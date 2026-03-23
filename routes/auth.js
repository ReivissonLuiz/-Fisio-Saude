/**
 * auth.js
 * Rotas de autenticação do app +Físio +Saúde.
 * Inclui: login, registro de paciente, registro de profissional,
 * esqueci minha senha (3 etapas) e redefinição de senha.
 */

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const storage = require('../utils/txtStorage');

// ─── Caminhos dos arquivos TXT ────────────────────────────────────────────────
const PACIENTES_FILE = path.join(__dirname, '../data/pacientes.txt');
const PROFISSIONAIS_FILE = path.join(__dirname, '../data/profissionais.txt');

// ─── Armazenamento em memória (lockout e tokens de recuperação) ───────────────

/**
 * loginAttempts: Map<email, { count: number, lockedUntil: Date|null }>
 * Controla tentativas de login para bloqueio após 5 falhas.
 */
const loginAttempts = new Map();

/**
 * recoveryTokens: Map<email, { code: string, expiresAt: Date, type: 'patient'|'professional' }>
 * Armazena códigos de recuperação de senha temporários.
 */
const recoveryTokens = new Map();

// ─── Constantes ───────────────────────────────────────────────────────────────
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 5;
const CODE_EXPIRY_MINUTES = 15;
const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS) || 10;

// ─── Funções Auxiliares ───────────────────────────────────────────────────────

/**
 * Verifica se uma conta está bloqueada e registra tentativa falha.
 * @param {string} email
 * @returns {{ locked: boolean, remainingMs?: number }}
 */
function checkLockout(email) {
  const data = loginAttempts.get(email);
  if (!data) return { locked: false };

  if (data.lockedUntil && new Date() < data.lockedUntil) {
    const remainingMs = data.lockedUntil - new Date();
    return { locked: true, remainingMs };
  }
  return { locked: false };
}

/**
 * Registra uma tentativa de login falha. Bloqueia após MAX_LOGIN_ATTEMPTS.
 * @param {string} email
 */
function registerFailedAttempt(email) {
  const data = loginAttempts.get(email) || { count: 0, lockedUntil: null };
  data.count += 1;
  if (data.count >= MAX_LOGIN_ATTEMPTS) {
    data.lockedUntil = new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000);
    data.count = 0; // Reinicia contagem após bloqueio
  }
  loginAttempts.set(email, data);
}

/**
 * Limpa o contador de tentativas após login bem-sucedido.
 * @param {string} email
 */
function clearFailedAttempts(email) {
  loginAttempts.delete(email);
}

/**
 * Gera um código numérico de 6 dígitos.
 * @returns {string}
 */
function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/**
 * Valida formato de e-mail simples.
 * @param {string} email
 * @returns {boolean}
 */
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Valida CPF (algoritmo de dígitos verificadores).
 * @param {string} cpf
 * @returns {boolean}
 */
function isValidCPF(cpf) {
  const clean = cpf.replace(/\D/g, '');
  if (clean.length !== 11 || /^(\d)\1+$/.test(clean)) return false;
  let sum = 0;
  for (let i = 0; i < 9; i++) sum += parseInt(clean[i]) * (10 - i);
  let r = (sum * 10) % 11;
  if (r === 10 || r === 11) r = 0;
  if (r !== parseInt(clean[9])) return false;
  sum = 0;
  for (let i = 0; i < 10; i++) sum += parseInt(clean[i]) * (11 - i);
  r = (sum * 10) % 11;
  if (r === 10 || r === 11) r = 0;
  return r === parseInt(clean[10]);
}

// ─── ROTA: Cadastro de Paciente ───────────────────────────────────────────────

/**
 * POST /auth/register/patient
 * Body: { nome, email, cpf, dataNascimento, telefone, senha, confirmarSenha, cep?, aceitaTermos }
 */
