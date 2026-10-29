# CAD Arquitetônico 2D

| Campo | Valor |
|---|---|
| Tipo | Aplicativo independente |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Segunda etapa e prioridade inicial: desenho técnico e plantas baixas com objetos inteligentes |
| Recebe | Tarefas do Planejador; arquivos de mercado pelo Motor de Importação |
| Produz | Plantas baixas (projeto nativo) para a Maquete 3D; pranchas PDF, DXF e SVG |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Descrição

Editor de desenho técnico 2D para produzir plantas baixas, com ferramentas de precisão, objetos arquitetônicos inteligentes (paredes, portas, janelas), cotas, layers, documentação e importação/exportação dos formatos usuais de mercado. **Não é responsável pela renderização fotorrealista.**

**Componentes técnicos:** interface desktop, viewport, mouse/teclado, comandos, gerenciamento de objetos, undo/redo, layers, cotas, biblioteca de símbolos e impressão.

## 2. Requisitos funcionais

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RF2D-001 | Essencial | Criar, abrir, salvar, duplicar e versionar projetos 2D. |
| RF2D-002 | Essencial | Desenhar linha, polilinha, arco, círculo, retângulo, polígono e hachura. |
| RF2D-003 | Essencial | Selecionar, mover, copiar, rotacionar, espelhar, escalar, aparar, estender e aplicar offset. |
| RF2D-004 | Essencial | Trabalhar com coordenadas absolutas/relativas, entrada numérica, unidades configuráveis e desenho 1:1. |
| RF2D-005 | Essencial | Oferecer grid, snap em extremidade/meio/interseção/perpendicular, modo ortogonal e rastreamento angular. |
| RF2D-006 | Essencial | Administrar layers com nome, visibilidade, bloqueio, cor, espessura e tipo de linha. |
| RF2D-007 | Essencial | Criar paredes paramétricas com largura, altura, material, eixo, alinhamento e conexões. |
| RF2D-008 | Essencial | Inserir portas e janelas com posicionamento, dimensões e abertura automática do vão na parede. |
| RF2D-009 | Essencial | Reconhecer ambientes fechados e calcular perímetro, área e identificador. |
| RF2D-010 | Essencial | Inserir cotas lineares, alinhadas, angulares e de raio/diâmetro, vinculáveis à geometria. |
| RF2D-011 | Essencial | Importar DWG e DXF por mecanismos documentados, com relatório de entidades não suportadas. |
| RF2D-012 | Essencial | Importar PDF vetorial, SVG e imagens de referência (PNG/JPEG/TIFF), preservando ou calibrando escala. |
| RF2D-013 | Essencial | Pré-visualizar importação, selecionar folhas/layers/blocos e configurar escala, unidades e origem. |
| RF2D-014 | Essencial | Criar, editar e reutilizar blocos/símbolos, inclusive móveis e símbolos arquitetônicos. |
| RF2D-015 | Essencial | Gerar pranchas, configurar escalas, carimbo e exportar PDF, DXF e SVG. |
| RF2D-016 | Essencial | Desfazer/refazer operações e manter arquivo original de importação intacto. |
| RF2D-017 | Importante | Importar DGN e extrair vistas 2D de modelos IFC, preservando informações possíveis. |
| RF2D-018 | Importante | Atualizar desenhos vinculados e sinalizar diferenças entre revisões. |
| RF2D-019 | Futuro | Suportar referências externas complexas (XREF), objetos personalizados e recursos avançados de DWG. |
| RF2D-020 | Futuro | Validar parâmetros de representação e acessibilidade mediante regras configuráveis. |

A importação de arquivos (RF2D-011 a RF2D-013, RF2D-017) usa o [Motor de Importação](Motor_Importacao.md).

## 3. Detalhamento funcional (referência AutoCAD / AutoCAD Architecture)

Vamos usar o AutoCAD como referência funcional, especialmente suas ferramentas de desenho técnico e os objetos arquitetônicos do AutoCAD Architecture.

A proposta é desenvolver um editor capaz de criar uma planta baixa completa, com paredes, portas, janelas, ambientes, medidas, cotas e impressão em escala. O principal diferencial será trabalhar com objetos arquitetônicos inteligentes, e não apenas linhas independentes.

### Resultado esperado

O usuário deverá conseguir criar uma planta baixa completa, como a de uma residência ou apartamento, com estes elementos:

- Paredes internas e externas com espessuras definidas.
- Portas, janelas, aberturas, colunas, escadas e rampas.
- Identificação dos cômodos, áreas e níveis.
- Cotas automáticas e manuais.
- Biblioteca de móveis e objetos.
- Escalas de apresentação e impressão.
- Exportação para DXF, PDF e imagens.

### Ferramentas fundamentais

| Grupo        | Ferramentas necessárias                                                 |
| ------------ | ----------------------------------------------------------------------- |
| Desenho      | Linha, polilinha, retângulo, círculo, arco e polígono                   |
| Modificação  | Mover, copiar, rotacionar, espelhar, escalar, aparar, estender e offset |
| Precisão     | Grid, snap, ortogonal, coordenadas, ângulos e distâncias                |
| Seleção      | Simples, múltipla, por janela e por tipo                                |
| Organização  | Layers, grupos, blocos e propriedades                                   |
| Visualização | Zoom, pan, enquadramento e régua                                        |
| Edição       | Desfazer, refazer, excluir, duplicar e alterar propriedades             |

