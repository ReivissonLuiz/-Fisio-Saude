-- ============================================================
-- +Físio +Saúde — Migration 021
-- Alinha colunas de notificacao com o app (mensagem, acao_id)
-- ============================================================

-- Renomeia corpo → mensagem se ainda existir apenas corpo
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notificacao' AND column_name = 'corpo'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notificacao' AND column_name = 'mensagem'
  ) THEN
    ALTER TABLE notificacao RENAME COLUMN corpo TO mensagem;
  END IF;
END $$;

-- Garante coluna mensagem
ALTER TABLE notificacao ADD COLUMN IF NOT EXISTS mensagem TEXT;

-- Copia corpo legado para mensagem quando ambas existem
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notificacao' AND column_name = 'corpo'
  ) THEN
    UPDATE notificacao SET mensagem = COALESCE(mensagem, corpo) WHERE mensagem IS NULL;
  END IF;
END $$;

-- acao_id (migration 008 pode já ter criado)
ALTER TABLE notificacao ADD COLUMN IF NOT EXISTS acao_id UUID;

-- Migra id_consulta → acao_id quando acao_id estiver vazio
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notificacao' AND column_name = 'id_consulta'
  ) THEN
    UPDATE notificacao
    SET acao_id = id_consulta
    WHERE acao_id IS NULL AND id_consulta IS NOT NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notif_acao_id ON notificacao (acao_id);
