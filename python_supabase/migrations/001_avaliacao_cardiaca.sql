-- ============================================================
-- Migração 001: Tabela avaliacao_cardiaca
-- +Físio +Saúde — Integração com Kaggle Heart Disease Dataset
--
-- Execute este script no Supabase SQL Editor antes de rodar
-- o pipeline de ingestão Python.
-- ============================================================

-- Habilita extensão UUID (já ativa por padrão no Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── Tabela principal ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS avaliacao_cardiaca (
    id                  UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    id_avaliacao        UUID        REFERENCES avaliacao(id) ON DELETE SET NULL,
    id_paciente         UUID        NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,

    -- Dados demográficos básicos do dataset
    idade               INT,
    sexo                SMALLINT    CHECK (sexo IN (0, 1)),   -- 1=Masculino, 0=Feminino

    -- Sinais vitais e exames
    tipo_dor_peito      SMALLINT    CHECK (tipo_dor_peito BETWEEN 0 AND 3),
    pressao_repouso     INT,                                   -- trestbps (mmHg)
    colesterol          INT,                                   -- chol (mg/dl)
    glicemia_jejum      BOOLEAN,                               -- fbs > 120 mg/dl
    ecg_repouso         SMALLINT    CHECK (ecg_repouso IN (0, 1, 2)),

    -- Dados de esforço/exercício
    freq_cardiaca_max   INT,                                   -- thalach
    angina_exercicio    BOOLEAN,                               -- exang
    depressao_st        NUMERIC(5, 2),                         -- oldpeak
    inclinacao_st       SMALLINT    CHECK (inclinacao_st BETWEEN 0 AND 2),

    -- Exames complementares
    vasos_principais    SMALLINT    CHECK (vasos_principais BETWEEN 0 AND 3),  -- ca
    thal                SMALLINT    CHECK (thal BETWEEN 0 AND 2),              -- 0=normal, 1=fixo, 2=reversível

    -- Desfecho clínico (campo target do dataset)
    doenca_cardiaca     BOOLEAN     NOT NULL,                  -- target: 1=sim, 0=não

    -- Rastreabilidade da importação
    fonte               TEXT        NOT NULL DEFAULT 'kaggle:johnsmith88/heart-disease-dataset',
    importado_em        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Chave única para garantir idempotência (evita duplicatas em re-execuções)
    CONSTRAINT uq_avaliacao_cardiaca_paciente_import
        UNIQUE (id_paciente, fonte, importado_em)
);

-- ─── Índices de consulta ─────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_avc_id_paciente   ON avaliacao_cardiaca (id_paciente);
CREATE INDEX IF NOT EXISTS idx_avc_doenca        ON avaliacao_cardiaca (doenca_cardiaca);
CREATE INDEX IF NOT EXISTS idx_avc_id_avaliacao  ON avaliacao_cardiaca (id_avaliacao);

-- ─── Row Level Security (RLS) ────────────────────────────────────────────────
ALTER TABLE avaliacao_cardiaca ENABLE ROW LEVEL SECURITY;

-- Profissionais podem ver todos os registros
CREATE POLICY "profissional_leitura_avaliacao_cardiaca"
    ON avaliacao_cardiaca FOR SELECT
    USING (true);

-- Apenas service_role pode inserir/atualizar (pipeline Python)
CREATE POLICY "service_insercao_avaliacao_cardiaca"
    ON avaliacao_cardiaca FOR INSERT
    WITH CHECK (true);

CREATE POLICY "service_atualizacao_avaliacao_cardiaca"
    ON avaliacao_cardiaca FOR UPDATE
    USING (true);

-- ─── Comentários descritivos ─────────────────────────────────────────────────
COMMENT ON TABLE  avaliacao_cardiaca                    IS 'Avaliações cardiovasculares importadas do dataset Kaggle (Heart Disease) e avaliações clínicas do sistema.';
COMMENT ON COLUMN avaliacao_cardiaca.tipo_dor_peito     IS '0=angina típica, 1=angina atípica, 2=dor não-anginosa, 3=assintomático';
COMMENT ON COLUMN avaliacao_cardiaca.ecg_repouso        IS '0=normal, 1=anormalidade ST-T, 2=hipertrofia ventricular esquerda';
COMMENT ON COLUMN avaliacao_cardiaca.inclinacao_st      IS '0=ascendente, 1=plana, 2=descendente';
COMMENT ON COLUMN avaliacao_cardiaca.thal               IS '0=normal, 1=defeito fixo, 2=defeito reversível';
COMMENT ON COLUMN avaliacao_cardiaca.doenca_cardiaca    IS 'true = presença de doença cardíaca (target=1 no dataset original)';
