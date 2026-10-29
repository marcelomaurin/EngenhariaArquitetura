# SimuTubulações 3D

Editor 3D e simulador de redes prediais de fluidos e esgoto. Aplicativo independente que usa a maquete como referência para projetar e simular redes de **água fria e quente, gás natural e GLP, ar comprimido, ventilação e esgoto sanitário**, com editor próprio de tubos, dutos e componentes e motores de cálculo adequados a cada fluido.

> **Estado:** em especificação. Especificação completa e etapas de desenvolvimento em [docs/SimuTubulacoes.md](../docs/SimuTubulacoes.md); integrações em [docs/Integracoes.md](../docs/Integracoes.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Pacote arquitetônico da Maquete 3D; disciplina elétrica como referência; tarefas do Planejador | Disciplina de tubulações, cenários, resultados, mapas 3D, quantitativos e relatórios | Maquete 3D (visualização), Elétrica 3D (coordenação), Criador de Cenas (apresentação) |

O SimuTubulações **não altera** os arquivos da Maquete 3D nem do Elétrica 3D: publica sua própria disciplina e pede alterações arquitetônicas por solicitação de coordenação. Cada tipo de rede tem grafo próprio; redes diferentes nunca se conectam, mesmo quando se cruzam no espaço.

## Redes previstas

| Rede | Principais análises |
|---|---|
| Água fria | Vazão, pressão residual, perda de carga, velocidade, bombeamento |
| Água quente | Distribuição, recirculação e queda térmica estimada |
| Gás natural e GLP | Queda de pressão em fluido compressível, consumo e vazamento hipotético |
| Ar comprimido | Queda de pressão, consumo intermitente, compressores e reservatórios |
| Ventilação e climatização (dutos) | Equilíbrio da rede, perdas e distribuição de ar |
| Esgoto sanitário | Escoamento por gravidade, declividade, capacidade, contrapendência e refluxo |

Gases medicinais e vácuo clínico ficam fora do modelo genérico e exigem módulo especializado aprovado à parte.

## Funcionalidades

- **Modelagem 3D:** tubos e dutos com curvas e desvios, conexões, válvulas, registros, reguladores, bombas, compressores, ventiladores, reservatórios, pontos de consumo e caixas de inspeção.
- **Verificações:** pontas abertas, conexões incompatíveis, colisões com arquitetura, elétrica e outras redes.
- **Cálculo:** vazões, pressões, perdas distribuídas e localizadas, desníveis, declividades e temperaturas, conforme o tipo de rede.
- **Cenários:** demanda, vazamento, bloqueio, válvula fechada, bomba indisponível; comparação lado a lado sem alterar o cenário base.
- **Resultados:** trechos coloridos por pressão, vazão, velocidade, perda ou temperatura, perfil longitudinal, quantitativos e relatórios PDF/CSV.
- **Honestidade numérica:** recusa calcular quando os dados ou o modelo não sustentam o resultado.

## Motores de cálculo previstos

| Rede | Referência |
|---|---|
| Água pressurizada | EPANET (EPA) |
| Esgoto e drenagem | EPA SWMM |
| Gás e ar comprimido | Modelica.Fluid via OpenModelica ou solucionador próprio |
| Dutos de ar | Solucionador de rede de dutos com curvas de ventilador |

Nenhum motor externo é presumido integrado; licenças e forma de integração ainda serão avaliadas.

## Requisitos

| Faixa | Assunto |
|---|---|
| ST-001 a ST-020 | Importação e modelagem 3D |
| ST-021 a ST-027 | Água fria e quente |
| ST-028 a ST-037 | Gás, ar comprimido e dutos |
| ST-038 a ST-047 | Esgoto, falhas e cenários |
| ST-048 a ST-060 | Visualização, relatórios e coordenação |
| ST-NF01 a ST-NF12 | Requisitos não funcionais |

## Etapas

| Etapa | Escopo |
|---|---|
| TB1 — Núcleo geométrico | Importação da maquete, edição de redes, conectores, catálogo e colisões |
| TB2 — Água | Redes pressurizadas, válvulas e bombas |
| TB3 — Esgoto | Declividades, capacidade, contrapendências, obstruções e refluxo |
| TB4 — Gás e ar | Solucionadores compressíveis, compressores, reguladores e dutos |
| TB5 — Cenários e BIM | Mapas 3D, relatórios, comparação, IFC e coordenação com a elétrica |
| TB6 — Avançados | Transitórios, golpe de aríete, transferência de calor e escoamento detalhado opcional |

## Normas de referência

ABNT NBR 5626 (água fria e quente), NBR 8160 (esgoto), NBR 15526 e NBR 15358 (gás combustível), NBR 10844 (águas pluviais, se incluídas), NBR 16401 (ar condicionado e dutos) e ISO 8573-1 (pureza do ar comprimido), conforme edição vigente e aplicabilidade.

> A simulação não substitui projeto, ensaios de estanqueidade, comissionamento, fiscalização nem a responsabilidade técnica de profissional habilitado.
