-- =====================================================
-- +Físio +Saúde — Habilitar RLS nas tabelas públicas
-- Execute este script no Supabase SQL Editor:
-- https://supabase.com/dashboard/project/nkicptibdnuygxxnoaof/sql
-- =====================================================

-- ── 1. Habilitar RLS ──────────────────────────────────────────────────────────
ALTER TABLE public.administrador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consulta      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paciente      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profissional  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login         ENABLE ROW LEVEL SECURITY;

-- Adicione aqui outras tabelas se existirem (ex: registro_sintomas)
-- ALTER TABLE public.registro_sintomas ENABLE ROW LEVEL SECURITY;


-- ── 2. Política: public.paciente ──────────────────────────────────────────────
-- Usuários autenticados têm acesso completo (admin gerencia, paciente lê o próprio)
CREATE POLICY "paciente_autenticado_tudo" ON public.paciente
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- Permite inserção anônima durante o cadastro (antes de confirmar e-mail)
CREATE POLICY "paciente_anon_inserir" ON public.paciente
  FOR INSERT TO anon
  WITH CHECK (true);


-- ── 3. Política: public.profissional ─────────────────────────────────────────
CREATE POLICY "profissional_autenticado_tudo" ON public.profissional
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "profissional_anon_inserir" ON public.profissional
  FOR INSERT TO anon
  WITH CHECK (true);


-- ── 4. Política: public.consulta ─────────────────────────────────────────────
CREATE POLICY "consulta_autenticado_tudo" ON public.consulta
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);


-- ── 5. Política: public.administrador ────────────────────────────────────────
CREATE POLICY "administrador_autenticado_tudo" ON public.administrador
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);


-- ── 6. Política: public.login ─────────────────────────────────────────────────
CREATE POLICY "login_autenticado_tudo" ON public.login
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- Permite inserção anônima durante o cadastro
CREATE POLICY "login_anon_inserir" ON public.login
  FOR INSERT TO anon
  WITH CHECK (true);


-- ── 7. (Opcional) registro_sintomas — se existir ──────────────────────────────
-- CREATE POLICY "sintomas_autenticado_tudo" ON public.registro_sintomas
--   FOR ALL TO authenticated
--   USING (true)
--   WITH CHECK (true);
