-- ============================================================
-- +Físio +Saúde — Migration 009
-- Descrição: Atualiza o check constraint da tabela de consulta
--            para aceitar os novos status (confirmada, finalizada)
-- ============================================================

-- Remove o check atual
ALTER TABLE consulta DROP CONSTRAINT IF EXISTS consulta_status_check;

-- Adiciona o novo check contendo todos os status utilizados pelo app
ALTER TABLE consulta ADD CONSTRAINT consulta_status_check 
  CHECK (status IN ('agendada', 'confirmada', 'realizada', 'cancelada', 'finalizada'));
