-- ============================================================
-- +Físio +Saúde — Migration 022
-- Descrição: Função SECURITY DEFINER para registro de usuários.
--            Bypassa RLS no INSERT da tabela usuario, resolvendo o
--            erro 401 que ocorre quando o signUp não cria sessão
--            (email já existente em auth.users ou confirmação ativada).
-- ============================================================

CREATE OR REPLACE FUNCTION public.registrar_usuario(
  p_supabase_user_id  UUID,
  p_id_permissao      INTEGER,
  p_nome              TEXT,
  p_email             TEXT,
  p_cpf               TEXT     DEFAULT NULL,
  p_data_nasc         DATE     DEFAULT NULL,
  p_telefone          TEXT     DEFAULT NULL,
  p_genero            TEXT     DEFAULT NULL,
  p_cep               TEXT     DEFAULT NULL,
  p_logradouro        TEXT     DEFAULT NULL,
  p_numero            TEXT     DEFAULT NULL,
  p_complemento       TEXT     DEFAULT NULL,
  p_bairro            TEXT     DEFAULT NULL,
  p_cidade            TEXT     DEFAULT NULL,
  p_uf                TEXT     DEFAULT NULL,
  p_cargo             TEXT     DEFAULT NULL,
  p_crefito           TEXT     DEFAULT NULL,
  p_especialidade     TEXT     DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  -- Valida que o supabase_user_id realmente existe em auth.users
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_supabase_user_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado no sistema de autenticação.';
  END IF;

  -- Insere na tabela usuario (SECURITY DEFINER bypassa RLS)
  INSERT INTO public.usuario (
    supabase_user_id, id_permissao, nome, email,
    cpf, data_nasc, telefone, genero,
    cep, logradouro, numero, complemento,
    bairro, cidade, uf,
    cargo, crefito, especialidade, ativo
  ) VALUES (
    p_supabase_user_id, p_id_permissao, p_nome, p_email,
    p_cpf, p_data_nasc, p_telefone, p_genero,
    p_cep, p_logradouro, p_numero, p_complemento,
    p_bairro, p_cidade, p_uf,
    p_cargo, p_crefito, p_especialidade, true
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Permite que anon e authenticated chamem a função
GRANT EXECUTE ON FUNCTION public.registrar_usuario TO anon;
GRANT EXECUTE ON FUNCTION public.registrar_usuario TO authenticated;

NOTIFY pgrst, 'reload schema';
