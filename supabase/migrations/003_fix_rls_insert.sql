-- 003_fix_rls_insert.sql
-- Corrige a política de inserção na tabela usuario para permitir que contas
-- recém-criadas no auth (ainda com role anon) possam gravar o perfil.

DROP POLICY IF EXISTS "usuario_insert" ON usuario;

CREATE POLICY "usuario_insert" ON usuario
  FOR INSERT TO public WITH CHECK (true);
