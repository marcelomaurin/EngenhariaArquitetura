# Versão 0.09 — instalador 009

Relatórios associados à sprint para acompanhamento de pendências e carga por pessoa.

- Relatório com pendências, atrasos, progresso, origem e esforço restante estimado.
- Carga por usuário com tarefas pendentes/concluídas, demanda, capacidade e horas apontadas.
- Apontamento diário de horas por tarefa e pessoa, com edição/remoção explícita.
- Filtros consistentes com o TO-DO, incluindo colaboradores por apontamento.
- Exportações HTML com gráfico e CSV separados para pendências, usuários e horas.
- Tarefas com atividade registrada no período também aparecem na sprint, inclusive
  quando concluídas e com prazo planejado anterior.
- Validação de duração/soma diária, preservação de horas ao editar, e proteção
  contra exclusão acidental de tarefas/pessoas referenciadas.
- Esquema de projeto 1.3; leitura dos projetos anteriores sem inventar horas.
- Exemplos com dados fictícios incluídos no instalador.

Horas apontadas e estimativas pelo progresso são separadas. Concluir uma tarefa
não cria horas nem contabiliza custos automaticamente. Os apontamentos são manuais
no Planejador, conforme suas permissões. Todas as funções anteriores permanecem.

Veja [Relatórios de sprint e carga por usuário](Relatorios_Sprint_Carga_Usuarios.md).

## Validação

| Suíte | Verificações |
|---|---:|
| Planejador e exemplos | 95 |
| Persistência CAD | 33 |
| DXF | 15 |
| Biblioteca e exemplos | 59 |
| Configuração compartilhada | 26 |
| Recursos, arquivos e custos | 57 |
| Sprints e custos semanais | 61 |
| Relatórios de sprint e apontamentos | 58 |
| Interface CAD | 68 |
| Interface de recursos | 15 |
| Interface de acompanhamento | 41 |
| Interface de relatórios de sprint | 33 |
| Gestão e permissões | 49 |
| Total | 610 |

O resultado efetivo fica em `setup/qa-tests-009.json`. Os três executáveis Windows
x64 têm versão 0.9.0.0. Manifesto e hashes acompanham o pacote. A revisão visual
manual completa e instalação/desinstalação em máquina limpa permanecem pendentes;
os fluxos essenciais e o layout das barras têm verificações LCL automatizadas.
