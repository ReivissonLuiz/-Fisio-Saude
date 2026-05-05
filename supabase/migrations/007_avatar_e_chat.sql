-- ============================================================
-- +Físio +Saúde — Migration 007
-- Descrição: Avatar de usuário e sistema de Chat entre
--            profissional e paciente.
-- ============================================================

-- ─── 1. Coluna avatar_url na tabela usuario ───────────────────────────────
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- ─── 2. Tabela de Mensagens (Chat) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS mensagem (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  id_remetente     UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  id_destinatario  UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  id_consulta      UUID        REFERENCES consulta(id) ON DELETE SET NULL,
  conteudo         TEXT        NOT NULL,
  lida             BOOLEAN     NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 3. RLS para mensagens ────────────────────────────────────────────────
ALTER TABLE mensagem ENABLE ROW LEVEL SECURITY;

-- Remetente ou destinatário podem ler
CREATE POLICY "msg_select_participante" ON mensagem
  FOR SELECT TO authenticated
  USING (
    id_remetente    IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_destinatario IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

-- Qualquer autenticado pode inserir (com remetente sendo o próprio)
CREATE POLICY "msg_insert_proprio" ON mensagem
  FOR INSERT TO authenticated
  WITH CHECK (
    id_remetente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
  );

-- Destinatário pode marcar como lida
CREATE POLICY "msg_update_lida" ON mensagem
  FOR UPDATE TO authenticated
  USING (
    id_destinatario IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
  );

-- ─── 4. Índices ───────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_msg_remetente     ON mensagem (id_remetente);
CREATE INDEX IF NOT EXISTS idx_msg_destinatario  ON mensagem (id_destinatario);
CREATE INDEX IF NOT EXISTS idx_msg_created_at    ON mensagem (created_at ASC);

-- ─── 5. Habilitar Realtime para mensagem ─────────────────────────────────
-- Execute isto manualmente no Supabase Dashboard > Database > Replication
-- ou adicione a tabela `mensagem` no painel Realtime.
-- ALTER PUBLICATION supabase_realtime ADD TABLE mensagem;
