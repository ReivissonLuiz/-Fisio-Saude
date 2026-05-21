# SQL - Tabela log_auditoria (Atualizado com GRANTS e RLS corrigido)
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
-- 3. Habilitar RLS (Row-Level Security)
-- ============================================================
ALTER TABLE log_auditoria ENABLE ROW LEVEL SECURITY;

-- Remove políticas antigas se existirem para evitar conflitos
DROP POLICY IF EXISTS "admins_read_audit" ON log_auditoria;
DROP POLICY IF EXISTS "authenticated_insert_audit" ON log_auditoria;
DROP POLICY IF EXISTS "anyone_insert_audit" ON log_auditoria;

-- 3.1 Política de Leitura (SELECT): somente admin (id_permissao = 3)
CREATE POLICY "admins_read_audit"
  ON log_auditoria FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM usuario u
      WHERE u.supabase_user_id = auth.uid()
        AND u.id_permissao = 3
    )
  );

-- 3.2 Política de Inserção (INSERT): permite tanto usuários logados quanto anônimos (ex: falhas de login)
CREATE POLICY "anyone_insert_audit"
  ON log_auditoria FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- ============================================================
-- 4. Permissões de Acesso (GRANTs) explícitas
--    Necessário no Supabase para que as roles anon/authenticated tenham direito de uso na tabela.
-- ============================================================
GRANT INSERT ON public.log_auditoria TO anon;
GRANT SELECT, INSERT ON public.log_auditoria TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.log_auditoria TO service_role;

-- ============================================================
-- 5. Verificação (execute para confirmar)
-- ============================================================
SELECT COUNT(*) FROM log_auditoria;