router.post('/register/patient', async (req, res) => {
  try {
    const { nome, email, cpf, dataNascimento, telefone, senha, confirmarSenha, cep, aceitaTermos } = req.body;

    // Validações obrigatórias
    if (!nome || !email || !cpf || !dataNascimento || !telefone || !senha || !confirmarSenha) {
      return res.status(400).json({ success: false, message: 'Todos os campos obrigatórios devem ser preenchidos.' });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ success: false, message: 'E-mail inválido.' });
    }
    if (!isValidCPF(cpf)) {
      return res.status(400).json({ success: false, message: 'CPF inválido.' });
    }
    if (senha !== confirmarSenha) {
      return res.status(400).json({ success: false, message: 'As senhas não coincidem.' });
    }
    if (senha.length < 6) {
      return res.status(400).json({ success: false, message: 'A senha deve ter no mínimo 6 caracteres.' });
    }
    if (!aceitaTermos) {
      return res.status(400).json({ success: false, message: 'Você deve aceitar os Termos de Uso.' });
    }

    // Verificar duplicidade
    if (storage.findByEmail(PACIENTES_FILE, email)) {
      return res.status(409).json({ success: false, message: 'E-mail já cadastrado.' });
    }
    if (storage.findByCPF(PACIENTES_FILE, cpf)) {
      return res.status(409).json({ success: false, message: 'CPF já cadastrado.' });
    }

    // Hash da senha
    const senhaHash = await bcrypt.hash(senha, BCRYPT_ROUNDS);

    // Montar e salvar registro
    const record = {
      id: uuidv4(),
      nome: nome.trim(),
      email: email.toLowerCase().trim(),
      cpf: cpf.replace(/\D/g, ''),
      dataNascimento,
      telefone: telefone.replace(/\D/g, ''),
      cep: (cep || '').replace(/\D/g, ''),
      senhaHash,
      status: 'ativo',
      dataCadastro: new Date().toISOString(),
    };

    storage.appendRecord(PACIENTES_FILE, record);

    return res.status(201).json({ success: true, message: 'Paciente cadastrado com sucesso!' });
  } catch (err) {
    console.error('[register/patient]', err);
    return res.status(500).json({ success: false, message: 'Erro interno do servidor.' });
  }
});

// ─── ROTA: Cadastro de Profissional ──────────────────────────────────────────

/**
 * POST /auth/register/professional
 * Body: { nome, email, cpf, crefito, especializacao, telefone, cep, senha, confirmarSenha, aceitaTermos }
 */
router.post('/register/professional', async (req, res) => {
  try {
    const { nome, email, cpf, crefito, especializacao, telefone, cep, senha, confirmarSenha, aceitaTermos } = req.body;

    // Validações obrigatórias
    if (!nome || !email || !cpf || !crefito || !especializacao || !telefone || !cep || !senha || !confirmarSenha) {
      return res.status(400).json({ success: false, message: 'Todos os campos obrigatórios devem ser preenchidos.' });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ success: false, message: 'E-mail inválido.' });
    }
    if (!isValidCPF(cpf)) {
      return res.status(400).json({ success: false, message: 'CPF inválido.' });
    }
    if (senha !== confirmarSenha) {
      return res.status(400).json({ success: false, message: 'As senhas não coincidem.' });
    }
    if (senha.length < 6) {
      return res.status(400).json({ success: false, message: 'A senha deve ter no mínimo 6 caracteres.' });
    }
    if (!aceitaTermos) {
      return res.status(400).json({ success: false, message: 'Você deve aceitar os Termos de Uso.' });
    }

    // Verificar duplicidade
    if (storage.findByEmail(PROFISSIONAIS_FILE, email)) {
      return res.status(409).json({ success: false, message: 'E-mail já cadastrado.' });
    }
    if (storage.findByCPF(PROFISSIONAIS_FILE, cpf)) {
      return res.status(409).json({ success: false, message: 'CPF já cadastrado.' });
    }

    // Hash da senha
    const senhaHash = await bcrypt.hash(senha, BCRYPT_ROUNDS);

    // Montar e salvar registro
    const record = {
      id: uuidv4(),
      nome: nome.trim(),
      email: email.toLowerCase().trim(),
      cpf: cpf.replace(/\D/g, ''),
      crefito: crefito.trim(),
      especializacao: especializacao.trim(),
      telefone: telefone.replace(/\D/g, ''),
      cep: cep.replace(/\D/g, ''),
      senhaHash,
      status: 'pendente', // Aguarda aprovação do administrador
      dataCadastro: new Date().toISOString(),
    };

    storage.appendRecord(PROFISSIONAIS_FILE, record);

    return res.status(201).json({
      success: true,
      message: 'Profissional cadastrado! Seu cadastro está em análise e será aprovado em breve.',
    });
  } catch (err) {
    console.error('[register/professional]', err);
    return res.status(500).json({ success: false, message: 'Erro interno do servidor.' });
  }
});

