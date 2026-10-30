# Versão 0.04 — instalador 004

Data: 30/10/2026. Plataforma: Windows 64 bits.

## Conteúdo

- Central `engenhariaarquitetura.exe`, com atalho principal selecionado por padrão.
- Planejador e CAD 2D, ambos com ícones incorporados.
- CAD exclusivamente 2D, menus nativos no topo, ferramentas e abas em azul no
  padrão do MultiCNC, camadas, navegação e atalhos associados às funções disponíveis.
- Barra lateral 2D/Tarefa/Gestão e aba superior Gestão no CAD.
- Gestão local compartilhada: tarefa, responsável, arquivo associado, respostas,
  progresso, situação e histórico de devoluções.
- Contas e tipos Administrador, Usuário, Usuário restrito (my task only) e
  Visualizador. Primeiro Administrador criado no primeiro acesso, sem senha padrão.
- Respostas e devolução do CAD para o Planejador; associação automática quando
  a tarefa ainda não tem arquivo; aplicação explícita do retorno no cronograma.
- Histórico de geometria com AI Project Core/aiundohistory do projeto CHATGPT.

Veja o [guia de gestão e usuários](Gestao_Tarefas_Usuarios.md) para instruções
de operação e a matriz completa de permissões.

## Compilação e arquivos

Configuração: `installer/VERSION.ini`, AppVersion=0.04 e SetupSeq=004.
Os três projetos Lazarus são recompilados para x86_64/win64. Os executáveis têm
metadados de versão 0.4.0; a versão comercial do instalador é 0.04.

O script gera `bin/setup_engenhariaarquitetura_004.exe`, sua cópia em `setup`,
`setup/build-manifest-004.json`, `setup/qa-tests-004.json` e atualiza SHA256SUMS.
O manifesto identifica o commit-base, alterações locais e hashes dos arquivos
instalados; não equivale a publicação de uma release no GitHub.

## Verificações

| Suíte | Verificações |
|---|---:|
| Planejador / núcleo e cronograma | 52 |
| CAD / geometria, interface e perfis | 47 |
| Gestão / autenticação, permissões e retorno | 38 |
| Total | 137 |

O resultado efetivo da geração está em qa-tests-004.json. Falha de compilação
ou de teste interrompe o empacotamento. As somas SHA-256 permitem conferir a
integridade dos binários e do instalador.

## Limites e pendências

A gestão usa um arquivo local compartilhado entre os aplicativos. Não há
sincronização de contas e tarefas entre computadores nem integração desse fluxo
com o PostgreSQL opcional. A proteção de acesso externo aos arquivos depende
das permissões do Windows. A autenticação deste pacote usa BCrypt do Windows.

O CAD não produz imagens ou modelos 3D e não tem importação DWG nativa. Os
demais módulos da plataforma continuam indisponíveis até implementação e compilação.
Os testes automatizados não substituem a revisão visual manual do fluxo completo,
da instalação e da desinstalação, que permanece pendente.
