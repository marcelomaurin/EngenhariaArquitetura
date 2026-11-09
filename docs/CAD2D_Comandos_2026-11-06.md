# CAD 2D — comandos e componentes de planta baixa

Revisão de 06/11/2026, implementada no projeto local `D:\projetos\maurinsoft\EngenhariaArquitetura`.

## Referências consultadas

- [Autodesk — fluxo de objetos arquitetônicos](https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-Architecture/files/GUID-508C88DB-2CB7-4D0C-A60D-8D4CCC7CC5A6.htm): paredes, portas, janelas, aberturas, escadas e espaços.
- [Autodesk — paletas de ferramentas](https://help.autodesk.com/cloudhelp/2022/ENU/AutoCAD-Architecture/files/GUID-91E5C61F-F1CC-4390-AE83-D6549F9E0275.htm): organização de ferramentas e componentes.
- [Autodesk — comandos](https://www.autodesk.com/shortcuts/autocad): ARC, ARRAY, SCALE, TEXT e demais comandos de edição.
- [Autodesk — Stretch](https://help.autodesk.com/cloudhelp/2022/ENU/AutoCAD-DidYouKnow/files/GUID-19FDC9E4-049E-40BA-AB6D-58A4C2557570.htm): deslocamento de vértices dentro de janela de seleção.

As referências orientam comportamento e organização; nenhum código ou biblioteca de blocos Autodesk foi copiado. Esta implementação não reproduz integralmente o AutoCAD ou seu toolset Architecture.

## Recursos disponíveis

| Área | Implementação |
|---|---|
| Formas | Linha e retângulo existentes; círculo existente; polilinha contínua; arco por centro/início/fim; elipse; polígono de seis lados; hachura diagonal retangular |
| Modificação | Mover, copiar, girar, escalar e espelhar a seleção/grupo; Stretch por janela de vértices; array retangular |
| Operações anteriores | Offset, aparar/trim, estender, chanfro e arredondar/fillet permanecem acessíveis. Atuam sobre segmentos; operações de canto solicitam o número da segunda entidade |
| Organização | Ctrl+clique adiciona entidades/grupos à seleção; agrupar e desagrupar; exclusão respeita os grupos selecionados |
| Texto | Inserção por clique e conteúdo digitado; altura, conteúdo, cor e posição editáveis; persistência, undo/redo, SVG e DXF TEXT |
| Cotas | Cota alinhada por dois pontos; afastamento editável no campo Dimensão mm; valor calculado em metros; salva como entidade própria |
| Medição | Ferramenta de distância por dois pontos, sem criar geometria; Medir seleção soma os comprimentos dos membros selecionados |
| Propriedades | Camada, início/fim em mm, dimensão, cor RGB, espessura do traço e texto; botão Aplicar propriedades com validação e undo |
| Planta baixa | Paredes, portas e janelas anteriores; folha e arco de abertura nas portas; três linhas nas janelas; símbolos iniciais de escada, pilar, cama, sofá, mesa, vão, vaso sanitário e lavatório |
| Interface | Seis abas de comandos, ícones, paleta esquerda de uma coluna com grupos expansíveis e rolagem; propriedades ocultáveis à direita |

## Como usar

- Abra **Propriedades / camadas** na barra inferior, ou use **Ctrl+I**. Selecione uma entidade, edite os campos e clique em **Aplicar propriedades**. O painel não abre automaticamente.
- Use **Polilinha**, clique nos vértices e finalize com o botão direito. Cada trecho tem undo; os trechos ficam agrupados.
- Use **Arco**: primeiro clique no centro, segundo no início/raio, terceiro define a direção final. O percurso é horário na tela.
- **Texto** pede o conteúdo após um clique. No painel, Dimensão mm corresponde à altura do texto. A direção início/fim controla sua rotação.
- **Cota alinhada** usa dois pontos. Dimensão mm é o afastamento assinado da linha de cota; não é o comprimento medido. Alterar os pontos da própria cota recalcula o valor.
- **Stretch** recebe dois cantos de uma janela e solicita deslocamentos X/Y em mm. Somente os vértices dentro da janela se movem; Y positivo aponta para cima.
- **Girar**, **Escala** e **Espelhar** usam o início da entidade principal como base. Giro positivo é horário na tela.
- **Array** solicita espaçamentos e quantidades de linhas/colunas, incluindo a instância original. Cada instância copiada forma um grupo.
- Os símbolos de peças, elipse, polígono e hachura são inseridos por dois cantos delimitando sua área.
- A propriedade de cor usa hexadecimal RGB; `000000` representa o comportamento automático atual. Camadas: 0 Arquitetura, 1 Estrutura, 2 Instalações. Traço 0 mantém a espessura automática.
- A aplicação de propriedades edita a entidade principal. As transformações atuam sobre o grupo/seleção inteira.

## Persistência e exportação

O formato escrito agora é **EACAD4**, com texto, cor e espessura. O aplicativo continua lendo **EACAD1, EACAD2 e EACAD3**. Aplicativos antigos não lerão EACAD4. Carregamento inválido preserva o desenho atual.

SVG preserva texto, estilo e representação de cotas. DXF foi atualizado para estrutura **2007/AC1021**, com LINE e TEXT; cotas são exportadas como linhas e texto, sem associação nativa DIMENSION. A importação existente não passa automaticamente a importar todos esses elementos: sua cobertura permanece a do importador anterior. A interoperabilidade em uma instalação real do AutoCAD ainda requer homologação.

## Validação executada

- Compilação do aplicativo com Lazarus/Free Pascal 3.2.2, Win32/i386.
- **33 verificações** em `test_cad2d_commands`: grupos, move/copy/rotate/scale/mirror/array, Stretch, polilinha/arco/círculo, propriedades, texto, cotas, undo/redo, exportação, EACAD1–4, arquivo inválido e símbolos.
- **16 verificações** em `test_cad2d_ui`, sem o argumento opcional de captura: abertura, abas, painel ocultável, grupos expansíveis, rolagem, seleção, undo/redo e tamanho mínimo.
- **22 verificações** do importador anterior: zero falhas.
- Prévia do formulário real renderizada e inspecionada com uma planta demonstrativa, texto, cotas, portas, janelas e propriedades.
- `git diff --check` sem erros. Hints/notas do compilador permanecem; não são erros de compilação.

## Limitações e trabalho restante

- Geometria continua baseada em coordenadas inteiras do protótipo e escala mm/pixel. Curvas e elipses são aproximações por segmentos agrupados, não curvas analíticas editáveis por raio.
- Polígono é de seis lados; hachura cobre somente a área retangular indicada. Falta contorno arbitrário, biblioteca de padrões e preenchimento associativo.
- Cotas são alinhadas e independentes: não acompanham automaticamente uma parede editada. Faltam cotas angulares, de raio/diâmetro, estilos e vínculos associativos.
- Componentes são símbolos 2D simples. Faltam objetos paramétricos/BIM, paredes com junções inteligentes, vãos topológicos, ambientes/áreas automáticos e bibliotecas completas de móveis/esquadrias.
- Propriedades não incluem ainda estilo de linha, transparência, bloqueio de camada ou editor completo de layers. O texto é de uma linha, sem editor de parágrafos.
- Array é retangular e não associativo; não há array polar ou por caminho. Stretch usa janela retangular, sem polígono/lasso.
- Aparar/fillet e os outros comandos antigos foram preservados, mas seus diálogos geométricos não foram todos homologados interativamente nesta revisão.
- Falta homologar DXF no AutoCAD, impressão/PDF em escala e diferentes configurações de DPI.

## Arquivos e Git

Alterações em `cad2d_main.pas`, `cad2d_controls.pas`; novas unidades de inclusão `cad2d_editing.inc` e `cad2d_export.inc`; testes `test_cad2d_commands.lpr/.lpi`; documentação atualizada. Executável compilado em `bin/cad2d.exe`.

`git fetch origin` executado: `fila` e `origin/fila` continuam no mesmo commit, 0 à frente / 0 atrás. Alterações locais anteriores foram preservadas. Não houve reset, stash, merge, commit ou push. A publicação permanece pendente de consolidar as mudanças anteriores e as desta sessão que compartilham arquivos.