// ─── ROTA: Login ──────────────────────────────────────────────────────────────

/**
 * POST /auth/login
 * Body: { email, senha }
 * Busca o usuário em ambos os arquivos TXT.
 */
router.post('/login', async (req, res) => {
  try {
    const { email, senha } = req.body;

    if (!email || !senha) {
      return res.status(400).json({ success: false, message: 'E-mail e senha são obrigatórios.' });
    }

    // Verificar bloqueio por tentativas excessivas
    const lockout = checkLockout(email);
    if (lockout.locked) {
      const minutes = Math.ceil(lockout.remainingMs / 60000);
      return res.status(429).json({
        success: false,
        message: `Conta bloqueada. Tente novamente em ${minutes} minuto(s).`,
      });
    }

    // Buscar em pacientes e depois em profissionais
    let user = storage.findByEmail(PACIENTES_FILE, email);
    let userType = 'patient';

    if (!user) {
      user = storage.findByEmail(PROFISSIONAIS_FILE, email);
      userType = 'professional';
    }

    if (!user) {
      registerFailedAttempt(email);
      return res.status(401).json({ success: false, message: 'Credenciais inválidas.' });
    }

    // Verificar status da conta
    if (user.status === 'pendente') {
      return res.status(403).json({
        success: false,
        message: 'Sua conta está aguardando aprovação do administrador.',
      });
    }
    if (user.status === 'inativo') {
      return res.status(403).json({ success: false, message: 'Conta inativa. Contate o suporte.' });
    }

    // Comparar senha com hash
    const senhaOk = await bcrypt.compare(senha, user.senhaHash);
    if (!senhaOk) {
      registerFailedAttempt(email);
      return res.status(401).json({ success: false, message: 'Credenciais inválidas.' });
    }

    // Login bem-sucedido — limpar tentativas e gerar token
    clearFailedAttempts(email);

    const token = jwt.sign(
      { id: user.id, email: user.email, tipo: userType, nome: user.nome },
      process.env.JWT_SECRET || 'fisiosaudeSecret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
    );

    return res.status(200).json({
      success: true,
      message: 'Login realizado com sucesso!',
      token,
      user: { id: user.id, nome: user.nome, email: user.email, tipo: userType },
    });
  } catch (err) {
    console.error('[login]', err);
    return res.status(500).json({ success: false, message: 'Erro interno do servidor.' });
  }
});

// ─── ROTA: Esqueci minha senha — Passo 1 (Enviar código) ─────────────────────

/**
 * POST /auth/forgot-password
 * Body: { email }
 * Verifica se o e-mail existe e "envia" o código (em dev, retorna no response).
 */
