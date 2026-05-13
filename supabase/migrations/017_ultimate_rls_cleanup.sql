-- ============================================================
-- +Físio +Saúde — Migration 017
-- Descrição: Limpeza absoluta de todas as políticas da tabela
--            usuario para garantir o fim do "infinite recursion".
--
-- O erro persiste porque provavelmente há alguma política antiga
-- com um nome diferente na tabela usuario que ainda está chamando
-- a função check_is_admin() durante o SELECT.
-- ============================================================

DO $$ 
DECLARE 
  pol record;
BEGIN
  -- 1. Remove TODAS as políticas existentes na tabela usuario (dinamicamente)
  FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'usuario' AND schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.usuario', pol.policyname);
  END LOOP;
END $$;

-- 2. Recria apenas as políticas essenciais e livres de recursão

-- SELECT: Aberto para todos os logados (necessário para listar profissionais)
-- Como não usa função, é 100% impossível causar loop infinito.
CREATE POLICY "usuario_select_all" ON public.usuario
  FOR SELECT TO authenticated
  USING (true);

-- UPDATE: Usuário pode editar a si mesmo
CREATE POLICY "usuario_proprio_update" ON public.usuario
  FOR UPDATE TO authenticated
  USING (supabase_user_id = auth.uid());

-- UPDATE: Admin pode editar qualquer um
CREATE POLICY "usuario_admin_update" ON public.usuario
  FOR UPDATE TO authenticated
  USING (check_is_admin());

-- INSERT: Permitido para novos cadastros
CREATE POLICY "usuario_insert" ON public.usuario
  FOR INSERT TO public 
  WITH CHECK (true);

-- 3. Limpa o cache da API do Supabase para forçar a nova regra imediatamente
NOTIFY pgrst, 'reload schema';
