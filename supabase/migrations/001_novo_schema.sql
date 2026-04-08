-- ============================================================
-- +Físio +Saúde — Novo Schema Unificado
-- Versão: 001
-- Descrição: Consolida paciente, profissional e administrador
--            em uma única tabela `usuario` com FK para `permissao`.
--            Reestrutura `login` como log de acessos.
-- ============================================================

-- ─── 0. Limpar tabelas antigas (se existirem) ──────────────────────────────

DROP TABLE IF EXISTS lgpd_consentimento CASCADE;
DROP TABLE IF EXISTS logs_auditoria    CASCADE;
DROP TABLE IF EXISTS login             CASCADE;
DROP TABLE IF EXISTS consulta          CASCADE;
DROP TABLE IF EXISTS registro_sintomas CASCADE;
DROP TABLE IF EXISTS administrador     CASCADE;
DROP TABLE IF EXISTS profissional      CASCADE;
DROP TABLE IF EXISTS paciente          CASCADE;
DROP TABLE IF EXISTS usuario           CASCADE;
DROP TABLE IF EXISTS permissao         CASCADE;

-- ─── 1. Tabela de Permissões ───────────────────────────────────────────────

CREATE TABLE permissao (
  id         SERIAL       PRIMARY KEY,
  nome       VARCHAR(50)  NOT NULL UNIQUE,
  descricao  TEXT,
  nivel      INTEGER      NOT NULL UNIQUE  -- 1=Paciente, 2=Profissional, 3=Administrador
);

-- Dados fixos: imutáveis em runtime
INSERT INTO permissao (id, nome, descricao, nivel) VALUES
  (1, 'Paciente',       'Acesso ao próprio perfil, consultas e registro de sintomas.', 1),
  (2, 'Profissional',   'Acesso à agenda, pacientes vinculados e ferramentas clínicas.', 2),
  (3, 'Administrador',  'Acesso total ao sistema: gestão de usuários, relatórios e configurações.', 3);

-- ─── 2. Tabela de Usuários (unificada) ────────────────────────────────────

