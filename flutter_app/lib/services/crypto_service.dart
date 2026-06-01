/// crypto_service.dart
/// Serviço de criptografia AES-256-GCM para mensagens — +Físio +Saúde
///
/// Atende à LGPD armazenando mensagens cifradas no Supabase.
/// A decifragem ocorre exclusivamente no cliente Flutter.
///
/// Formato armazenado no banco:
///   "<nonce_base64>:<ciphertext_base64>"
///
/// Retrocompatibilidade: textos que não seguem o formato acima
/// (mensagens antigas em texto puro) são retornados sem alteração.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  CryptoService._();
  static final CryptoService instance = CryptoService._();

  // ── Chave derivada de uma constante fixa via HMAC-SHA256 ─────────────────
  // A constante é combinada com um salt fixo para produzir sempre os mesmos
  // 32 bytes (256 bits) de chave AES.
  //
  // Em produção, mova _kSecret para variáveis de ambiente / flutter_dotenv.
  static const String _kSecret = 'fisio_saude_lgpd_mensagens_2024';
  static const String _kSalt   = 'fisio_saude_salt_v1';

  late final enc.Key _key = _deriveKey();

  enc.Key _deriveKey() {
    final keyBytes = Hmac(sha256, utf8.encode(_kSalt))
        .convert(utf8.encode(_kSecret))
        .bytes;
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  // ── Constante separadora ──────────────────────────────────────────────────
  static const String _sep = ':';

  // ── Identifica se uma string está no formato cifrado ─────────────────────
  bool _isCiphered(String text) {
    final parts = text.split(_sep);
    if (parts.length != 2) return false;
    try {
      final nonceBytes = base64.decode(parts[0]);
      return nonceBytes.length == 12; // GCM nonce = 12 bytes
    } catch (_) {
      return false;
    }
  }

  // ── Cifra um texto em claro ───────────────────────────────────────────────
  /// Retorna "<nonce_base64>:<ciphertext_base64>"
  String encrypt(String plaintext) {
    // Gera nonce aleatório de 12 bytes (96 bits) por mensagem
    final rng = Random.secure();
    final nonceBytes = Uint8List.fromList(
      List<int>.generate(12, (_) => rng.nextInt(256)),
    );
    final iv = enc.IV(nonceBytes);
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final nonceB64 = base64.encode(nonceBytes);
    return '$nonceB64$_sep${encrypted.base64}';
  }

  // ── Decifra um texto cifrado ──────────────────────────────────────────────
  /// Retorna o texto em claro.
  /// Se o texto não estiver no formato cifrado (mensagem histórica),
  /// retorna o próprio texto sem alteração (retrocompatibilidade).
  String tryDecrypt(String stored) {
    if (stored.isEmpty) return stored;
    if (!_isCiphered(stored)) return stored; // mensagem histórica em texto puro

    try {
      final parts = stored.split(_sep);
      final nonceBytes = base64.decode(parts[0]);
      final iv = enc.IV(Uint8List.fromList(nonceBytes));
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      // Se falhar a decifragem por qualquer motivo, retorna o dado bruto
      // para não quebrar a UI (melhor exibir dado ilegível que travar o app).
      return stored;
    }
  }
}