O AutoCAD utiliza coordenadas, rastreamento polar, encaixe em objetos e entrada precisa de distâncias para garantir a exatidão dos desenhos. Esses recursos devem ser tratados como fundamentais, não opcionais.

### Objetos arquitetônicos inteligentes

Cada objeto deverá possuir propriedades geométricas e arquitetônicas próprias.

| Objeto     | Parâmetros                                             |
| ---------- | ------------------------------------------------------ |
| Parede     | Início, fim, espessura, altura, material e alinhamento |
| Porta      | Largura, altura, posição, sentido e ângulo de abertura |
| Janela     | Largura, altura, peitoril, posição e tipo              |
| Ambiente   | Nome, perímetro, área útil e nível                     |
| Coluna     | Forma, largura, profundidade e orientação              |
| Escada     | Largura, degraus, espelho, piso e sentido              |
| Rampa      | Comprimento, largura, desnível e inclinação            |
| Mobiliário | Tipo, dimensões, posição e rotação                     |

Comportamento obrigatório: ao inserir uma porta ou janela em uma parede, o sistema deve criar automaticamente a abertura correspondente. Ao mover a parede, os elementos associados devem acompanhar sua transformação. Esse comportamento existe no AutoCAD Architecture.

### Regras geométricas e medidas

Sugiro utilizar estas configurações iniciais, todas editáveis pelo usuário:

| Configuração                | Padrão proposto                 |
| --------------------------- | ------------------------------- |
| Unidade geométrica interna  | Milímetros                      |
| Precisão interna            | `Double` (64 bits)              |
| Unidade apresentada         | Metros                          |
| Precisão visual             | 0,00 m                          |
| Ângulo                      | Graus                           |
| Espessura inicial de parede | 150 mm                          |
| Grid inicial                | 100 mm                          |
| Escalas de impressão        | 1:20, 1:50, 1:75, 1:100 e 1:200 |
| Coordenadas                 | Cartesianas X/Y                 |
| Origem                      | X=0, Y=0                        |

Esses valores são padrões de funcionamento, não exigências construtivas universais.

O desenho deverá manter sempre as medidas reais em escala 1:1 no espaço de modelagem. A escala será aplicada na apresentação em folha ou exportação, seguindo a organização entre Model Space e Paper Space utilizada pelo AutoCAD.

### Sistema de camadas (Layers)

Cada tipo de elemento deverá estar associado a uma camada independente.

| Layer sugerido   | Conteúdo                                |
| ---------------- | --------------------------------------- |
| `ARQ_PAREDES`    | Paredes e divisórias                    |
| `ARQ_PORTAS`     | Portas                                  |
| `ARQ_JANELAS`    | Janelas                                 |
| `ARQ_ESTRUTURA`  | Pilares e elementos estruturais         |
| `ARQ_COTAS`      | Cotas dimensionais                      |
| `ARQ_TEXTOS`     | Textos e identificação                  |
| `ARQ_MOBILIARIO` | Móveis e equipamentos                   |
| `ARQ_PISOS`      | Pisos e revestimentos                   |
| `ARQ_PROJECOES`  | Elementos projetados                    |
| `ARQ_AREAS`      | Polígonos e identificação dos ambientes |

Cada layer precisa controlar cor, espessura de linha, estilo de traço, visibilidade, bloqueio e impressão.

### Reconhecimento automático de ambientes

Esta é uma funcionalidade importante para diferenciar um editor arquitetônico de um CAD genérico.

Ilustração conceitual de ambientes delimitados por paredes e identificados automaticamente. Áreas meramente demonstrativas.

O sistema deverá identificar contornos fechados, calcular áreas e perímetros, atribuir nomes aos ambientes e atualizar os resultados sempre que a geometria mudar.

As portas não devem interromper a delimitação lógica dos ambientes. O editor deverá preservar a separação entre dois cômodos mesmo quando houver passagem entre eles.

### Normas e apresentação técnica

O módulo deve oferecer recursos para produzir documentação conforme as normas pertinentes:

| Norma                                     | Aplicação                                               |
| ----------------------------------------- | ------------------------------------------------------- |
| ABNT NBR 6492:2021                        | Documentação e representação de projetos arquitetônicos |
| ABNT NBR 9050:2020, versão corrigida 2021 | Acessibilidade de edificações                           |
| ABNT NBR 16636                            | Etapas e desenvolvimento de projetos arquitetônicos     |

A NBR 6492 apresenta orientações de linhas, escalas, símbolos, cotas, identificações e quadros. A NBR 9050 estabelece parâmetros técnicos de acessibilidade, cuja aplicação deve considerar o tipo de edificação.

Também será necessário considerar o código de obras e as exigências municipais aplicáveis. O software deve permitir alertas de conformidade, sem substituir a avaliação de um profissional habilitado.

### Estrutura técnica dos arquivos