CREATE TABLE usuario (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  supabase_user_id  UUID         UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  id_permissao      INTEGER      NOT NULL REFERENCES permissao(id),

  -- Dados pessoais (comuns a todos)
  nome              VARCHAR(150) NOT NULL,
  email             VARCHAR(150) NOT NULL UNIQUE,
  cpf               VARCHAR(11)  UNIQUE,
  data_nasc         DATE,
  telefone          VARCHAR(11),
  genero            VARCHAR(30),

  -- Endereço
  cep               VARCHAR(8),
  logradouro        VARCHAR(150),
  numero            VARCHAR(20),
  complemento       VARCHAR(100),
  bairro            VARCHAR(100),
  cidade            VARCHAR(100),
  uf                VARCHAR(2),

  -- Campos exclusivos de Profissional (nullable para outros tipos)
  crefito           VARCHAR(20),
  especialidade     VARCHAR(100),

  -- Campos exclusivos de Administrador (nullable para outros tipos)
  cargo             VARCHAR(80),

  -- Controle
  ativo             BOOLEAN      NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION atualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuario_updated_at
  BEFORE UPDATE ON usuario
  FOR EACH ROW EXECUTE FUNCTION atualizar_updated_at();

-- ─── 3. Tabela Login (log de acessos) ────────────────────────────────────

CREATE TABLE login (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  supabase_user_id UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  id_usuario       UUID        REFERENCES usuario(id) ON DELETE SET NULL,
  email            VARCHAR(150),
  data_hora        TIMESTAMPTZ NOT NULL DEFAULT now(),
  status           VARCHAR(10) NOT NULL CHECK (status IN ('sucesso', 'falha')),
  dispositivo      VARCHAR(100),
  ip_address       INET
);

-- ─── 4. Tabela de Consultas ───────────────────────────────────────────────

CREATE TABLE consulta (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  id_paciente      UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  id_profissional  UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  data_hora        TIMESTAMPTZ NOT NULL,
  duracao_min      INTEGER,
  status           VARCHAR(20) NOT NULL DEFAULT 'agendada'
                   CHECK (status IN ('agendada', 'realizada', 'cancelada')),
  observacoes      TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 5. Tabela de Sintomas ────────────────────────────────────────────────

CREATE TABLE registro_sintomas (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  id_paciente  UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  categoria    VARCHAR(80),
  intensidade  INTEGER     CHECK (intensidade BETWEEN 1 AND 10),
  descricao    TEXT,
  data_hora    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 6. Row Level Security ────────────────────────────────────────────────

ALTER TABLE permissao          ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario            ENABLE ROW LEVEL SECURITY;
ALTER TABLE login              ENABLE ROW LEVEL SECURITY;
ALTER TABLE consulta           ENABLE ROW LEVEL SECURITY;
ALTER TABLE registro_sintomas  ENABLE ROW LEVEL SECURITY;

-- Função SECURITY DEFINER para verificar se o usuário é administrador (ignora RLS)
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

-- permissao: leitura pública (todos os usuários autenticados)
CREATE POLICY "permissao_leitura" ON permissao
  FOR SELECT TO authenticated USING (true);

-- usuario: cada usuário lê/edita apenas o próprio registro
CREATE POLICY "usuario_proprio_select" ON usuario
  FOR SELECT TO authenticated
  USING (supabase_user_id = auth.uid());

CREATE POLICY "usuario_proprio_update" ON usuario
  FOR UPDATE TO authenticated
  USING (supabase_user_id = auth.uid());

-- usuario: administradores lêem todos os registros
CREATE POLICY "usuario_admin_select" ON usuario
  FOR SELECT TO authenticated
  USING (check_is_admin());

-- usuario: administradores atualizam qualquer registro
CREATE POLICY "usuario_admin_update" ON usuario
  FOR UPDATE TO authenticated
  USING (check_is_admin());

-- usuario: insert permitido (necessário no cadastro — auth ainda não tem uid em alguns fluxos)
CREATE POLICY "usuario_insert" ON usuario
  FOR INSERT TO authenticated WITH CHECK (true);

-- login: insert aberto (registrar logs de tentativas de acesso)
CREATE POLICY "login_insert" ON login
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "login_admin_select" ON login
  FOR SELECT TO authenticated
  USING (check_is_admin());

-- consulta: paciente vê as próprias, profissional vê as suas, admin vê todas
CREATE POLICY "consulta_paciente_select" ON consulta
  FOR SELECT TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

CREATE POLICY "consulta_insert" ON consulta
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "consulta_update" ON consulta
  FOR UPDATE TO authenticated
  USING (
    id_profissional IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

CREATE POLICY "consulta_delete" ON consulta
  FOR DELETE TO authenticated
  USING (check_is_admin());

-- registro_sintomas: paciente CRUD dos próprios, admin lê todos
CREATE POLICY "sintomas_proprio" ON registro_sintomas
  FOR ALL TO authenticated
  USING (
    id_paciente IN (SELECT id FROM usuario WHERE supabase_user_id = auth.uid())
    OR check_is_admin()
  );

-- ─── 7. Índices de Performance ────────────────────────────────────────────

CREATE INDEX idx_usuario_supabase_id  ON usuario (supabase_user_id);
CREATE INDEX idx_usuario_email        ON usuario (email);
CREATE INDEX idx_usuario_cpf          ON usuario (cpf);
CREATE INDEX idx_usuario_permissao    ON usuario (id_permissao);
CREATE INDEX idx_login_usuario        ON login (id_usuario);
CREATE INDEX idx_login_data_hora      ON login (data_hora DESC);
CREATE INDEX idx_consulta_paciente    ON consulta (id_paciente);
CREATE INDEX idx_consulta_profissional ON consulta (id_profissional);
CREATE INDEX idx_consulta_data_hora   ON consulta (data_hora);
CREATE INDEX idx_sintomas_paciente    ON registro_sintomas (id_paciente);
