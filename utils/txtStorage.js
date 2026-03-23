/**
 * txtStorage.js
 * Funções utilitárias para leitura, escrita, busca e atualização
 * de registros nos arquivos TXT (pacientes.txt e profissionais.txt).
 * Formato de linha: campos separados por pipe (|), uma linha por registro.
 * Linhas que começam com '#' são comentários e ignoradas.
 */

const fs = require('fs');
const path = require('path');

/**
 * Lê todas as linhas de um arquivo TXT e retorna um array de strings.
 * Ignora linhas de comentário (#) e linhas vazias.
 * @param {string} filePath - Caminho absoluto do arquivo
 * @returns {string[]} Array de linhas
 */
function readAllLines(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, 'utf-8');
  return content
    .split('\n')
    .map(l => l.trim())
    .filter(l => l && !l.startsWith('#'));
}

/**
 * Converte uma linha pipe-separated em objeto usando as chaves fornecidas.
 * @param {string} line - Linha do arquivo TXT
 * @param {string[]} keys - Array de nomes de campos na ordem correta
 * @returns {Object}
 */
function lineToObject(line, keys) {
  const values = line.split('|');
  const obj = {};
  keys.forEach((k, i) => { obj[k] = values[i] || ''; });
  return obj;
}

/**
 * Converte um objeto em linha pipe-separated conforme a ordem de keys.
 * @param {Object} obj
 * @param {string[]} keys
 * @returns {string}
 */
function objectToLine(obj, keys) {
  return keys.map(k => (obj[k] !== undefined ? String(obj[k]) : '')).join('|');
}

// ─── Schemas ──────────────────────────────────────────────────────────────────

const PATIENT_KEYS = [
  'id', 'nome', 'email', 'cpf', 'dataNascimento',
  'telefone', 'cep', 'senhaHash', 'status', 'dataCadastro'
];

const PROFESSIONAL_KEYS = [
  'id', 'nome', 'email', 'cpf', 'crefito',
  'especializacao', 'telefone', 'cep', 'senhaHash', 'status', 'dataCadastro'
];

/**
 * Retorna as keys corretas de acordo com o tipo de arquivo.
 * @param {string} filePath
 */
function getKeys(filePath) {
  return path.basename(filePath).startsWith('profissionais')
    ? PROFESSIONAL_KEYS
    : PATIENT_KEYS;
}

// ─── CRUD Funções ─────────────────────────────────────────────────────────────

/**
 * Lê todos os registros de um arquivo TXT como array de objetos.
 * @param {string} filePath
 * @returns {Object[]}
 */
function readAllRecords(filePath) {
  const keys = getKeys(filePath);
  return readAllLines(filePath).map(line => lineToObject(line, keys));
}

/**
 * Busca um registro pelo e-mail (case-insensitive).
 * @param {string} filePath
 * @param {string} email
 * @returns {Object|null}
 */
function findByEmail(filePath, email) {
  const records = readAllRecords(filePath);
  return records.find(r => r.email.toLowerCase() === email.toLowerCase()) || null;
}

/**
 * Busca um registro pelo CPF (ignora pontuação).
 * @param {string} filePath
 * @param {string} cpf
 * @returns {Object|null}
 */
function findByCPF(filePath, cpf) {
  const cleanCPF = cpf.replace(/\D/g, '');
  const records = readAllRecords(filePath);
  return records.find(r => r.cpf.replace(/\D/g, '') === cleanCPF) || null;
}

/**
 * Acrescenta um novo registro ao final do arquivo TXT.
 * @param {string} filePath
 * @param {Object} record - Objeto com os campos do registro
 */
function appendRecord(filePath, record) {
  const keys = getKeys(filePath);
  const line = objectToLine(record, keys);
  fs.appendFileSync(filePath, line + '\n', 'utf-8');
}

/**
 * Atualiza um campo específico de um registro localizado pelo e-mail.
 * Reescreve o arquivo inteiro com a linha alterada.
 * @param {string} filePath
 * @param {string} email - E-mail do registro a atualizar
 * @param {string} field - Nome do campo a modificar
 * @param {string} value - Novo valor do campo
 * @returns {boolean} true se encontrado e atualizado, false caso contrário
 */
function updateFieldByEmail(filePath, email, field, value) {
  const keys = getKeys(filePath);
  const lines = readAllLines(filePath);
  let updated = false;

  const newLines = lines.map(line => {
    const obj = lineToObject(line, keys);
    if (obj.email.toLowerCase() === email.toLowerCase()) {
      obj[field] = value;
      updated = true;
      return objectToLine(obj, keys);
    }
    return line;
  });

  if (updated) {
    // Preserva o cabeçalho de comentário original
    const header = `# ${keys.map(k => k.toUpperCase()).join('|')}\n`;
    fs.writeFileSync(filePath, header + newLines.join('\n') + '\n', 'utf-8');
  }
  return updated;
}

/**
 * Atualiza o campo 'status' de um registro pelo e-mail.
 * @param {string} filePath
 * @param {string} email
 * @param {string} status - Novo status
 */
function updateStatus(filePath, email, status) {
  return updateFieldByEmail(filePath, email, 'status', status);
}

module.exports = {
  readAllRecords,
  findByEmail,
  findByCPF,
  appendRecord,
  updateFieldByEmail,
  updateStatus,
  PATIENT_KEYS,
  PROFESSIONAL_KEYS,
};
