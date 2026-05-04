-- 005_recomendacoes_videos.sql
-- Tabela para recomendações de exercícios de fisioterapia via ML
-- +Físio +Saúde — UniCesumar

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabela: recomendacao_video
-- Armazena as recomendações enviadas pelo profissional ao paciente
-- após o encerramento de uma consulta.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recomendacao_video (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_consulta     UUID REFERENCES consulta(id) ON DELETE SET NULL,
    id_paciente     UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    id_profissional UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,

    -- Array JSON com os exercícios selecionados pelo profissional
    -- Estrutura de cada item:
    -- { "id": "shoulder_abduction_right",
    --   "nome_pt": "Abdução de Ombro (Direito)",
    --   "regiao_display": "Ombro Direito",
    --   "descricao": "...",
    --   "nivel_dificuldade": "intermediario",
    --   "duracao_min": 8,
    --   "url_video": "https://...",
    --   "score_similaridade": 0.842 }
    videos          JSONB NOT NULL DEFAULT '[]',

    -- Mensagem personalizada do profissional ao paciente
    mensagem        TEXT,

    -- Controle de leitura pelo paciente
    lida            BOOLEAN NOT NULL DEFAULT FALSE,
    lida_em         TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Índices para performance nas queries do app
-- ─────────────────────────────────────────────────────────────────────────────

-- Paciente buscando suas recomendações
CREATE INDEX IF NOT EXISTS idx_recomendacao_paciente
    ON recomendacao_video (id_paciente, created_at DESC);

-- Profissional consultando recomendações que enviou
CREATE INDEX IF NOT EXISTS idx_recomendacao_profissional
    ON recomendacao_video (id_profissional, created_at DESC);

-- Recomendações não lidas (badge de notificação)
CREATE INDEX IF NOT EXISTS idx_recomendacao_nao_lida
    ON recomendacao_video (id_paciente, lida)
    WHERE lida = FALSE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE recomendacao_video ENABLE ROW LEVEL SECURITY;

-- Paciente: lê apenas suas próprias recomendações
CREATE POLICY "paciente_le_proprias_recomendacoes"
    ON recomendacao_video FOR SELECT
    USING (
        id_paciente = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    );

-- Profissional: lê recomendações que enviou
CREATE POLICY "profissional_le_proprias_recomendacoes"
    ON recomendacao_video FOR SELECT
    USING (
        id_profissional = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    );

-- Profissional: pode inserir recomendações
CREATE POLICY "profissional_insere_recomendacoes"
    ON recomendacao_video FOR INSERT
    WITH CHECK (
        id_profissional = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    );

-- Paciente: pode marcar como lida (UPDATE apenas no campo lida)
CREATE POLICY "paciente_marca_lida"
    ON recomendacao_video FOR UPDATE
    USING (
        id_paciente = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    )
    WITH CHECK (
        id_paciente = (
            SELECT id FROM usuario
            WHERE supabase_user_id = auth.uid()
        )
    );

-- Administrador: acesso total
CREATE POLICY "admin_acesso_total_recomendacoes"
    ON recomendacao_video FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM usuario
            WHERE supabase_user_id = auth.uid()
              AND id_permissao = 3
        )
    );
