-- ============================================================
-- +Físio +Saúde — Migration 015
-- Descrição: Corrige a policy de INSERT na tabela `login` para
--            permitir registro de tentativas de acesso por `anon`.
--
-- Problema: Quando o login FALHA, o usuário ainda não está
-- autenticado (role = anon). A policy antiga exigia `authenticated`,
-- bloqueando o INSERT com erro 42501 (RLS violation).
--
-- Solução: Substituir a policy de INSERT por uma que aceite
-- tanto `anon` quanto `authenticated`.
-- ============================================================

-- Remove a policy antiga (restrita a authenticated)
DROP POLICY IF EXISTS "login_insert" ON public.login;

-- Nova policy: qualquer role pode registrar tentativas de acesso
CREATE POLICY "login_insert" ON public.login
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- Garante o GRANT de INSERT para anon (necessário junto com a policy)
GRANT INSERT ON public.login TO anon;
