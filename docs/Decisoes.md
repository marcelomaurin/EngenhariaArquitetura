# Decisões de projeto

Registro das decisões tomadas durante a concepção da plataforma (28/10/2026).

## Decisões

| # | Decisão | Reflexo na especificação |
|---|---|---|
| 1 | A plataforma é um conjunto de aplicativos que funcionam como linha de produção, cada um produzindo uma etapa do processo. | Visão geral e seção 15 |
| 2 | O primeiro aplicativo é um **Planejador** no estilo do Microsoft Project, que cria as tarefas do empreendimento. | Projeto P, seção 19 |
| 3 | O Planejador cria **tarefas arquitetônicas** executadas nos demais aplicativos. | RFP-004 a RFP-007 |
| 4 | O Planejador oferece visão de cronograma e os gráficos usados comumente no Microsoft Project. | RFP-010, 19.3 |
| 5 | O MultiCNC serve de **referência** de organização e padrão visual. | Princípios gerais |
| 6 | O **MultiCNC não faz parte do projeto**; são aceitos apenas os arquivos de sólidos que ele gera (STL e 3MF). Arquivos `.mcad` e `.msuite` não são lidos. | RF3D-057 e RF3D-058 removidos; RFI-021, 4B.3, matriz de formatos |
| 7 | CAD 2D e Maquete 3D são projetos independentes, integrados por arquivos de dados arquitetônicos. | Seções 1, 2 e 7 |
| 8 | O Editor de Objetos 3D faz parte da Maquete 3D. | Seção 4A |
| 9 | O gerador de texturas fica ligado ao programa que gera objetos; a textura é aplicada ao objeto inteiro ou a uma face dele. | Seção 4C, RF3D-053 |
| 10 | Ao criar ou importar um objeto, o Planejador pode criar tarefas, anexá-lo a tarefas existentes e vincular texturas, que ficam vinculadas aos objetos. | RFP-008, RFP-009, 19.5 |
| 11 | O Criador de Cenas Realistas é o terceiro aplicativo, independente. | Seção 13 |
| 12 | O Elétrica 3D é um aplicativo independente conectado à Maquete 3D, e não um plugin. | Seção 14 |
| 13 | O SimuEletrica é o quinto aplicativo de engenharia, independente e vinculado ao Elétrica 3D; não modifica o projeto elétrico original. | Seção 18 |

## Pontos técnicos a confirmar

- **Eixos dos arquivos do MultiCAD:** o README do MultiCAD cita `Y` para cima nas vistas, mas diz que o STL sai "em pé para o MultiSlicer" (`Z` para cima). Confirmar no exportador antes de definir a conversão padrão do importador.
- **Leitura de DWG:** escolher entre SDK licenciado da Open Design Alliance, LibreDWG (GPL) ou conversor externo; homologar com arquivos reais.
- **Leitura de IFC:** leitor próprio do subconjunto necessário ou IfcOpenShell como processo externo.
- **Motor de renderização do Criador de Cenas:** avaliar LuxCoreRender (Apache 2.0, interface em C) e Cycles do Blender como processo separado (GPL).
- **Personagens animados:** origem com licença de uso comercial.
- **Extensão do pacote nativo** da plataforma, sem conflito com `.msuite`.

## Questões em aberto

1. Quando uma textura da biblioteca é alterada, os objetos vinculados acompanham a mudança automaticamente ou mantêm a versão vinculada até atualização explícita?
2. O Planejador também vincula texturas às superfícies arquitetônicas da Maquete (paredes, pisos, lajes), ou apenas aos objetos?
3. Os aplicativos reaproveitarão componentes da suíte CHATGPT (Lazarus/FPC)?
