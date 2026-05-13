-- ============================================================
-- Recriação Segura da Política e Limpeza do Cache (PostgREST)
-- ============================================================

-- 1. Garante que qualquer política anterior de SELECT na tabela usuario seja removida
DROP POLICY IF EXISTS "usuario_proprio_select" ON public.usuario;
DROP POLICY IF EXISTS "usuario_admin_select" ON public.usuario;
DROP POLICY IF EXISTS "usuario_select_all" ON public.usuario;

-- 2. Cria a política correta
CREATE POLICY "usuario_select_all" ON public.usuario
  FOR SELECT TO authenticated
  USING (true);

-- 3. FORÇA a atualização do cache da API do Supabase (PostgREST)
-- Sem isso, a API pode continuar retornando 500 porque ainda
-- está usando a versão antiga do banco em memória.
NOTIFY pgrst, 'reload schema';
