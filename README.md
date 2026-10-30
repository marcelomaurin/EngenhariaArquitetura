# EngenhariaArquitetura

Software para Engenharia e Arquitetura.

Plataforma de aplicações independentes em Lazarus/Free Pascal que funcionam como uma linha de produção de projetos de edificações:

| # | Aplicativo | Pasta | Função |
|---|---|---|---|
| 1 | **Planejador** | [`planejador/`](planejador/README.md) | Tarefas, cronograma e coordenação das etapas |
| 2 | **CAD Arquitetônico 2D** | [`cad2d/`](cad2d/README.md) | Plantas baixas com objetos inteligentes (paredes, portas, janelas, ambientes) |
| 3 | **Maquete 3D** | [`maquete3d/`](maquete3d/README.md) | Reconstrução da edificação, editor de objetos e gerador de texturas |
| 4 | **Criador de Cenas Realistas** | [`criadorcenas/`](criadorcenas/README.md) | Câmeras, iluminação, animação e renderização fotorrealista |
| 5 | **Elétrica 3D** | [`eletrica3d/`](eletrica3d/README.md) | Projeto das instalações elétricas sobre a maquete |
| 6 | **SimuEletrica** | [`simueletrica/`](simueletrica/README.md) | Simulação elétrica, falhas, proteções e análise térmica |
| 7 | **SimuTubulações** | [`simutubulacoes/`](simutubulacoes/README.md) | Redes de água, gás, ar comprimido, ventilação e esgoto, com simulação de fluidos |

Cada pasta tem um README com o resumo do aplicativo. A documentação completa, com um documento por componente, integrações e plano de desenvolvimento, começa em [`docs/README.md`](docs/README.md).

| Documento | Conteúdo |
|---|---|
| [Visão geral](docs/Visao_Geral_Plataforma.md) | Aplicativos, objetivos, escopo e requisitos comuns |
| [Integrações](docs/Integracoes.md) | Tudo o que cada componente troca com os demais |
| [Plano de desenvolvimento](docs/Plano_Desenvolvimento.md) | Fases, etapas e decisões pendentes |
| [Decisões](docs/Decisoes.md) | Decisões tomadas e questões em aberto |

## Central de Aplicativos

O launcher independente em [`launcher/`](launcher/README.md) segue o catálogo do MultiSuite: relaciona sete softwares, mostra a disponibilidade dos executáveis e abre programas instalados. Os módulos ainda não compilados ficam indisponíveis. A homologação Windows/Linux está pendente.

## Instalação

O instalador para Windows 64 bits e os executáveis ficam em [`bin/`](bin/), como no MultiCNC:

| Arquivo | Conteúdo |
|---|---|
| `bin/setup_engenhariaarquitetura_002.exe` | Instalador da plataforma (versão 0.02) |
| `bin/planejador.exe` | Planejador para Windows 64 bits |

Como gerar o instalador: [installer/windows](installer/windows/README.md).

> **Estado:** o **Planejador** tem a etapa P1 implementada (tarefas, dependências, caminho crítico, Gantt e gravação); os demais aplicativos estão em especificação.
