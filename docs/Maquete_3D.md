# Maquete 3D (Gerador de Maquetes 3D)

| Campo | Valor |
|---|---|
| Tipo | Aplicativo independente; contém os módulos Editor de Objetos 3D e Gerador de Texturas |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Terceira etapa: reconstrói a edificação em 3D a partir das plantas |
| Recebe | Plantas do CAD 2D; DWG, DXF e IFC pelo Motor de Importação; objetos do Editor de Objetos 3D |
| Produz | Maquete com pavimentos, objetos, texturas e âncoras para o Criador de Cenas, o Elétrica 3D e o SimuTubulações; exibe as disciplinas de instalações publicadas |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Descrição

Aplicativo para importar uma planta ou um conjunto de plantas baixas, reconhecer e associar pavimentos, reconstruir o volume 3D de uma edificação, **criar, editar e posicionar objetos tridimensionais em um editor 3D integrado**, organizar bibliotecas de componentes e visualizar o resultado em 3D com materiais e iluminação básica de trabalho. A renderização ultrarrealista e os movimentos avançados ficam no aplicativo independente Criador de Cenas. Recebe também modelos BIM e malhas 3D importadas. O Editor de Objetos 3D importa STL/3MF e outros formatos de mercado independentemente do aplicativo de origem. O Gerador de Texturas (Skins), integrado ao próprio projeto 3D, cria, importa, aplica e reutiliza materiais de aparência PBR em objetos e superfícies arquitetônicas.

**Componentes técnicos:** gerador de malhas/volumes a partir das plantas, viewport de montagem, câmera de trabalho, materiais, iluminação de prévia e exportadores de modelo. Incluir **Editor de Objetos 3D**, importação genérica STL/3MF/GLB/OBJ, **Gerador e Editor de Texturas (Skins) próprio e offline**, biblioteca de objetos e materiais, UV/projeção de texturas, edição PBR/procedural, gizmos de transformação e instanciamento com âncoras por pavimento/superfície.

**Módulos internos:** [Editor de Objetos 3D](Editor_Objetos_3D.md) e [Gerador de Texturas](Gerador_Texturas.md), cada um com documento próprio.

## 2. Requisitos funcionais

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RF3D-001 | Essencial | Importar uma planta baixa isolada ou várias plantas em uma única operação. |
| RF3D-002 | Essencial | Importar desenho técnico DWG/DXF e modelos BIM IFC; aceitar formato interno do CAD 2D. |
| RF3D-003 | Essencial | Identificar ou solicitar ao usuário a associação dos arquivos a térreo, pavimentos, subsolo e cobertura. |
| RF3D-004 | Essencial | Alinhar pavimentos por origem, eixos, pontos de controle ou transformações assistidas. |
| RF3D-005 | Essencial | Definir cotas de nível, pé-direito, espessuras de lajes, alturas das paredes e níveis de cobertura. |
| RF3D-006 | Essencial | Converter paredes 2D em volumes 3D e executar junções, encontros e recortes. |
| RF3D-007 | Essencial | Gerar vãos, portas, janelas e respectivos posicionamentos a partir dos dados da planta. |
| RF3D-008 | Essencial | Gerar pisos, lajes, ambientes e estrutura simplificada conforme dados disponíveis. |
| RF3D-009 | Essencial | Reconhecer escadas e relacionar pavimentos, com confirmação de parâmetros ambíguos. |
| RF3D-010 | Essencial | Permitir orbit, pan, zoom, câmera em perspectiva/ortográfica e ocultação de pavimentos. |
| RF3D-011 | Essencial | Exibir prévia da maquete e registrar alertas sobre ausências ou ambiguidades da origem. |
| RF3D-012 | Essencial | Salvar e reabrir maquete, preservando a associação com cada arquivo importado. |
| RF3D-013 | Importante | Importar geometria 3D de referência em STL, 3MF, OBJ, glTF/GLB, DAE e FBX, com adaptações conforme o formato. |
| RF3D-014 | Importante | Importar IFC2x3, IFC4 e IFC4.3, inclusive hierarquia de pavimentos e objetos semânticos. |
| RF3D-015 | Importante | Aplicar skins, transparência, materiais e iluminação de **pré-visualização** para montagem da maquete. |
| RF3D-016 | Importante | Disponibilizar vistas internas/externas e exportar a cena geométrica completa, com objetos e skins, ao Criador de Cenas externo. |
| RF3D-017 | Importante | Comparar versões das plantas e atualizar somente elementos alterados, preservando ajustes manuais quando possível. |
| RF3D-018 | Importante | Exportar maquete em glTF/GLB, OBJ, imagens e, quando viável, IFC com dados arquitetônicos. |
| RF3D-019 | Importante | Permitir importação de SKP/RVT por adaptador licenciado, plugin ou conversão para IFC/DXF, com indicação de perdas. |
| RF3D-020 | Futuro | Reconstruir parcialmente plantas rasterizadas por vetorização e interpretação assistida, mediante revisão humana. |
| RF3D-021 | Futuro | Criar telhados complexos a partir de plantas de cobertura, cortes e fachadas. |
| RF3D-022 | Importante | Exibir disciplinas externas vinculadas (como Elétrica 3D) e verificar conflitos geométricos simples sem editar os circuitos desses aplicativos. |

## 3. Critérios de aceitação

1. Importar dois DXF separados (térreo e superior), alinhá-los e montar uma maquete com níveis parametrizados.
2. Alterar uma parede na planta 2D, reimportar e revisar diferenças antes de atualizar a maquete 3D.
3. Demonstrar que documentos com diferentes pavimentos e origens podem ser organizados sem perder coordenadas ou relações.
4. Regenerar a maquete após revisão de planta, preservando instâncias manuais e emitindo aviso para âncoras inválidas.
5. Instalar e executar Maquete 3D em máquina sem MultiCNC/MultiCAD, gerar skins localmente e importar STL externo.

## 4. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| M1 — Reconstrução básica | Ler o projeto nativo do CAD 2D; gerar volumes de paredes, vãos de portas e janelas, pisos e lajes de um pavimento; navegação orbital | RF3D-002 (nativo), RF3D-005 a RF3D-008, RF3D-010 | Sala de 4,00 × 3,00 m do CAD 2D vira volume com porta e janela nos vãos corretos |
| M2 — Vários pavimentos | Associação de plantas a pavimentos, alinhamento, níveis, escadas, ocultação de pavimentos, salvar e reabrir | RF3D-001, RF3D-003, RF3D-004, RF3D-009, RF3D-011, RF3D-012 | Critério 1 (dois DXF montados com níveis parametrizados) |
| M3 — Objetos e texturas | Integração dos módulos Editor de Objetos e Gerador de Texturas; instâncias ancoradas | RF3D-015 e módulos | Mesa da biblioteca inserida em dois pavimentos com texturas diferentes |
| M4 — Revisões | Comparar versões das plantas e atualizar só o que mudou, preservando ajustes e instâncias | RF3D-017 | Critérios 2 e 4 |
| M5 — BIM e exportação | IFC com hierarquia de pavimentos; exportação GLB, OBJ e IFC | RF3D-014, RF3D-018 | Critério 4 do Motor de Importação (IFC com dois pavimentos) |
| M6 — Avançado | SKP e RVT por conversão, plantas digitalizadas, telhados complexos, conflitos entre disciplinas | RF3D-019 a RF3D-022 | Definido ao iniciar a etapa |

**Dependências:** M1 exige o modelo arquitetônico do [Núcleo Comum](Nucleo_Comum.md) e o CAD 2D na etapa A2; M3 exige as etapas O1–O3 e T1–T2 dos módulos.
