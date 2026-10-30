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
