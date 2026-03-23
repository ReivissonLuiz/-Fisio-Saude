/**
 * server.js
 * Ponto de entrada do servidor Node.js — +Físio +Saúde Backend
 * Inicializa o Express, configura middlewares e registra as rotas.
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const authRoutes = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Middlewares ──────────────────────────────────────────────────────────────

// Habilitar CORS para o app Flutter (localhost durante desenvolvimento)
app.use(cors({
  origin: '*', // Em produção, restringir ao domínio do app
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Parse de JSON no corpo das requisições
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─── Rotas ────────────────────────────────────────────────────────────────────

app.use('/auth', authRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', app: '+Físio +Saúde API', version: '1.0.0' });
});

// ─── Inicialização ────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`\n✅  +Físio +Saúde API rodando em http://localhost:${PORT}`);
  console.log(`📂  Dados armazenados em: ${path.join(__dirname, 'data/')}\n`);
});

module.exports = app;
