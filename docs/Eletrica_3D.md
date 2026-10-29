# Elétrica 3D

| Campo | Valor |
|---|---|
| Tipo | Aplicativo independente (não é plugin da Maquete 3D) |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Quinta etapa: projeto das instalações elétricas usando a maquete como referência |
| Recebe | Maquete 3D em somente leitura |
| Produz | Projeto elétrico, camada elétrica vinculada, solicitações de coordenação, diagramas, quantitativos e pacote para o SimuEletrica |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Descrição

Recebe a **maquete arquitetônica como referência**, sem duplicar ou substituir seu editor, e cria a disciplina elétrica tridimensional: eletrodutos, conduítes, eletrocalhas, cabos, caixas, tomadas, interruptores, pontos de luz, quadros e circuitos. Salva seu projeto elétrico próprio e entrega à Maquete 3D uma camada vinculada de instalações para coordenação e visualização. O Criador de Cenas pode consumir a posição de luminárias e comandos para simular a iluminação, sem calcular ou validar o projeto elétrico.

O **Elétrica 3D** será um **programa próprio**, com instalador, executável, menus, arquivos de projeto, biblioteca e ciclo de versões independentes. **Não é um plugin da Maquete 3D.** Ele se conecta à Maquete 3D por um contrato de troca de dados: importa a edificação (preferencialmente em formato estruturado preservando IDs, geometria e pavimentos), oferece ferramentas de instalação elétrica e devolve uma **disciplina elétrica vinculada**, capaz de ser exibida como sobreposição na maquete.

Ele deve ser útil para projetar e revisar a distribuição espacial de infraestrutura elétrica. Os cálculos e avisos assistidos não substituem projeto, responsabilidade técnica ou inspeção por profissional habilitado conforme normas e regras vigentes.

## 2. Requisitos funcionais

| ID | Prioridade | Descrição |
|---|---|---|
| RFE-001 | Essencial | Criar, abrir, salvar e versionar arquivo próprio de projeto elétrico. |
| RFE-002 | Essencial | Importar a maquete arquitetônica por arquivo/intercâmbio, respeitando coordenadas, unidades, níveis e IDs de objetos. |
| RFE-003 | Essencial | Trabalhar com a arquitetura em referência **somente leitura**, sem sobrescrever a maquete-base. |
| RFE-004 | Essencial | Exibir, ocultar e isolar pavimentos, paredes, lajes, forros e elementos estruturais. |
| RFE-005 | Essencial | Inserir tomadas com posição, altura de instalação, orientação, classificação e propriedades. |
| RFE-006 | Essencial | Inserir interruptores e vincular logicamente os pontos comandados. |
| RFE-007 | Essencial | Inserir luminárias, pontos de luz e suas cargas declaradas. |
| RFE-008 | Essencial | Inserir quadros elétricos, caixas de passagem e pontos de conexão. |
| RFE-009 | Essencial | Desenhar rotas de eletrodutos/conduítes entre pontos usando segmentos e curvas 3D. |
| RFE-010 | Essencial | Definir diâmetro, material, ocupação, suporte e instalação aparente/embutida dos conduítes. |
| RFE-011 | Essencial | Inserir eletrocalhas, leitos e perfilados quando necessários. |
| RFE-012 | Essencial | Definir condutores/cabos com identificação, seção nominal, material, isolação, função e circuito. |
| RFE-013 | Essencial | Agrupar pontos e condutores em circuitos e identificar o quadro de origem. |
| RFE-014 | Essencial | Calcular comprimentos geométricos de rotas e permitir margens técnicas parametrizadas. |
| RFE-015 | Essencial | Associar elementos elétricos a superfícies/ambientes/pavimentos por âncoras persistentes. |
| RFE-016 | Essencial | Exportar camada elétrica 3D com metadados, IDs e vínculo à maquete de referência. |
| RFE-017 | Essencial | Reimportar uma revisão arquitetônica, comparar mudanças e sinalizar itens afetados sem apagar automaticamente instalações. |
| RFE-018 | Essencial | Exibir erros de conexão, itens órfãos e roteamentos interrompidos. |
| RFE-019 | Importante | Identificar interferências entre eletrodutos, lajes, vigas, portas, hidráulica e outros elementos disponíveis. |
| RFE-020 | Importante | Propor percursos assistidos respeitando zonas proibidas e obstáculos; exigir confirmação. |
| RFE-021 | Importante | Apoiar estimativas de cargas, divisão de circuitos, ocupação de eletrodutos e quadros com parâmetros configuráveis. |
| RFE-022 | Importante | Gerar diagramas unifilares e identificação de pontos/circuitos. |
| RFE-023 | Importante | Gerar quantitativos de tomadas, interruptores, pontos de luz, caixas, eletrodutos, cabos e acessórios. |
| RFE-024 | Importante | Exportar listas e relatórios em CSV, PDF e formatos estruturados para orçamento e revisão. |
| RFE-025 | Importante | Oferecer visualizações por circuito, tensão, categoria, pavimento e estado de validação. |
| RFE-026 | Importante | Permitir biblioteca de componentes configuráveis com dimensões, símbolos e dados de fabricantes, sem exigência de marcas específicas. |
| RFE-027 | Importante | Disponibilizar verificações normativas configuráveis e registrar sua versão, sem declaração automática de conformidade total. |
| RFE-028 | Importante | Suportar comparação visual e por IDs entre revisão elétrica anterior e posterior. |
| RFE-029 | Futuro | Trocar dados BIM/MEP em IFC, quando a compatibilidade semântica for homologada. |
| RFE-030 | Futuro | Exportar relações entre interruptores e luminárias para animação de cenas, sem exportar detalhes elétricos sensíveis desnecessários. |

