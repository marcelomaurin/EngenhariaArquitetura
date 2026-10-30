# CAD Arquitetônico 2D

Editor profissional de plantas baixas, tendo o AutoCAD e o AutoCAD Architecture como referências funcionais. Trabalha com **objetos arquitetônicos inteligentes** (paredes, portas, janelas, ambientes), e não apenas com linhas independentes. É a **prioridade inicial** da plataforma.

> **Estado:** em especificação. Especificação completa e etapas de desenvolvimento em [docs/CAD_Arquitetonico_2D.md](../docs/CAD_Arquitetonico_2D.md); integrações em [docs/Integracoes.md](../docs/Integracoes.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Tarefas do Planejador; arquivos de mercado (DWG, DXF, IFC, PDF, SVG, imagens) | Plantas baixas com objetos, pavimentos, cotas e camadas | Maquete 3D; pranchas PDF, DXF e SVG |

**Fora do escopo:** renderização realista e modelagem 3D.

## Funcionalidades

### Desenho e precisão
- Linha, polilinha, arco, círculo, retângulo, polígono e hachura.
- Mover, copiar, rotacionar, espelhar, escalar, aparar, estender e deslocamento paralelo.
- Coordenadas absolutas e relativas, entrada numérica, grade, encaixe (extremidade, meio, interseção, perpendicular), modo ortogonal e rastreamento angular.
- Desenho sempre em escala 1:1 no espaço do modelo; escala aplicada na folha.

### Objetos arquitetônicos
| Objeto | Parâmetros |
|---|---|
| Parede | Início, fim, espessura, altura, material, alinhamento e conexões |
| Porta | Largura, altura, posição, sentido e ângulo de abertura |
| Janela | Largura, altura, peitoril, posição e tipo |
| Ambiente | Nome, perímetro, área útil e nível |
| Coluna, escada, rampa | Dimensões, degraus, inclinação e orientação |
| Mobiliário | Tipo, dimensões, posição e rotação |

- Ao inserir porta ou janela, o vão é aberto automaticamente na parede; ao mover a parede, os elementos acompanham.
- Reconhecimento automático de ambientes fechados, com cálculo de área e perímetro; portas não quebram a delimitação dos cômodos.

### Documentação
- Cotas lineares, alinhadas, angulares e de raio, vinculadas à geometria.
- Blocos e símbolos reutilizáveis; biblioteca de móveis.
- Pranchas, carimbo e escalas 1:20, 1:50, 1:75, 1:100 e 1:200.
- Alertas de conformidade com ABNT NBR 6492, NBR 9050 e NBR 16636, sem substituir o profissional habilitado.

### Camadas padrão
`ARQ_PAREDES`, `ARQ_PORTAS`, `ARQ_JANELAS`, `ARQ_ESTRUTURA`, `ARQ_COTAS`, `ARQ_TEXTOS`, `ARQ_MOBILIARIO`, `ARQ_PISOS`, `ARQ_PROJECOES` e `ARQ_AREAS`, cada uma com cor, espessura, tipo de linha, visibilidade, bloqueio e impressão.

## Configuração padrão

| Item | Valor |
|---|---|
| Unidade interna | Milímetros, dupla precisão |
| Unidade apresentada | Metros (0,00 m) |
| Espessura inicial de parede | 150 mm |
| Grade inicial | 100 mm |

## Formatos

| Importação | Exportação |
|---|---|
| DWG e DXF (essencial), PDF vetorial, SVG, PNG/JPG/TIFF como referência, IFC (vistas 2D), DGN | Projeto nativo (JSON), DXF, PDF, SVG, PNG |

DXF vem antes do DWG; o DWG depende de biblioteca ou conversor a homologar.

## Requisitos

| Faixa | Assunto |
|---|---|
| RF2D-001 a RF2D-006 | Projeto, desenho, edição, precisão e camadas |
| RF2D-007 a RF2D-010 | Paredes, aberturas, ambientes e cotas |
| RF2D-011 a RF2D-013 | Importação e pré-visualização |
| RF2D-014 a RF2D-016 | Blocos, pranchas, desfazer e preservação do original |
| RF2D-017 a RF2D-020 | DGN, IFC, revisões, referências externas e validações |
| RFI-001 a RFI-021 | Motor de importação comum |

## Arquitetura interna

- **Interface CAD:** menus, barras, área gráfica e painel de propriedades.
- **Motor geométrico 2D:** coordenadas, encaixe, interseções, deslocamentos e transformações.
- **Motor arquitetônico:** paredes, aberturas, ambientes, relações e áreas.
- **Documentação e persistência:** cotas, camadas, pranchas, DXF, PDF e projeto nativo.

## Etapas

1. **Editor básico:** área de desenho, unidades reais, grade, encaixe, linhas, seleção, transformações, camadas, salvar e abrir.
2. **Planta arquitetônica:** paredes paramétricas, portas, janelas, ambientes, áreas e cotas associativas.
3. **Documentação:** bibliotecas, quadros de áreas e esquadrias, pranchas, carimbo, PDF e DXF.
4. **Avançado:** múltiplos pavimentos, cortes, elevações e verificações normativas.

## Critérios de aceite da primeira versão

1. Desenhar uma sala de 4,00 × 3,00 m com paredes de 150 mm a partir de medidas digitadas.
2. Inserir porta e janela abrindo corretamente os vãos.
3. Alterar uma dimensão e atualizar paredes, objetos vinculados e cotas.
4. Identificar o ambiente fechado e calcular a área interna.
5. Salvar, reabrir e editar sem perder medidas ou vínculos.
6. Exportar DXF editável e PDF com escala verificável.


## Protótipo executável inicial (2026-10-30)

A aplicação independente `cad2d/src/app/cad2d.lpi` foi iniciada em Lazarus/LCL. Inclui grade visual, captura de dois pontos com snap à grade, linhas, desfazer a última linha e exportação **DXF R12** de entidades LINE. A geometria está atualmente em coordenadas de grade/pixels, **sem escala física calibrada**, e o DXF deve ser tratado como experimental.

**Ainda não implementados:** persistência/editoração de arquivos nativos, importação DXF/DWG, camadas, blocos, objetos arquitetônicos (paredes, portas, janelas), cotas, ortogonal/polar, coordenadas em metros/milímetros e integração BIM com Maquete 3D. Não usar para projeto executivo.

A compilação Windows/Linux, o teste de interface e a validação do DXF exportado seguem pendentes até aprovação das respectivas verificações.


## Evolução do protótipo — camadas e unidades

- Ferramentas de linha e retângulo por dois pontos, com snap à grade.
- Três camadas iniciais: Arquitetura, Estrutura e Instalações, com cores diferentes.
- Escala inicial fixa de 50 mm/pixel (grade 20 px = 1.000 mm). Ainda sem calibração, zoom ou pan.
- Exportação DXF LINE com coordenadas em milímetros e camada de cada segmento. A importação e o projeto nativo permanecem pendentes.
- Esta é uma evolução de protótipo, **não** um editor CAD pronto para projeto executivo. Necessita compilação e homologação visual.


## Objetos iniciais e arquivo nativo (.eacad)

O CAD 2D agora tem ferramentas iniciais para representar **parede**, **porta** e **janela** como segmentos tipados, além de **Salvar projeto** e **Abrir projeto**. O arquivo `.eacad` é textual e versionado com cabeçalho `EACAD1`, escala e segmentos com camada e tipo, para continuar a edição posteriormente.

**Limitação importante:** paredes ainda são segmentos de espessura visual; portas e janelas não abrem vãos na parede nem têm atributos BIM, ferragens, folhas ou dimensões editáveis. O desenho não possui cotas, zoom, deslocamento de tela, seleção e edição geométrica. É um protótipo de armazenamento e visualização; não atende à elaboração de plantas executivas. Exportação DXF ainda usa entidades LINE.


## Etapa dimensional EACAD2 (2026-10-30)

Objetos do tipo parede têm espessura inicial de 150 mm; porta e janela têm largura nominal inicial de 900 e 1200 mm. O comando **Editar último** permite alterar a dimensão do último objeto arquitetônico. O formato **EACAD2** persiste esta propriedade e lê arquivos antigos **EACAD1**, atribuindo valores iniciais. A geometria permanece baseada em segmentos: ainda **não existem vãos reais** cortados nas paredes, associação automática de esquadrias com paredes, seleção de qualquer objeto ou dimensões vinculadas ao DXF. Isso deve ser implementado e testado em uma etapa posterior.


## Seleção e edição inicial

Ferramenta **Selecionar** localiza o segmento mais próximo do clique (até 12 pixels), destaca-o e permite **Excluir seleção**. **Editar último** passa a usar o segmento selecionado quando existente e, na ausência de seleção, o último segmento. A edição ainda altera somente a propriedade dimensional, não os pontos geométricos. Faltam movimentação, cópia, rotação, grips, snaps geométricos reais, associação de aberturas com paredes e operações CAD mais completas.

**Estado:** protótipo, não homologado como CAD de produção. O projeto não está concluído. A compilação de cada commit deve ser conferida no GitHub Actions.


## Transformações geométricas iniciais

A seleção agora oferece **Mover seleção** e **Copiar seleção** com deslocamentos X e Y informados em milímetros. O eixo Y positivo representa a direção superior da planta. Como a geometria ainda utiliza pontos inteiros da tela, deslocamentos menores que a resolução de 50 mm/pixel são arredondados; zoom e geometria vetorial em dupla precisão são pendências importantes. Esta etapa não deve ser confundida com operações CAD de precisão profissional.


## Zoom do viewport

Controles Zoom + e Zoom - (50% a 400%) foram adicionados ao protótipo. A transformação de visualização aplica-se à grade, aos segmentos, ao marcador de início e à seleção por clique, preservando as coordenadas do arquivo. **Pan, ajuste à tela, coordenadas vetoriais de precisão e ensaios de interface permanecem pendentes.**


## Círculos e ortogonal (protótipo)

A ferramenta **Círculo** recebe centro e um ponto do raio e cria aproximação poligonal de 48 segmentos. Não representa entidade CIRCLE nativa em DXF e o comando Desfazer remove somente o último segmento, não o círculo inteiro. Segurar **Shift** ao definir o segundo ponto restringe linhas e objetos lineares aos eixos horizontal ou vertical. Estas funções exigem validação visual e evolução para geometria vetorial paramétrica.


## Histórico de operações e EACAD3

Desfazer e Refazer agrupam linhas geradas na mesma operação, como retângulos e círculos. O formato textual **EACAD3** persiste o identificador do grupo, permitindo reabrir o projeto sem perder o agrupamento dos desenhos. Há leitura retrocompatível de EACAD1 e EACAD2, cujos segmentos recebem grupos individuais. O histórico de desfazer/refazer continua apenas em memória; exclusões, movimentações e mudanças de propriedades ainda não participam do histórico. Não confundir com undo/redo completo de um CAD profissional.


## Pan da vista

Comandos Pan esquerda/direita/cima/baixo deslocam a visualização em passos de 40 pixels. Grade, objetos, ponto inicial e seleção usam a mesma transformação de coordenadas, sem alterar a geometria persistida. A grade atual mantém origem (0,0) e ainda precisa de repetição para offsets negativos, arraste pelo mouse e ajuste automático à tela. Histórico completo para operações de mover, copiar, excluir e editar continua pendente.


## Histórico de edição expandido

Os botões **Desfazer** e **Refazer** utilizam snapshots do desenho, com limite de 60 estados desfazíveis. O histórico abrange criação de segmentos e formas, mover, copiar, excluir, alterar dimensão e limpar o desenho. O histórico é reiniciado ao abrir projeto, e não é gravado no EACAD3. O histórico anterior por grupos permanece no código como implementação legada. Ainda exige testes funcionais de múltiplas sequências de operações e correção de casos de falha de arquivo, não sendo um sistema de transações CAD de produção.


## Entrega de exportação e medição (2026-10-30)

- **Exportar SVG:** gera um desenho vetorial SVG com os segmentos existentes e o enquadramento geométrico da planta, usando milímetros como unidades do sistema de desenho; trata-se de exportação de linhas, não de elementos BIM.
- **Medir seleção:** calcula o comprimento euclidiano da linha selecionada e o exibe em metros e milímetros. A medida ainda segue a resolução geométrica do protótipo (pontos inteiros).
- **Retângulo:** os quatro lados agora são armazenados como linhas comuns (Kind=0), evitando confundi-los com objetos arquitetônicos.

Esta entrega **não** implementa suporte DWG, PDF, IFC, cotas associativas, edição paramétrica de paredes, portas/janelas com vãos reais, nem validação profissional dos arquivos. Esses itens permanecem pendentes.
