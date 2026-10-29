# Decisões de projeto

Registro das decisões tomadas durante a concepção da plataforma (28 e 29/10/2026). O momento em que cada pendência precisa ser resolvida está no [Plano de desenvolvimento](Plano_Desenvolvimento.md#3-decisões-e-o-momento-de-cada-uma).

## Decisões

| # | Decisão | Onde está |
|---|---|---|
| 1 | A plataforma é um conjunto de aplicativos que funcionam como linha de produção, cada um produzindo uma etapa do processo. | [Visão geral](Visao_Geral_Plataforma.md), [Integrações](Integracoes.md) |
| 2 | O primeiro aplicativo é um **Planejador** no estilo do Microsoft Project, que cria as tarefas do empreendimento. | [Planejador](Planejador.md) |
| 3 | O Planejador cria **tarefas arquitetônicas** executadas nos demais aplicativos. | [Planejador](Planejador.md): RFP-004 a RFP-007 |
| 4 | O Planejador oferece visão de cronograma e os gráficos usados comumente no Microsoft Project. | [Planejador](Planejador.md): RFP-010 e visões |
| 5 | O MultiCNC serve de **referência** de organização e padrão visual. | [Índice](README.md), princípios gerais |
| 6 | O **MultiCNC não faz parte do projeto**; são aceitos apenas os arquivos de sólidos que ele gera (STL e 3MF). Arquivos `.mcad` e `.msuite` não são lidos. | [Editor de Objetos 3D](Editor_Objetos_3D.md): RF3D-057 e RF3D-058 removidos; [Motor de Importação](Motor_Importacao.md): RFI-021 e matriz de formatos |
| 7 | CAD 2D e Maquete 3D são projetos independentes, integrados por arquivos de dados arquitetônicos. | [Visão geral](Visao_Geral_Plataforma.md), [Integrações](Integracoes.md): I-06 |
| 8 | O Editor de Objetos 3D faz parte da Maquete 3D. | [Editor de Objetos 3D](Editor_Objetos_3D.md) |
| 9 | O gerador de texturas fica ligado ao programa que gera objetos; a textura é aplicada ao objeto inteiro ou a uma face dele. | [Gerador de Texturas](Gerador_Texturas.md), RF3D-053 |
| 10 | Ao criar ou importar um objeto, o Planejador pode criar tarefas, anexá-lo a tarefas existentes e vincular texturas, que ficam vinculadas aos objetos. | [Planejador](Planejador.md): RFP-008, RFP-009; [Integrações](Integracoes.md): I-03 |
| 11 | O Criador de Cenas Realistas é o terceiro aplicativo, independente. | [Criador de Cenas](Criador_Cenas.md) |
| 12 | O Elétrica 3D é um aplicativo independente conectado à Maquete 3D, e não um plugin. | [Elétrica 3D](Eletrica_3D.md) |
| 13 | O SimuEletrica é o quinto aplicativo de engenharia, independente e vinculado ao Elétrica 3D; não modifica o projeto elétrico original. | [SimuEletrica](SimuEletrica.md) |
| 14 | Cada componente da plataforma tem um documento específico em `docs`, com especificação e etapas de desenvolvimento; um documento de integrações cobre as trocas entre eles. | [Índice](README.md) |
| 15 | O **SimuTubulações** é um aplicativo independente, vinculado à Maquete 3D e coordenado com o Elétrica 3D, que edita e simula redes prediais de água fria e quente, gás, ar comprimido, ventilação e esgoto; edição e cálculo ficam no mesmo executável nesta fase. | [SimuTubulações](SimuTubulacoes.md), [Integrações](Integracoes.md): I-18 a I-23 |
| 16 | Os aplicativos **reaproveitam a suíte CHATGPT**, como o MultiCNC: o Planejador usa os pacotes AIProjectCore e AIProject (grafo, calendário, caminho crítico, Gantt). Os projetos procuram a CHATGPT em `..\CHATGPT\pacote\` e usam a cópia em `third_party/chatgpt` como reserva. | [Planejador](Planejador.md), [Núcleo Comum](Nucleo_Comum.md) |
| 17 | O desenvolvimento começou pelo **Planejador** (etapa P1), antecipando a fase 3 do plano. | [Plano de desenvolvimento](Plano_Desenvolvimento.md) |

## Pontos técnicos a confirmar

- **Eixos dos arquivos do MultiCAD:** o README do MultiCAD cita `Y` para cima nas vistas, mas diz que o STL sai "em pé para o MultiSlicer" (`Z` para cima). Confirmar no exportador antes de definir a conversão padrão do importador.
- **Leitura de DWG:** escolher entre SDK licenciado da Open Design Alliance, LibreDWG (GPL) ou conversor externo; homologar com arquivos reais.
- **Leitura de IFC:** leitor próprio do subconjunto necessário ou IfcOpenShell como processo externo.
- **Motor de renderização do Criador de Cenas:** avaliar LuxCoreRender (Apache 2.0, interface em C) e Cycles do Blender como processo separado (GPL).
- **Personagens animados:** origem com licença de uso comercial.
- **Motores do SimuTubulações:** avaliar licença de redistribuição, interface e desempenho do EPANET, do SWMM e do OpenModelica.
- **Pressões e unidades de fluidos:** formalizar pressões absolutas e manométricas, sobretudo para gases.
- **Gases medicinais e vácuo clínico:** fora do modelo genérico; exigem módulo especializado aprovado à parte (ABNT NBR 12188).
- **Extensão do pacote nativo** da plataforma, sem conflito com `.msuite`.

## Questões em aberto

1. Quando uma textura da biblioteca é alterada, os objetos vinculados acompanham a mudança automaticamente ou mantêm a versão vinculada até atualização explícita?
2. O Planejador também vincula texturas às superfícies arquitetônicas da Maquete (paredes, pisos, lajes), ou apenas aos objetos?
3. A primeira fase do SimuTubulações será só predial (recomendado na especificação) ou também industrial?
