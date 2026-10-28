# Especificação técnica — Módulo de Planta Baixa 2D

**Referência:** AutoCAD / AutoCAD Architecture 2026 • **Versão:** 1.0 — 28/10/2026

> Documento complementar ao Projeto A da [especificação da plataforma](Especificacao_Plataforma_Arquitetura.md). O formato `.msuite` previsto originalmente foi substituído pelo pacote nativo da plataforma, cuja extensão ainda será definida (ver seção 15.2 da especificação da plataforma).

Vamos usar o AutoCAD como referência funcional, especialmente suas ferramentas de desenho técnico e os objetos arquitetônicos do AutoCAD Architecture.

A proposta é desenvolver um editor capaz de criar uma planta baixa completa, com paredes, portas, janelas, ambientes, medidas, cotas e impressão em escala. O principal diferencial será trabalhar com objetos arquitetônicos inteligentes, e não apenas linhas independentes.

## 1. Resultado esperado

O usuário deverá conseguir criar uma planta baixa completa, como a de uma residência ou apartamento, com estes elementos:

- Paredes internas e externas com espessuras definidas.
- Portas, janelas, aberturas, colunas, escadas e rampas.
- Identificação dos cômodos, áreas e níveis.
- Cotas automáticas e manuais.
- Biblioteca de móveis e objetos.
- Escalas de apresentação e impressão.
- Exportação para DXF, PDF e imagens.

## 2. Ferramentas fundamentais

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

## 3. Objetos arquitetônicos inteligentes

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

## 4. Regras geométricas e medidas

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

## 5. Sistema de camadas (Layers)

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

## 6. Reconhecimento automático de ambientes

Esta é uma funcionalidade importante para diferenciar um editor arquitetônico de um CAD genérico.

Ilustração conceitual de ambientes delimitados por paredes e identificados automaticamente. Áreas meramente demonstrativas.

O sistema deverá identificar contornos fechados, calcular áreas e perímetros, atribuir nomes aos ambientes e atualizar os resultados sempre que a geometria mudar.

As portas não devem interromper a delimitação lógica dos ambientes. O editor deverá preservar a separação entre dois cômodos mesmo quando houver passagem entre eles.

## 7. Normas e apresentação técnica

O módulo deve oferecer recursos para produzir documentação conforme as normas pertinentes:

| Norma                                     | Aplicação                                               |
| ----------------------------------------- | ------------------------------------------------------- |
| ABNT NBR 6492:2021                        | Documentação e representação de projetos arquitetônicos |
| ABNT NBR 9050:2020, versão corrigida 2021 | Acessibilidade de edificações                           |
| ABNT NBR 16636                            | Etapas e desenvolvimento de projetos arquitetônicos     |

A NBR 6492 apresenta orientações de linhas, escalas, símbolos, cotas, identificações e quadros. A NBR 9050 estabelece parâmetros técnicos de acessibilidade, cuja aplicação deve considerar o tipo de edificação.

Também será necessário considerar o código de obras e as exigências municipais aplicáveis. O software deve permitir alertas de conformidade, sem substituir a avaliação de um profissional habilitado.

## 8. Estrutura técnica dos arquivos

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

## 9. Arquitetura do editor

Pensando na implementação em Lazarus/Free Pascal, eu separaria as responsabilidades desta forma:

- **Interface CAD:** menus, barras, área gráfica e painel de propriedades

- **Motor geométrico 2D:** coordenadas, snap, interseções, offsets e transformações

- **Motor arquitetônico:** paredes, aberturas, ambientes, relações e áreas

- **Documentação e persistência:** cotas, layers, pranchas, DXF, PDF e projeto nativo

A separação permitirá reaproveitar ferramentas geométricas já existentes no ecossistema CAD sem misturar objetos de arquitetura com operações de fabricação.

## 10. Ordem de implementação

### Etapa 1 — Editor CAD básico (versão mínima)

Canvas 2D, unidades reais, grid, snap, linhas, polilinhas, seleção, transformações, layers, salvar e abrir projetos.

### Etapa 2 — Planta arquitetônica

Paredes paramétricas, conexões automáticas, portas, janelas, ambientes, áreas e cotas associativas.

### Etapa 3 — Documentação profissional

Bibliotecas, quadros de áreas e esquadrias, pranchas, carimbo, escalas, PDF e DXF.

### Etapa 4 — Recursos avançados

Múltiplos pavimentos, cortes, elevações, visualização 3D, compatibilidade BIM e verificações normativas.

## 11. Critérios de aceitação

Para considerar o primeiro módulo funcional, ele deverá conseguir:

1. Desenhar uma sala de 4,00 × 3,00 m com paredes de 150 mm, a partir de medidas digitadas.
2. Inserir uma porta e uma janela, abrindo corretamente os respectivos vãos.
3. Alterar uma dimensão e atualizar paredes, objetos vinculados e cotas.
4. Identificar um ambiente fechado e calcular corretamente sua área interna.
5. Salvar, reabrir e editar o projeto sem perder medidas ou vínculos.
6. Exportar um DXF editável e um PDF com escala verificável.

Minha recomendação: começar com um motor CAD 2D preciso e uma ferramenta de paredes inteligentes. Esses dois elementos são a base de todo o restante. Não iniciaria pela modelagem 3D, pois ela acrescentaria complexidade antes da estabilização da geometria.

Essa especificação serve como documento inicial de desenvolvimento do CAD Arquitetônico 2D, tomando o AutoCAD como referência de funcionamento, sem depender de uma instalação do AutoCAD.
