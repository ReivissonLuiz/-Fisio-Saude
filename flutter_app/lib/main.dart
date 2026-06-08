/// main.dart
/// Ponto de entrada do app +Fisio +Saúde.
/// Configura tema, rotas e listener global de autenticação (recovery de senha).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password/forgot_step1_screen.dart';
import 'screens/forgot_password/reset_password_screen.dart';
import 'screens/register/profile_selection_screen.dart';
import 'screens/register/patient_register_screen.dart';
import 'screens/register/professional_register_screen.dart';
import 'screens/register/register_success_screen.dart';
import 'screens/register/admin_register_screen.dart';
import 'services/api_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa os dados de locale para formatação de datas em pt_BR
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o Supabase antes de qualquer widget
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // runZonedGuarded captura erros assíncronos não tratados (ex: sessão inválida ao iniciar)
  runZonedGuarded(
    () => runApp(const FisioSaudeApp()),
    (error, stack) {
      // Erros de sessão/auth são esperados quando o usuário foi deletado
      // ou o token expirou. Não devem quebrar o app.
      debugPrint('Erro assíncrono capturado: $error');
    },
  );
}

// Chave global para navegar a partir de qualquer lugar no app
final _navigatorKey = GlobalKey<NavigatorState>();



class FisioSaudeApp extends StatefulWidget {
  const FisioSaudeApp({super.key});

  @override
  State<FisioSaudeApp> createState() => _FisioSaudeAppState();
}

class _FisioSaudeAppState extends State<FisioSaudeApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Ouve eventos globais de autenticação do Supabase
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        // Quando o usuário clica no link de recuperação do e-mail,
        // o Supabase emite este evento com type=recovery
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/reset-password',
            (route) => false,
          );
        }
      },
      onError: (Object error) {
        // Ignora erros de sessão inválida (ex: usuário deletado, token expirado).
        // Sem este handler, uma sessão corrompida causaria "Uncaught Error" no startup.
        debugPrint('Auth stream error (ignorado): $error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '+Fisio +Saúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: _navigatorKey,
      // _AuthGate decide se exibe Splash ou vai direto para Home (reload)
      home: const _AuthGate(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-step1': (context) => const ForgotStep1Screen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/profile-selection': (context) => const ProfileSelectionScreen(),
        '/register-patient': (context) => const PatientRegisterScreen(),
        '/register-professional': (context) =>
            const ProfessionalRegisterScreen(),
        '/register-admin': (context) => const AdminRegisterScreen(),
        '/register-success': (context) {
          final tipo =
              ModalRoute.of(context)!.settings.arguments as String? ??
                  'Paciente';
          return RegisterSuccessScreen(tipoConta: tipo);
        },
      },
    );
  }
}

/// Verifica se há sessão ativa ao iniciar o app (ex: reload no browser).
/// - Com sessão → busca dados do usuário e abre HomeScreen diretamente.
/// - Sem sessão → exibe SplashScreen normalmente.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _api = ApiService();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Sem sessão ativa → mostra Splash normalmente
      if (mounted) setState(() => _checking = false);
      return;
    }

    try {
      final result = await _api.getUsuarioPorSupabaseId(session.user.id);

      if (!mounted) return;

      if (result['success'] != true) {
        // Sessão inválida ou usuário não encontrado → Splash
        setState(() => _checking = false);
        return;
      }

      final data = result['data'] as Map<String, dynamic>;
      final permissaoData = data['permissao'] as Map<String, dynamic>?;

      // Sessão válida → vai direto para HomeScreen preservando o estado
      // (HomeScreen irá restaurar _tabIndex e _visaoAtiva via SharedPreferences)
      Navigator.of(context).pushReplacementNamed(
        '/home',
        arguments: {
          'id': session.user.id,
          'id_usuario': data['id'] as String?,
          'nome': data['nome'] as String? ?? session.user.email ?? 'Usuário',
          'email': data['email'] as String? ?? session.user.email ?? '',
          'avatar_url': data['avatar_url'] as String?,
          'id_permissao': data['id_permissao'] as int? ?? 1,
          'tipo': permissaoData?['nome'] as String? ?? 'Paciente',
        },
      );
    } catch (_) {
      // Erro de rede → mostra Splash (usuário precisará fazer login)
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      // Tela de carregamento enquanto verifica sessão
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Sem sessão → Splash normal
    return const SplashScreen();
  }
}


