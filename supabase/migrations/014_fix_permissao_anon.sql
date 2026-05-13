-- ============================================================
-- +Físio +Saúde — Migration 014
-- Descrição: Corrige acesso à tabela `permissao` para o join
--            PostgREST funcionar durante o fluxo de login.
--
-- Problema: O join `usuario?select=*,permissao(*)` feito pelo
-- método `login()` retorna 500 porque a policy RLS de `permissao`
-- está restrita a `authenticated`, mas durante o processamento
-- do JWT o PostgREST pode executar o join com role `anon`.
--
-- Solução: Adicionar policy de SELECT para `anon` em `permissao`
-- (tabela de lookup, sem dados sensíveis).
-- ============================================================

-- Garante que anon possa ler a tabela de permissões (lookup)
DROP POLICY IF EXISTS "permissao_leitura_anon" ON public.permissao;

CREATE POLICY "permissao_leitura_anon" ON public.permissao
  FOR SELECT TO anon USING (true);

-- Garante o GRANT também (caso a migration 013 não tenha sido aplicada)
GRANT SELECT ON public.permissao TO anon;
GRANT SELECT ON public.permissao TO authenticated;
