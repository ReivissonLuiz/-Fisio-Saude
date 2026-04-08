# +Físio +Saúde

Projeto desenvolvido por estudantes do curso de Análise e Desenvolvimento de Sistemas da UniCesumar.

## Sobre o Sistema

O +Físio +Saúde é uma plataforma voltada para a gestão de atendimentos fisioterapêuticos, oferecendo uma ponte de comunicação e controle entre clínicas, profissionais e pacientes. O sistema opera de maneira integrada utilizando tecnologia front-end baseada em Flutter, com suporte à plataforma Web, e integração direta a um banco de dados relacional Supabase (PostgreSQL).

### Estrutura e Funcionamento

- **Gestão de Acessos:** O núcleo da aplicação consolida todos os perfis de usuários em uma estrutura de banco de dados unificada, onde o perfil e a permissão de acesso (Paciente, Profissional ou Administrador) são dinamicamente interpretados, garantindo centralização e integridade dos dados.
- **Portal do Paciente:** Oferece ferramentas para que as pessoas cadastradas busquem profissionais, realizem acompanhamento de saúde, comuniquem dores e sintomas e acompanhem o seu progresso geral de maneira unificada.
- **Portal do Profissional:** Profissionais de fisioterapia e terapia ocupacional possuem acesso aos registros de sintomas dos pacientes, controle da disponibilidade de atendimento e gerenciamento de interações clínicas diretas.
- **Portal Administrativo:** Fornece recursos analíticos e gerenciais essenciais para a coordenação da plataforma, permitindo habilitar, desabilitar e excluir contas permanentemente na base de dados, respeitando o fluxo da informação e normas vigentes.

O planejamento arquitetural da aplicação mantém as permissões sob rigorosas diretrizes de segurança, utilizando processos automatizados e políticas configuradas diretamente na camada do banco de dados (Row Level Security) para proteger informações clinicamente sensíveis.

## Equipe de Desenvolvimento

* BRUNO REZENDE DE LIMA - 24081546-2
* REIVISSON LUIZ CORDEIRO - 24379632-2
* TALISSA EBSEN TEIXEIRA - 24214429-2
* VINICIUS EDUARDO FRANÇA - 24370532-2
* WILLY ROBERT VIANA - 24403787-2

## Orientador

* Prof. Dr. Alexandre Bento
