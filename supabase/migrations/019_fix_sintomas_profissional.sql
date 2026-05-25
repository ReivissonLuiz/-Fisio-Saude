-- ============================================================
-- +Físio +Saúde — Migration 019
-- Descrição: Ajusta as políticas de RLS da tabela de sintomas
--            para permitir que os profissionais de saúde possam
--            ler os sintomas de seus respectivos pacientes.
-- ============================================================

-- Remove as políticas antigas para evitar duplicatas ou conflitos
DROP POLICY IF EXISTS "sintomas_proprio" ON public.registro_sintomas;
DROP POLICY IF EXISTS "sintomas_select" ON public.registro_sintomas;
DROP POLICY IF EXISTS "sintomas_write" ON public.registro_sintomas;
DROP POLICY IF EXISTS "sintomas_acesso_geral" ON public.registro_sintomas;

-- 1. Permite LEITURA (SELECT) para o próprio paciente, administrador 
--    e PARA O PROFISSIONAL que possua alguma consulta com esse paciente
CREATE POLICY "sintomas_select" ON public.registro_sintomas
  FOR SELECT TO authenticated
  USING (
    -- O próprio paciente
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    
    -- O Administrador
    OR check_is_admin()

    -- O Profissional (se o profissional tem consultas com este paciente, ele pode ler os sintomas)
    OR EXISTS (
      SELECT 1 FROM consulta 
      WHERE consulta.id_paciente = registro_sintomas.id_paciente
        AND consulta.id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    )
  );

-- 2. Permite ESCRITA (INSERT, UPDATE, DELETE) apenas para o paciente dono ou admin
CREATE POLICY "sintomas_write" ON public.registro_sintomas
  FOR ALL TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

-- Notifica o PostgREST para limpar o cache das políticas
NOTIFY pgrst, 'reload schema';
