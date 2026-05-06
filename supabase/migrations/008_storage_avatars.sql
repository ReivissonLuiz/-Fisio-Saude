-- ============================================================
-- +Físio +Saúde — Migration 008
-- Descrição: Configuração do Storage para avatares (bucket e RLS)
-- ============================================================

-- Cria o bucket 'avatars' se não existir
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Habilita RLS no bucket (mesmo sendo público, a tabela de objetos precisa ter RLS)
-- Geralmente, a tabela storage.objects já tem RLS habilitado, mas as políticas precisam ser definidas.
-- Executar isso garante que as políticas serão exigidas.
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Remove políticas anteriores se existirem (para evitar erros de duplicação)
DROP POLICY IF EXISTS "Avatares são públicos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem enviar avatares" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem atualizar seus próprios avatares" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem deletar seus próprios avatares" ON storage.objects;

-- Política 1: Qualquer um pode visualizar os avatares (pois o bucket é público)
CREATE POLICY "Avatares são públicos"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Política 2: Qualquer usuário autenticado pode fazer upload de novos arquivos para este bucket
CREATE POLICY "Usuários autenticados podem enviar avatares"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
);

-- Política 3: Usuários autenticados podem atualizar imagens no bucket avatars
CREATE POLICY "Usuários podem atualizar seus próprios avatares"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
);

-- Política 4: Usuários autenticados podem deletar imagens
CREATE POLICY "Usuários podem deletar seus próprios avatares"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
);
