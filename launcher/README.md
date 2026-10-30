# EngenhariaArquitetura Launcher

Central de aplicativos inspirada no MultiSuite do MultiCNC, com código independente.

- Lazarus / Free Pascal, interfaces LCL (Windows e Linux).
- Exibe os sete aplicativos planejados, com categorias e descrição.
- Verifica a existência dos executáveis antes de habilitar **Abrir**.
- Inicialmente somente o Planejador está implementado; os outros aparecem indisponíveis até que sejam compilados.
- Busca executáveis instalados junto ao launcher ou nas pastas de desenvolvimento.
- O launcher não exige PostgreSQL nem substitui os aplicativos independentes.

## Compilação

Abrir `launcher/src/app/engenhariaarquitetura.lpi` no Lazarus e compilar. A saída padrão fica na pasta do projeto, podendo ser configurada para `bin/` no instalador.

## Validação pendente

Compilar Windows e Linux, executar o launcher, verificar o posicionamento dos cartões e a abertura do Planejador, e incluir o launcher na construção do instalador. O launcher não implementa ainda a gestão de projetos/arq. do workspace MultiSuite.
