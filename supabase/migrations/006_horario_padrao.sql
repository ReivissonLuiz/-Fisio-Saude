-- 006_horario_padrao.sql
-- Horário padrão de atendimento do profissional (por dia da semana)
-- +Físio +Saúde — UniCesumar
--
-- Diferença em relação à tabela `disponibilidade`:
--   disponibilidade → slots específicos de data+hora (ex: "10/05 às 09:00")
--   horario_padrao  → padrão semanal recorrente (ex: "toda Segunda das 08h às 17h")
--
-- O app usa o horario_padrao como fallback quando não há slots específicos.
-- Se nem horario_padrao existir, considera 07:00–19:00 em todos os dias úteis.

CREATE TABLE IF NOT EXISTS horario_padrao (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_profissional UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,

    -- 0 = Domingo, 1 = Segunda, 2 = Terça, 3 = Quarta,
    -- 4 = Quinta,  5 = Sexta,   6 = Sábado
    dia_semana      SMALLINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),

    hora_inicio     TIME NOT NULL DEFAULT '07:00',
    hora_fim        TIME NOT NULL DEFAULT '19:00',

    -- Permite desativar um dia sem excluir o registro
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Cada profissional tem no máximo um padrão por dia da semana
    UNIQUE (id_profissional, dia_semana)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Índices
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_horario_padrao_profissional
    ON horario_padrao (id_profissional, dia_semana);

-- ─────────────────────────────────────────────────────────────────────────────
-- Trigger para atualizar updated_at automaticamente
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_horario_padrao_updated_at
    BEFORE UPDATE ON horario_padrao
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE horario_padrao ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado pode VER o horário de qualquer profissional
-- (necessário para o paciente visualizar disponibilidade na busca)
CREATE POLICY "autenticado_le_horario_padrao"
    ON horario_padrao FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Profissional só gerencia seu próprio horário
CREATE POLICY "profissional_gerencia_proprio_horario"
    ON horario_padrao FOR ALL
    USING (
        id_profissional = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    )
    WITH CHECK (
        id_profissional = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    );

-- Administrador: acesso total
CREATE POLICY "admin_acesso_total_horario_padrao"
    ON horario_padrao FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM usuario
            WHERE supabase_user_id = auth.uid()
              AND id_permissao = 3
        )
    );
