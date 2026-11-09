# Engenharia e Arquitetura

Suite integrada para gestão, planejamento e desenvolvimento de projetos de engenharia civil e arquitetura, desenvolvida em Lazarus/Free Pascal com suporte a Windows e Linux.

[English](docs/README.en.md)

## Aplicativos da plataforma

- **Central de Aplicativos:** lançador que organiza o acesso às ferramentas da suíte.
- **Planejador:** planejamento de obras com cronograma, dependências e caminho crítico.
- **CAD Arquitetônico 2D:** desenho técnico 2D com paredes, portas, janelas e cotas.
- **Modelador 3D:** em especificação.
- **Estruturas:** em especificação.
- **Hidráulica:** em especificação.
- **Elétrica:** em especificação.
- **Orçamentista:** em especificação.

## Atualização automática

A partir da versão 0.03, os instaladores configuram atualização automática com
base nos lançamentos do GitHub Releases. A checagem ocorre na abertura do launcher
e sob demanda; a integridade é verificada por SHA256 e a instalação aguarda o
fechamento dos aplicativos abertos. Para detalhes, limites e arquitetura, consulte
[Atualização Automática](docs/Atualizacao_Automatica.md).

## Executáveis e instalador Windows

O instalador para Windows 64 bits e os executáveis portáteis ficam na pasta `bin/`:

| Arquivo | Conteúdo |
|---|---|
| `bin/setup_engenhariaarquitetura_010.exe` | Instalador da plataforma (versão 0.10) |
| `bin/planejador.exe` | Planejador para Windows 64 bits |
| `bin/cad2d.exe` | CAD Arquitetônico 2D para Windows 64 bits |
| `bin/engenhariaarquitetura.exe` | Central de Aplicativos (lançador) |

Como gerar o instalador: [installer/windows](installer/windows/README.md).

> **Estado:** Planejador e CAD 2D têm executáveis Windows, com gestão local integrada de tarefas, usuários e quatro perfis. O CAD trabalha exclusivamente em 2D e continua em evolução; os demais aplicativos permanecem em especificação.

## Modelos de hospital

A pasta [samples/files](samples/README.md) inclui o mesmo hospital demonstrativo em IFC4, DWG, DXF e formato nativo CAD2D. Os instaladores incluem os modelos no componente CAD2D.

## Versão 0.06 — instalador 006

O CAD inclui barra lateral 2D/Tarefa/Gestão, menu principal no topo, paleta azul
do MultiCNC e aba Gestão para responder, devolver a tarefa com arquivo associado
e voltar ao Planejador. O Planejador permite criar contas, atribuir tarefas e
acompanhar andamento, retornos e pendências.

Os acessos são Administrador, Usuário, Usuário restrito (my task only) e
Visualizador. No primeiro acesso ao Planejador, crie o Administrador. A gestão
é local e compartilhada entre os aplicativos; não há sincronização entre computadores.

- [Guia de gestão, usuários e primeiro acesso](docs/Gestao_Tarefas_Usuarios.md)
- [Notas da versão 004 e validação](docs/Notas_Versao_004.md)

O histórico de Desfazer/Refazer reutiliza AI Project Core do projeto CHATGPT.
A revisão visual manual da instalação e do fluxo completo permanece pendente.

## Melhorias de confiabilidade (entrega 005)

- EACAD4 preserva altura, peitoril, grupo, grade, visibilidade e bloqueio das camadas. A entrega 006 evolui para EACAD5, incluindo identificação dos blocos e nomes dos ambientes.
- Leitura de EACAD1/2/3 com migração de coordenadas para resolução de 1 mm.
- Salvamento com arquivo temporário e substituição segura no CAD e no Planejador.
- Validação de arquivos inválidos, ciclos, autodependências e vínculos duplicados.
- Importação DXF ASCII de entidades LINE 2D, com relatório de perdas e unidades.
- Exportação CSV das tarefas permitidas ao perfil do usuário.
- Enquadramento inicial do desenho após a janela adquirir seu tamanho final.

Veja [as notas da versão 005](docs/Notas_Versao_005.md) para limites, testes e pendências.

## Bibliotecas e exemplos de saúde

A versão 0.06 inclui 48 itens em biblioteca 2D, estudos esquemáticos de UBS e ala hospitalar e exemplos de planejamento correspondentes. As medidas são iniciais e editáveis; o exemplo residencial e os recursos gerais permanecem disponíveis. Consulte [Direcionamento para saúde e SUS](docs/Direcionamento_Saude_SUS.md) e [Notas da versão 006](docs/Notas_Versao_006.md).

- [Setup e configuração compartilhada](docs/Setup_Configuracao_Compartilhada.md): preferências comuns, último projeto e login lembrado.

## Recursos e custos — entrega 007

Etapa Recursos habilitada, arquivos opcionais de entrada/saída e custos compostos.
Consulte [Recursos, arquivos e custos](docs/Recursos_Arquivos_Custos.md) e [Notas da versão 007](docs/Notas_Versao_007.md).

## Acompanhamento — entrega 008

Sprints, quadro TO-DO filtrado por usuário/recurso e evolução semanal do custo previsto e computado.
Veja [o guia de acompanhamento](docs/Sprints_TODO_Custos_Semanais.md) e [as notas 008](docs/Notas_Versao_008.md).

## Relatórios por sprint — entrega 009

Pendências e carga por usuário, com horas apontadas, estimativas separadas e exportação HTML/CSV.
Veja [o guia de relatórios de sprint](docs/Relatorios_Sprint_Carga_Usuarios.md) e [as notas 009](docs/Notas_Versao_009.md).

## Versão 0.10 — instalador 010

Interoperabilidade BIM/CAD (DXF, DWG, IFC), modelos hospitalares demonstrativos e pipeline de releases contínuos.
Consulte [Notas da versão 010](docs/Notas_Versao_010.md).
