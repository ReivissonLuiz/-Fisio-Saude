-- ============================================================
-- +Físio +Saúde — Migration 010
-- Descrição: Adiciona a coluna de relatório à tabela de consulta.
-- ============================================================

ALTER TABLE consulta ADD COLUMN IF NOT EXISTS relatorio TEXT;
ALTER TABLE consulta ADD COLUMN IF NOT EXISTS avaliacao INTEGER CHECK (avaliacao BETWEEN 1 AND 5);
