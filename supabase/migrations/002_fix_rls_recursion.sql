-- 002_fix_rls_recursion.sql
-- Este script corrige o erro "infinite recursion detected" na tabela usuario.
-- Ele cria uma função SECURITY DEFINER (ignora RLS durante a verificação de permissão)
-- e recria as políticas de acesso do administrador.

-- 1. Cria função segura para verificar se é admin
CREATE OR REPLACE FUNCTION check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuario
    WHERE supabase_user_id = auth.uid()
      AND id_permissao = 3
  );
END;
$$;

-- 2. Remove as políticas recursivas (que causavam o erro)
DROP POLICY IF EXISTS "usuario_admin_select" ON usuario;
DROP POLICY IF EXISTS "usuario_admin_update" ON usuario;
DROP POLICY IF EXISTS "login_admin_select" ON login;
DROP POLICY IF EXISTS "consulta_paciente_select" ON consulta;
DROP POLICY IF EXISTS "consulta_update" ON consulta;
DROP POLICY IF EXISTS "consulta_delete" ON consulta;
DROP POLICY IF EXISTS "sintomas_proprio" ON registro_sintomas;

-- 3. Recria as políticas apontando para a função segura
CREATE POLICY "usuario_admin_select" ON usuario
  FOR SELECT TO authenticated USING (check_is_admin());

CREATE POLICY "usuario_admin_update" ON usuario
  FOR UPDATE TO authenticated USING (check_is_admin());

CREATE POLICY "login_admin_select" ON login
  FOR SELECT TO authenticated USING (check_is_admin());

CREATE POLICY "consulta_paciente_select" ON consulta
  FOR SELECT TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

CREATE POLICY "consulta_update" ON consulta
  FOR UPDATE TO authenticated
  USING (
    id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

CREATE POLICY "consulta_delete" ON consulta
  FOR DELETE TO authenticated
  USING (check_is_admin());

CREATE POLICY "sintomas_proprio" ON registro_sintomas
  FOR ALL TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );
