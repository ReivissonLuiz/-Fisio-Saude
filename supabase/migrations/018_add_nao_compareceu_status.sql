-- ============================================================
-- +Físio +Saúde — Migration 018
-- Descrição: Atualiza o check constraint da tabela de consulta
--            para aceitar o status 'nao_compareceu'.
-- ============================================================

-- Remove o check atual
ALTER TABLE consulta DROP CONSTRAINT IF EXISTS consulta_status_check;

-- Adiciona o novo check contendo todos os status utilizados pelo app,
-- incluindo o novo status de expiração 'nao_compareceu'
ALTER TABLE consulta ADD CONSTRAINT consulta_status_check 
  CHECK (status IN ('agendada', 'confirmada', 'realizada', 'cancelada', 'finalizada', 'nao_compareceu'));
