# Gestão de tarefas e usuários — CAD 2D / Planejador

## Primeiro acesso

Abra o Planejador e crie o primeiro Administrador com nome, login e senha
de pelo menos oito caracteres. Não existe senha inicial nem conta padrão.
Em Gestão de tarefas, use Usuários para cadastrar pessoas, editar seu perfil,
redefinir senhas e ativar/desativar acessos. Ao redefinir uma senha, as sessões
anteriores daquela conta são invalidadas.

| Tipo de acesso | Visão e operações |
|---|---|
| Administrador | Todas as tarefas, planejamento, criação/atribuição de tarefas e gestão de usuários |
| Usuário | Todas as tarefas, planejamento, criação/atribuição, respostas e andamento; não gerencia contas |
| Usuário restrito (my task only) | Somente tarefas de sua responsabilidade, inclusive no acesso direto pelo CAD; pode responder e devolver suas tarefas |
| Visualizador | Todas as tarefas e seu histórico em leitura; não cria, atribui, responde, devolve ou altera desenhos associados |

Mudanças de perfil e desativação são verificadas em cada operação. O Administrador
não pode remover ou rebaixar o último Administrador ativo. Senhas são protegidas
por PBKDF2-HMAC-SHA256 (600 mil iterações) com salt individual e aleatório pelo
BCrypt do Windows. Cinco falhas consecutivas bloqueiam o login por um minuto.
Sessões expiram após oito horas; a senha não é repassada ao outro aplicativo.

## Fluxo de trabalho

1. No Planejador, Gestão de tarefas → Nova tarefa. Informe título, detalhes e
   responsável. O arquivo CAD pode ser associado agora ou ao devolver a tarefa.
2. Uma tarefa do cronograma existente também pode ser enviada: no Planejamento,
   escolha um usuário cadastrado em Responsável, selecione a tarefa e use
   Enviar tarefa selecionada ao CAD. Salve o projeto quando solicitado.
3. Abrir no CAD 2D leva a tarefa, a identidade e o arquivo associado para o CAD.
4. A barra lateral do CAD contém 2D, Tarefa e Gestão. Tarefa mostra os detalhes,
   o arquivo, responsável, situação, progresso e histórico de respostas.
5. A aba superior Gestão oferece Tarefa e arquivo, Responder tarefa, Devolver
   tarefa e Voltar Planejador. A resposta deve dizer o que foi feito e o que falta.
6. Ao devolver, o CAD pede para salvar o desenho. Cancelar o salvamento cancela
   a devolução. Se a tarefa não possui arquivo, o arquivo salvo é associado
   automaticamente. Uma associação existente não é substituída silenciosamente.
7. O Planejador mostra a tarefa como Devolvida / em revisão. O gestor pode
   registrar pendências ou aceitar e marcar Concluída. O resumo mostra as
   quantidades concluídas, pendentes e devolvidas.
8. Para refletir um retorno no cronograma de origem, selecione a tarefa na
   Gestão e use Aplicar retorno ao planejamento. A aplicação requer confirmação
   e preserva a separação dos arquivos dos aplicativos. Salve o planejamento.

Tarefas novas sem arquivo utilizam o desenho atual do CAD ao serem abertas;
o vínculo só é consolidado no salvamento e na devolução. As tarefas enviadas
do cronograma guardam o arquivo de origem e o ID estável da tarefa.

## Persistência e escopo

Esta implementação é um espaço de trabalho local compartilhado pelos aplicativos:
`%LOCALAPPDATA%\EngenhariaArquitetura\workspace.json`. Contas, atribuições,
arquivos associados e respostas persistem nesse arquivo. Gravações usam bloqueio
exclusivo e substituição atômica; os arquivos do CAD e do Planejador continuam
independentes. O instalador não remove os dados desse espaço de trabalho.

É possível selecionar outro arquivo de espaço de trabalho com `--workspace`.
Não há serviço de sincronização de identidades/tarefas entre computadores ou
integração desta gestão com o PostgreSQL opcional. A restrição por perfil é
aplicada pelos aplicativos; proteção contra leitura/alteração externa do arquivo
depende das permissões do Windows. Não é uma barreira de segurança entre pessoas
com acesso irrestrito ao mesmo arquivo ou à mesma conta do Windows.

## Validação

- `shared/tests/test_workflow.lpr`: 38 verificações isoladas de autenticação,
  perfis, filtros, acesso direto, associação de arquivo, devolução, histórico,
  mudança de perfil, desativação, invalidação de sessões e ausência de senha em texto.
- `cad2d/tests/test_cad2d.lpi`: 47 verificações, incluindo a barra lateral, aba
  Gestão, troca entre tarefa e 2D e proibição de edição por Visualizador.
- Os testes integram os scripts de geração Windows e de compilação com Wine.
- A inspeção visual manual do fluxo completo continua necessária.
