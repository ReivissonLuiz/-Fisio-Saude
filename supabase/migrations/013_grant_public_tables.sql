-- ============================================================
-- +Físio +Saúde — Migration 013
-- Descrição: GRANTs explícitos para todas as tabelas do schema
--            public, exigidos pelo Supabase a partir de 30/05/2026.
--
-- Cada tabela usa um bloco DO independente para que o erro
-- "relation does not exist" em tabelas opcionais não aborte
-- os GRANTs das tabelas que realmente existem.
-- ============================================================

-- ─── permissao ────────────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT ON public.permissao TO anon;
  GRANT SELECT ON public.permissao TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.permissao TO service_role;
  GRANT USAGE, SELECT ON SEQUENCE public.permissao_id_seq TO authenticated;
  GRANT USAGE, SELECT ON SEQUENCE public.permissao_id_seq TO service_role;
EXCEPTION WHEN undefined_table OR undefined_object THEN
  RAISE NOTICE 'permissao: GRANT ignorado (tabela/sequência não encontrada)';
END $$;

-- ─── usuario ──────────────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE ON public.usuario TO anon;
  GRANT SELECT, INSERT, UPDATE ON public.usuario TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.usuario TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'usuario: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── login ────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT INSERT ON public.login TO anon;
  GRANT SELECT, INSERT ON public.login TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.login TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'login: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── consulta ─────────────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.consulta TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.consulta TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'consulta: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── registro_sintomas ────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.registro_sintomas TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.registro_sintomas TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'registro_sintomas: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── disponibilidade_profissional (opcional) ──────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.disponibilidade_profissional TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.disponibilidade_profissional TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'disponibilidade_profissional: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── notificacao ──────────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notificacao TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notificacao TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'notificacao: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── recomendacao_video ───────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.recomendacao_video TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.recomendacao_video TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'recomendacao_video: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── horario_padrao ───────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.horario_padrao TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.horario_padrao TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'horario_padrao: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── mensagem ─────────────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.mensagem TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.mensagem TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'mensagem: GRANT ignorado (tabela não encontrada)';
END $$;

-- ─── disponibilidade ──────────────────────────────────────────────────────────
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.disponibilidade TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.disponibilidade TO service_role;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'disponibilidade: GRANT ignorado (tabela não encontrada)';
END $$;
