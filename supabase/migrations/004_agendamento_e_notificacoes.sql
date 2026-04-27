-- ============================================================
-- +Físio +Saúde — Migration 004
-- Descrição: Tabela de disponibilidade do profissional e
--            tabela de notificações in-app.
-- Execute no Supabase SQL Editor antes de usar o agendamento.
-- ============================================================

-- ─── 1. Tabela de Disponibilidade do Profissional ─────────────────────────
-- Armazena os horários que o profissional define como disponíveis.
-- Cada linha representa um slot de 1 hora (ex: segunda 09:00).

CREATE TABLE IF NOT EXISTS disponibilidade_profissional (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  id_profissional  UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  dia_semana       INTEGER     NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    -- 0=Domingo, 1=Segunda, 2=Terça, 3=Quarta, 4=Quinta, 5=Sexta, 6=Sábado
  hora_inicio      TIME        NOT NULL,  -- ex: '09:00'
  hora_fim         TIME        NOT NULL,  -- ex: '10:00'
  ativo            BOOLEAN     NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (id_profissional, dia_semana, hora_inicio)
);

-- ─── 2. Tabela de Notificações In-App ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS notificacao (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  id_destinatario  UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  titulo           VARCHAR(120) NOT NULL,
  corpo            TEXT        NOT NULL,
  tipo             VARCHAR(30) NOT NULL DEFAULT 'info',
    -- 'agendamento', 'cancelamento', 'reagendamento', 'info'
  id_consulta      UUID        REFERENCES consulta(id) ON DELETE SET NULL,
  lida             BOOLEAN     NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 3. RLS ───────────────────────────────────────────────────────────────

ALTER TABLE disponibilidade_profissional ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificacao                  ENABLE ROW LEVEL SECURITY;

-- Disponibilidade: qualquer autenticado pode ler (para agendar)
CREATE POLICY "disp_select_autenticado" ON disponibilidade_profissional
  FOR SELECT TO authenticated USING (true);

-- Disponibilidade: profissional gerencia a própria
CREATE POLICY "disp_insert_proprio" ON disponibilidade_profissional
  FOR INSERT TO authenticated
  WITH CHECK (
    id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
  );

CREATE POLICY "disp_update_proprio" ON disponibilidade_profissional
  FOR UPDATE TO authenticated
  USING (
    id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
  );

CREATE POLICY "disp_delete_proprio" ON disponibilidade_profissional
  FOR DELETE TO authenticated
  USING (
    id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
  );

-- Notificação: destinatário lê as próprias, qualquer autenticado insere
CREATE POLICY "notif_select_proprio" ON notificacao
  FOR SELECT TO authenticated
  USING (
    id_destinatario IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

CREATE POLICY "notif_insert_autenticado" ON notificacao
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "notif_update_proprio" ON notificacao
  FOR UPDATE TO authenticated
  USING (
    id_destinatario IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
  );

-- ─── 4. Índices ───────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_disp_profissional  ON disponibilidade_profissional (id_profissional);
CREATE INDEX IF NOT EXISTS idx_disp_dia_semana    ON disponibilidade_profissional (dia_semana);
CREATE INDEX IF NOT EXISTS idx_notif_destinatario ON notificacao (id_destinatario);
CREATE INDEX IF NOT EXISTS idx_notif_lida         ON notificacao (lida);
CREATE INDEX IF NOT EXISTS idx_notif_created_at   ON notificacao (created_at DESC);

-- ─── 5. Também atualizar a policy de UPDATE da consulta ───────────────────
-- Permitir que o PACIENTE também cancele/reagende a própria consulta

DROP POLICY IF EXISTS "consulta_update" ON consulta;

CREATE POLICY "consulta_update" ON consulta
  FOR UPDATE TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );
