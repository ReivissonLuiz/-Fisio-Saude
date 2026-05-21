# SQL - Tabela log_auditoria
# Execute este script no Editor SQL do Supabase (https://supabase.com/dashboard → SQL Editor)

-- ============================================================
-- 1. Criar a tabela log_auditoria
-- ============================================================
CREATE TABLE IF NOT EXISTS log_auditoria (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  id_usuario  uuid        REFERENCES usuario(id) ON DELETE SET NULL,
  tipo_evento text        NOT NULL,
  descricao   text        NOT NULL,
  dados_extras jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. Índices para buscas rápidas
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_log_auditoria_usuario  ON log_auditoria (id_usuario);
CREATE INDEX IF NOT EXISTS idx_log_auditoria_tipo     ON log_auditoria (tipo_evento);
CREATE INDEX IF NOT EXISTS idx_log_auditoria_data     ON log_auditoria (created_at DESC);

-- ============================================================
-- 3. Row-Level Security (RLS)
--    - Apenas administradores podem LER
--    - O sistema (qualquer usuário autenticado) pode INSERIR
-- ============================================================
ALTER TABLE log_auditoria ENABLE ROW LEVEL SECURITY;

-- Leitura: somente admin (id_permissao = 3)
CREATE POLICY "admins_read_audit"
  ON log_auditoria FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM usuario u
      WHERE u.supabase_user_id = auth.uid()
        AND u.id_permissao = 3
    )
  );

-- Inserção: qualquer usuário autenticado (o app insere via SDK)
CREATE POLICY "authenticated_insert_audit"
  ON log_auditoria FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================================
-- 4. Verificação (execute para confirmar)
-- ============================================================
SELECT COUNT(*) FROM log_auditoria;
