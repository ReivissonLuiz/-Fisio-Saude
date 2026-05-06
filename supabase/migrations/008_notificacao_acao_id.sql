-- ============================================================
-- +Físio +Saúde — Migration 008
-- Descrição: Adiciona acao_id na tabela notificacao
-- ============================================================

ALTER TABLE notificacao ADD COLUMN IF NOT EXISTS acao_id UUID;