## 3. Interface mínima

- **Menus próprios:** Arquivo, Editar, Exibir, Inserir, Circuitos, Roteamento, Verificação, Relatórios, Ferramentas e Ajuda.
- **Esquerda:** árvore de pavimentos, quadros, circuitos, grupos e disciplinas vinculadas.
- **Centro:** maquete arquitetônica com navegação 3D, modo corte, vista superior/ortográfica e seleção de rotas e equipamentos.
- **Direita:** propriedades do elemento elétrico selecionado.
- **Rodapé:** status de unidades, comprimento da rota, circuito, advertências e revisão-base.
- **Fluxo:** Abrir maquete → Definir quadros → Inserir pontos → Criar conduítes → Roteamento de cabos → Revisar interferências → Quantificar → Publicar disciplina elétrica.

## 4. Separação de dados e responsabilidade

- **Maquete 3D:** arquitetura e objetos de decoração (fonte da geometria arquitetônica).
- **Elétrica 3D:** objetos elétricos, circuitos, conexões, rotas, validações e documentação (fonte de verdade elétrica).
- **Criador de Cenas:** estados e representações visuais de luminárias, quando disponibilizados pela camada elétrica (sem cálculos normativos).
- **SimuTubulações:** fonte de verdade das redes de fluidos; as duas disciplinas trocam geometria apenas para detectar interferências (integração I-20), sem que uma edite a outra.
- Uma modificação no elétrico **não altera paredes, lajes, portas e janelas** na Maquete 3D. Alterações que exijam rasgos, furos, shafts ou aberturas devem criar **solicitações de coordenação** ou propostas para aprovação no modelo arquitetônico.
- O Elétrica 3D deverá ser **instalável e executável sozinho**; para produzir instalações em uma edificação, recebe arquivo ou pacote arquitetônico compatível, sem exigir que a Maquete 3D esteja executando no mesmo computador.

## 5. Critérios de aceitação

1. Instalar o Elétrica 3D sem Maquete 3D ou MultiCNC instalados; abrir um pacote arquitetônico válido.
2. Importar maquete com dois pavimentos preservando escala, coordenadas e alinhamentos.
3. Inserir tomadas, interruptores, quadros e pontos de luz associados a paredes e níveis.
4. Traçar eletrodutos 3D e cabos associados a circuitos, calculando comprimentos e quantitativos.
5. Produzir relatório de conflitos com lajes/vigas e de pontos sem conexão.
6. Exportar disciplina elétrica e abri-la sobreposta na Maquete 3D, mantendo IDs e posições.
7. Mudar a posição de uma parede no arquivo da Maquete 3D; reimportar, detectar o impacto e exigir confirmação antes de reposicionar ou desconectar elementos.
8. Salvar e reabrir o projeto elétrico sem perda de circuitos, rotas e vínculos.
9. Gerar relatório claro das verificações e marcar itens pendentes de validação profissional.

## 6. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| E1 — Maquete e pontos | Projeto elétrico próprio, maquete em referência, tomadas, interruptores, luminárias, quadros e caixas ancorados | RFE-001 a RFE-008, RFE-015 | Critérios 1 a 3 |
| E2 — Rotas e cabos | Eletrodutos, eletrocalhas, cabos e comprimentos com margens | RFE-009 a RFE-012, RFE-014 | Critério 4 |
| E3 — Circuitos e documentação | Circuitos, quadros de origem, unifilar, quantitativos e relatórios | RFE-013, RFE-022 a RFE-025 | Relatório de quantitativos de um pavimento |
| E4 — Coordenação | Exportar camada elétrica, revisões da arquitetura, erros de conexão, interferências e solicitações de coordenação | RFE-016 a RFE-019, RFE-028 | Critérios 5 a 8 |
| E5 — Engenharia assistida | Rotas assistidas, cargas, ocupação de eletrodutos, biblioteca de componentes, verificações com base na NBR 5410 | RFE-020, RFE-021, RFE-026, RFE-027 | Critério 9 |
| E6 — Intercâmbio | IFC para instalações e relações interruptor–luminária para o Criador de Cenas | RFE-029, RFE-030 | Definido ao iniciar a etapa |

**Dependências:** E1 exige a Maquete 3D na etapa M2 e as âncoras do [Núcleo Comum](Nucleo_Comum.md); a exportação para o SimuEletrica é definida no [documento de integrações](Integracoes.md).
