# Setup e configuração compartilhada

O lançador EngenhariaArquitetura, o Planejador e o CAD 2D possuem o menu
**Setup → Configurações compartilhadas**. Todos utilizam o mesmo arquivo por
usuário do Windows:

`%LOCALAPPDATA%\EngenhariaArquitetura\config.json`

Não são mantidas cópias de preferências por aplicativo. As configurações são
relidas a cada acesso; uma alteração fica disponível aos demais aplicativos
sem exigir reinicialização. O instalador não distribui um arquivo de preferências
preenchido e não sobrescreve as escolhas do usuário ao atualizar os programas.

## Campos

- **Último projeto aberto:** caminho completo, atualizado após abertura ou
  salvamento bem-sucedidos. É informativo no Setup. Não altera o projeto ao editar
  outras preferências. Arquivos rejeitados ou operações canceladas não substituem
  esse histórico. Também são mantidos os últimos projetos do Planejador e do CAD
  em campos separados dentro do mesmo arquivo.
- **URL do servidor de nuvem:** endereço HTTP/HTTPS, opcional e editável.
  Credenciais embutidas na URL não são aceitas. O endereço fica disponível por
  configuração comum; esta entrega não implementa uma API HTTP nem sincronização
  de projetos/tarefas. A integração PostgreSQL opcional existente não é convertida
  automaticamente por esse campo.
- **Último login digitado:** pode ser editado no Setup e é atualizado quando o
  usuário confirma a identificação. Preenche o campo Login do próximo acesso,
  inclusive no outro aplicativo. Pode ser alterado antes de entrar. Não concede
  acesso automaticamente e não armazena senha nem token de sessão.

## Reabrir projetos

**Setup → Abrir último projeto** no lançador abre o programa correspondente ao
último arquivo geral. No Planejador e no CAD, a mesma opção usa o último arquivo
compatível daquele aplicativo. Arquivos ausentes geram uma mensagem e o histórico
é preservado. A troca mantém a confirmação de salvamento de alterações atuais.
Não há reabertura automática na inicialização: o Planejador continua abrindo
primeiro na sua tela de planejamento para os perfis permitidos.

## Estrutura do arquivo

```json
{
  "schema_version": "1.0",
  "last_project": "C:/Projetos/planta.eacad",
  "last_planner_project": "C:/Projetos/ubs.plan.json",
  "last_cad2d_project": "C:/Projetos/planta.eacad",
  "cloud_server_url": "https://servidor.exemplo",
  "last_login": "usuario"
}
```

O código comum está em `shared/ea_config.pas` e a janela em
`shared/ea_config_ui.pas`. As gravações usam bloqueio entre processos, releitura
sob bloqueio e substituição por arquivo temporário. Atualizar um campo preserva
os demais. O Setup grava apenas os campos alterados, evitando substituir um novo
último projeto registrado enquanto a janela estava aberta. Erros de leitura e
versões desconhecidas são reportados, sem sobrescrever silenciosamente o arquivo.

Para testes e execução portátil controlada, `EA_CONFIG_FILE` pode apontar para
um arquivo alternativo. Todos os processos da plataforma devem receber o mesmo
valor; sem a variável, todos usam o caminho padrão acima. Os testes usam arquivos
temporários isolados e validam gravações simultâneas sem alterar preferências reais.

O arquivo `workspace.json`, que contém cadastros e tarefas, permanece separado
das preferências. A configuração compartilhada vale para os aplicativos executáveis
atuais; os módulos ainda em especificação devem reutilizar a mesma unidade quando
forem implementados.
