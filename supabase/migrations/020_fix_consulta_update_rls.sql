-- ============================================================
-- +Físio +Saúde — Migration 020
-- Descrição: Recria as políticas da tabela consulta de forma explícita
--            para garantir que o UPDATE (incluindo avaliações) funcione
--            sem falhas silenciosas.
-- ============================================================

DO $$ 
DECLARE 
  pol record;
BEGIN
  -- 1. Remove TODAS as políticas existentes na tabela consulta (dinamicamente)
  FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'consulta' AND schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.consulta', pol.policyname);
  END LOOP;
END $$;

-- 2. Recria as políticas de forma limpa e explícita

-- SELECT: Paciente vê as próprias, profissional vê as suas, admin vê todas
CREATE POLICY "consulta_select_all" ON public.consulta
  FOR SELECT TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

-- INSERT: Permitido para autenticados
CREATE POLICY "consulta_insert" ON public.consulta
  FOR INSERT TO authenticated 
  WITH CHECK (true);

-- UPDATE: Paciente (para avaliação, cancelamento), Profissional (relatório, checkin), Admin (tudo)
CREATE POLICY "consulta_update" ON public.consulta
  FOR UPDATE TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  )
  WITH CHECK (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

-- DELETE: Somente admin
CREATE POLICY "consulta_delete" ON public.consulta
  FOR DELETE TO authenticated
  USING (check_is_admin());

-- 3. Limpa o cache da API do Supabase para forçar a nova regra imediatamente
NOTIFY pgrst, 'reload schema';
