-- ============================================================
-- +Físio +Saúde — Migration 011
-- Descrição: Cria tabela de disponibilidade para dias específicos
-- ============================================================

CREATE TABLE IF NOT EXISTS disponibilidade (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_profissional UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    data DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fim TIME,
    disponivel BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(id_profissional, data, hora_inicio)
);

ALTER TABLE disponibilidade ENABLE ROW LEVEL SECURITY;

CREATE POLICY "autenticado_le_disponibilidade"
    ON disponibilidade FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "profissional_gerencia_disponibilidade"
    ON disponibilidade FOR ALL
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
