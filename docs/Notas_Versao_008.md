# Versão 0.08 — instalador 008

- Custo previsto e computado do projeto, com orçamento automático ou fixado.
- Apurações históricas e relatório semanal de evolução dos custos, com gráfico,
  variações, desvios, exportação HTML e CSV e identificação de semanas sem registro.
- Sprints por período, inclusão automática de pendências anteriores e tarefas do
  período, preservando a identidade das tarefas e os cartões concluídos.
- Quadro TO-DO com três situações, filtros por sprint e usuário/recurso, alteração
  de situação e acesso aos detalhes das tarefas.
- Etapas Acompanhar e Relatórios habilitadas e barras com quebra em janelas menores.
- Esquema 1.2 com leitura dos projetos anteriores e validação antes da troca.
- Exemplos de sprints nos planejamentos UBS e ala hospitalar; exemplo de relatório
  semanal com dados fictícios, sem reconstruir histórico de projetos reais.

Todos os recursos anteriores permanecem: uso geral direcionado à saúde, CAD
exclusivamente 2D, biblioteca médica, recursos/consumíveis, arquivos opcionais,
custos compostos, gestão e Setup compartilhado.

Veja [Sprints, TO-DO e custos semanais](Sprints_TODO_Custos_Semanais.md).

## Validação

| Suíte | Verificações |
|---|---:|
| Planejador e exemplos | 95 |
| Persistência CAD | 33 |
| DXF | 15 |
| Biblioteca e exemplos | 59 |
| Configuração compartilhada | 26 |
| Recursos, arquivos e custos | 57 |
| Sprints, filtros e histórico semanal | 61 |
| Interface CAD | 68 |
| Interface de recursos/custos | 15 |
| Interface TO-DO, sprints, relatórios e adaptação | 37 |
| Gestão, arquivos e permissões | 49 |
| Total | 515 |

O resultado efetivo fica em `setup/qa-tests-008.json`. Os executáveis Windows x64
são versão 0.8.0.0. Manifesto e hashes acompanham o instalador. A revisão visual
manual completa e instalação/desinstalação em ambiente limpo não são declaradas
concluídas pelos testes automatizados. O histórico semanal começa na primeira
apuração, sem simulação de custos anteriores. Não há sincronização em nuvem.
