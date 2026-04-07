/**
 * Edge Function: delete-auth-user
 * +Físio +Saúde — Remove um usuário do Supabase Auth permanentemente.
 *
 * Segurança:
 *  - Requer JWT válido no header Authorization
 *  - Verifica que o chamador é do tipo 'Administrador' na tabela login
 *  - Usa a service_role key (disponível automaticamente no ambiente da Edge Function)
 *
 * Chamada esperada (POST):
 *  Body: { "user_id": "<supabase_auth_uid>" }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  // Responde ao preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Verifica se há token de autenticação
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Não autorizado.' }, 401);
    }

    const sbUrl = Deno.env.get('SUPABASE_URL')!;
    const sbAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const sbServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // 2. Cria client com as credenciais do chamador para validar quem está chamando
    const callerClient = createClient(sbUrl, sbAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user: caller },
      error: callerError,
    } = await callerClient.auth.getUser();

    if (callerError || !caller) {
      return json({ error: 'Token inválido ou expirado.' }, 401);
    }

    // 3. Verifica se o chamador é Administrador
    const { data: loginData } = await callerClient
      .from('login')
      .select('tipo_usuario')
      .eq('supabase_user_id', caller.id)
      .maybeSingle();

    if (loginData?.tipo_usuario !== 'Administrador') {
      return json(
        { error: 'Acesso negado. Apenas administradores podem executar esta ação.' },
        403,
      );
    }

    // 4. Lê o user_id a ser excluído
    const body = await req.json();
    const { user_id } = body as { user_id?: string };

    if (!user_id) {
      return json({ error: 'O campo user_id é obrigatório.' }, 400);
    }

    // Proteção: impede que o ADM exclua a si mesmo
    if (user_id === caller.id) {
      return json({ error: 'Você não pode excluir sua própria conta.' }, 400);
    }

    // 5. Exclui do Supabase Auth usando o client com service_role
    const adminClient = createClient(sbUrl, sbServiceKey);
    const { error: deleteError } =
      await adminClient.auth.admin.deleteUser(user_id);

    if (deleteError) {
      return json({ error: deleteError.message }, 500);
    }

    return json({ success: true, message: 'Usuário excluído do Auth com sucesso.' });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

/** Helper para retornar JSON com headers CORS */
function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