Minha proposta é adotar um formato nativo próprio, com objetos paramétricos, e disponibilizar formatos de intercâmbio.

| Formato   | Finalidade                                             |
| --------- | ------------------------------------------------------ |
| nativo (extensão a definir) | Pacote nativo da plataforma |
| `.json`   | Estrutura editável e armazenamento dos objetos         |
| `.dxf`    | Troca de desenhos CAD                                  |
| `.dwg`    | Compatibilidade futura, mediante biblioteca apropriada |
| `.pdf`    | Pranchas e impressão                                   |
| `.svg`    | Desenho vetorial                                       |
| `.png`    | Pré-visualização                                       |

Para DWG, existe o SDK da Open Design Alliance, cuja utilização comercial depende de licenciamento. Sugiro começar por DXF, que é mais simples de implementar e testar.

Exemplo simplificado da representação de uma parede:

```

{
  "id": "P001",
  "tipo": "parede",
  "layer": "ARQ_PAREDES",
  "inicio": [0, 0],
  "fim": [5000, 0],
  "espessura_mm": 150,
  "altura_mm": 2800,
  "material": "alvenaria",
  "aberturas": ["PORTA001"]
}

```

### Arquitetura do editor

Pensando na implementação em Lazarus/Free Pascal, eu separaria as responsabilidades desta forma:

- **Interface CAD:** menus, barras, área gráfica e painel de propriedades

- **Motor geométrico 2D:** coordenadas, snap, interseções, offsets e transformações

- **Motor arquitetônico:** paredes, aberturas, ambientes, relações e áreas

- **Documentação e persistência:** cotas, layers, pranchas, DXF, PDF e projeto nativo

A separação permitirá reaproveitar ferramentas geométricas já existentes no ecossistema CAD sem misturar objetos de arquitetura com operações de fabricação.

### Ordem de implementação

#### Etapa 1 — Editor CAD básico (versão mínima)

Canvas 2D, unidades reais, grid, snap, linhas, polilinhas, seleção, transformações, layers, salvar e abrir projetos.

#### Etapa 2 — Planta arquitetônica

Paredes paramétricas, conexões automáticas, portas, janelas, ambientes, áreas e cotas associativas.

#### Etapa 3 — Documentação profissional

Bibliotecas, quadros de áreas e esquadrias, pranchas, carimbo, escalas, PDF e DXF.

#### Etapa 4 — Recursos avançados

Múltiplos pavimentos, cortes, elevações, visualização 3D, compatibilidade BIM e verificações normativas.

### Critérios de aceitação

Para considerar o primeiro módulo funcional, ele deverá conseguir:

1. Desenhar uma sala de 4,00 × 3,00 m com paredes de 150 mm, a partir de medidas digitadas.
2. Inserir uma porta e uma janela, abrindo corretamente os respectivos vãos.
3. Alterar uma dimensão e atualizar paredes, objetos vinculados e cotas.
4. Identificar um ambiente fechado e calcular corretamente sua área interna.
5. Salvar, reabrir e editar o projeto sem perder medidas ou vínculos.
6. Exportar um DXF editável e um PDF com escala verificável.

Minha recomendação: começar com um motor CAD 2D preciso e uma ferramenta de paredes inteligentes. Esses dois elementos são a base de todo o restante. Não iniciaria pela modelagem 3D, pois ela acrescentaria complexidade antes da estabilização da geometria.

Essa especificação serve como documento inicial de desenvolvimento do CAD Arquitetônico 2D, tomando o AutoCAD como referência de funcionamento, sem depender de uma instalação do AutoCAD.

## 4. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| A1 — Editor básico | Área de desenho, unidades em mm, grade, encaixe, ortogonal, linha, polilinha, arco, círculo, seleção, transformações, camadas, desfazer, salvar e abrir | RF2D-001 a RF2D-006, RF2D-016 | Desenhar e cotar manualmente um retângulo de 4.000 × 3.000 mm por coordenadas digitadas, salvar e reabrir sem perda |
| A2 — Planta arquitetônica | Paredes paramétricas, conexões, portas, janelas, ambientes, áreas e cotas associativas | RF2D-007 a RF2D-010 | Critérios 1 a 5 da primeira versão (item 3 deste documento) |
| A3 — Documentação | Blocos, biblioteca de móveis, pranchas, carimbo, escalas, exportação PDF, DXF e SVG | RF2D-014, RF2D-015 | Critério 6: DXF editável e PDF com escala verificável |
| A4 — Importação de mercado | DXF, SVG, PDF vetorial, imagens de referência; depois DWG | RF2D-011 a RF2D-013 | Critérios 1 a 3 do Motor de Importação |
| A5 — Avançado | Múltiplos pavimentos, revisões, DGN, vistas de IFC, referências externas e validações de acessibilidade | RF2D-017 a RF2D-020 | Comparar duas revisões de planta e sinalizar diferenças |

**Dependências:** A1 exige a geometria 2D e a persistência do [Núcleo Comum](Nucleo_Comum.md); A4 exige o Motor de Importação; o DWG exige a decisão sobre a biblioteca (ver [Decisões](Decisoes.md)).