router.post('/forgot-password', (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ success: false, message: 'E-mail inválido.' });
    }

    // Verificar existência em ambos os arquivos
    let userType = null;
    if (storage.findByEmail(PACIENTES_FILE, email)) userType = 'patient';
    else if (storage.findByEmail(PROFISSIONAIS_FILE, email)) userType = 'professional';

    // Resposta genérica por segurança (não revela se email existe ou não)
    // Em ambiente de desenvolvimento, retornamos o código para facilitar testes
    if (userType) {
      const code = generateCode();
      const expiresAt = new Date(Date.now() + CODE_EXPIRY_MINUTES * 60 * 1000);
      recoveryTokens.set(email.toLowerCase(), { code, expiresAt, type: userType });

      console.log(`[forgot-password] Código para ${email}: ${code}`); // Apenas em desenvolvimento

      // Em produção, aqui enviaria o código por e-mail (SMTP, SendGrid, etc.)
      // Por ora, retornamos no body para facilitar testes do app
      return res.status(200).json({
        success: true,
        message: 'Se este e-mail estiver cadastrado, você receberá um código em breve.',
        // REMOVER EM PRODUÇÃO:
        _devCode: code,
      });
    }

    // E-mail não encontrado — resposta genérica
    return res.status(200).json({
      success: true,
      message: 'Se este e-mail estiver cadastrado, você receberá um código em breve.',
    });
  } catch (err) {
    console.error('[forgot-password]', err);
    return res.status(500).json({ success: false, message: 'Erro interno do servidor.' });
  }
});

// ─── ROTA: Esqueci minha senha — Passo 2 (Verificar código) ──────────────────

/**
 * POST /auth/verify-code
 * Body: { email, code }
 */
router.post('/verify-code', (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ success: false, message: 'E-mail e código são obrigatórios.' });
    }

    const tokenData = recoveryTokens.get(email.toLowerCase());

    if (!tokenData) {
      return res.status(400).json({ success: false, message: 'Código inválido ou expirado.' });
    }

    if (new Date() > tokenData.expiresAt) {
      recoveryTokens.delete(email.toLowerCase());
      return res.status(400).json({ success: false, message: 'Código expirado. Solicite um novo.' });
    }

    if (tokenData.code !== code) {
      return res.status(400).json({ success: false, message: 'Código incorreto.' });
    }

    // Marcar como verificado (mantém no Map para uso no passo 3)
    tokenData.verified = true;

    return res.status(200).json({ success: true, message: 'Código verificado com sucesso!' });
  } catch (err) {
    console.error('[verify-code]', err);
    return res.status(500).json({ success: false, message: 'Erro interno do servidor.' });
  }
});

// ─── ROTA: Esqueci minha senha — Passo 3 (Redefinir senha) ───────────────────

/**
 * POST /auth/reset-password
 * Body: { email, code, novaSenha, confirmarSenha }
 */
router.post('/reset-password', async (req, res) => {
  try {
    const { email, code, novaSenha, confirmarSenha } = req.body;

    if (!email || !code || !novaSenha || !confirmarSenha) {
      return res.status(400).json({ success: false, message: 'Todos os campos são obrigatórios.' });
    }

    if (novaSenha !== confirmarSenha) {
      return res.status(400).json({ success: false, message: 'As senhas não coincidem.' });
    }

    if (novaSenha.length < 6) {
      return res.status(400).json({ success: false, message: 'A senha deve ter no mínimo 6 caracteres.' });
    }

    const tokenData = recoveryTokens.get(email.toLowerCase());

    if (!tokenData || !tokenData.verified || tokenData.code !== code) {
      return res.status(400).json({ success: false, message: 'Sessão de recuperação inválida. Recomece o processo.' });
    }

    if (new Date() > tokenData.expiresAt) {
      recoveryTokens.delete(email.toLowerCase());
      return res.status(400).json({ success: false, message: 'Sessão expirada. Solicite um novo código.' });
    }

    // Determinar arquivo correto e atualizar senha
    const filePath = tokenData.type === 'professional' ? PROFISSIONAIS_FILE : PACIENTES_FILE;
    const senhaHash = await bcrypt.hash(novaSenha, BCRYPT_ROUNDS);
    const updated = storage.updateFieldByEmail(filePath, email, 'senhaHash', senhaHash);

    if (!updated) {
      return res.status(500).json({ success: false, message: 'Não foi possível atualizar a senha.' });
    }

    // Limpar token de recuperação
    recoveryTokens.delete(email.toLowerCase());

    return res.status(200).json({ success: true, message: 'Senha redefinida com sucesso!' });
  } catch (err) {
    console.error('[reset-password]', err);
    return res.status(500).json({ success: false, message: 'Erro interno do servidor.' });
  }
});

module.exports = router;
