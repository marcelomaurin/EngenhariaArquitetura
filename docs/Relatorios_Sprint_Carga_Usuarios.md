# Relatórios de sprint, pendências e carga por usuário

## Como acessar

No Planejador, abra **6 TO-DO / Sprints**, selecione uma sprint e clique em
**Relatório da sprint**. O filtro de usuário/recurso do quadro é levado ao relatório
e pode ser alterado na janela. A data junto do filtro é a referência para os
atrasos; as situações e os progressos exibidos são os atuais.

O relatório possui quatro abas:

- **Pendências:** tarefas não concluídas, executor, progresso, prazo, atraso,
  origem em período anterior, saldo estimado e horas apontadas no período.
- **Carga por usuário:** tarefas em que a pessoa participa, pendentes/concluídas,
  atrasos, carga prevista no período, carga concluída/restante estimada, horas
  apontadas na sprint e capacidade segundo seu calendário.
- **Horas apontadas:** data, usuário, tarefa, horas e observação de cada registro.
- **Escopo completo:** todas as tarefas da sprint e do filtro, inclusive concluídas.

**Relatório HTML** gera uma versão com resumo, gráfico de carga, tabelas e relação
de tarefas concluídas, que funciona sem conexão e pode ser impressa pelo navegador.
Os botões CSV exportam separadamente pendências, carga por usuário e apontamentos.
Os arquivos incluem identificação e período da sprint; os relatórios com atrasos
incluem a data de referência. CSV usa UTF-8 com BOM e protege campos de texto
contra interpretação como fórmulas de planilha. O filtro selecionado limita as
exportações, assim como a tela.

## Registrar a carga realizada

Selecione um cartão no TO-DO e clique **Apontar horas**. Também é possível apontar
pela janela do relatório. Informe tarefa, pessoa que executou, data, duração em
horas e observação opcional. Os valores são arredondados ao minuto. Pessoas são
recursos do tipo Pessoa, que podem estar vinculados aos usuários cadastrados;
a etapa Recursos permite importar usuários para o projeto.

Na aba Horas apontadas, selecione um registro para editar ou remover. A remoção
pede confirmação e preserva a tarefa. Para evitar alteração de registro oculto,
as ações Editar/Remover exigem essa aba aberta e um apontamento selecionado.
Os registros devem ter duração positiva, até 24 horas por lançamento e até 24
horas somadas por pessoa/data dentro do projeto. Erros de edição preservam o
registro anterior. Tarefas e pessoas com horas apontadas não são apagadas
silenciosamente: corrija/remova explicitamente os apontamentos antes de excluí-las.
O vínculo de login de uma pessoa com horas registradas também é protegido na edição.

O apontamento é feito no Planejador pelos perfis que podem editar o planejamento
(Administrador e Usuário), com a pessoa executora indicada. Os dados são manuais,
salvos no arquivo do projeto; não são captura automática de atividade do usuário.
O retorno do CAD continua seguindo os fluxos de status, arquivos e respostas já
existentes. **Salve o projeto** para preservar as horas lançadas.

## O que os números significam

**Horas apontadas na sprint** são apenas os registros de trabalho da pessoa nas
tarefas do agrupamento, com data entre início e fim da sprint, inclusive. Trabalho
antes/depois não entra nesse total. Marcar uma tarefa como concluída não cria
horas realizadas automaticamente. Pessoas que colaboraram por apontamento podem
aparecer mesmo sem serem executoras ou alocadas formalmente.

**Carga prevista no período** considera o intervalo calculado que cai dentro da
sprint e a dedicação da pessoa. Para pendências com prazo inteiramente anterior,
inclui o saldo estimado ainda não concluído. **Restante estimado do escopo** é o
esforço completo atribuído à pessoa, ponderado pelo progresso atual; pode abranger
trabalho além do período em tarefas longas. **Concluída estimada do escopo** é a
parte correspondente ao progresso, e não uma medição de horas realizadas.

O executor possui alocação implícita de 100%, salvo quando há uma alocação explícita
dessa mesma pessoa; os relatórios respeitam a dedicação explícita, sem somar outra
alocação fictícia do executor. A capacidade usa calendário, ausências, datas de
disponibilidade e percentual do recurso. O HTML destaca demanda/horas acima da
capacidade. A comparação é da sprint inteira, não somente dos dias já transcorridos.

Uma tarefa compartilhada aparece uma vez no escopo geral, mas pode participar da
contagem de mais de uma pessoa. As contagens por usuário não devem ser somadas
como tarefas distintas. Equipes agregadas não são divididas automaticamente entre
integrantes; sem pessoa atribuída, a responsabilidade aparece como **Sem usuário
atribuído**, e as horas reais continuam vinculadas a quem as apontou.

O filtro de Pessoa limita os totais àquela pessoa; filtros de equipe/equipamento
limitam o conjunto de tarefas e mostram seus participantes. Contribuição real por
apontamento também é considerada no filtro de pessoa do TO-DO para o período.

## Associação à sprint e preservação

Além das regras já existentes de período e pendências, uma tarefa com apontamento
real dentro do período é incluída no agrupamento ao recalcular, mesmo que seu prazo
planejado seja anterior e ela já esteja concluída. Isso preserva a visibilidade do
trabalho realizado no período. Remover uma sprint não remove os apontamentos, que
pertencem à tarefa/pessoa/data. Períodos sobrepostos podem mostrar os mesmos registros;
não some esses relatórios como se fossem períodos independentes.

O esquema `.plan.json` é **1.3**. A coleção de apontamentos é opcional na leitura:
projetos anteriores continuam abrindo sem horas inventadas. Referências órfãs,
identificações duplicadas, datas/durações inválidas e somas diárias impossíveis são
recusadas antes de trocar o projeto ativo. Use a versão atual para preservar os
novos campos; programas antigos podem ignorá-los ao salvar.

O apontamento **não altera automaticamente os custos**, nem comprova pagamento.
A composição monetária e sua contabilização continuam nas regras de custos da
tarefa. A carga é apurada no projeto aberto, sem consolidação automática entre
projetos nem sincronização em nuvem. O filtro é uma seleção da visão e não altera
as permissões de acesso. O gráfico do HTML mostra até 30 pessoas; a tabela permanece
completa. Os nomes são escapados no HTML e não executam código.

O instalador inclui `relatorio_sprint_exemplo.html`, `sprint_pendencias_exemplo.csv`,
`sprint_usuarios_exemplo.csv` e `sprint_horas_exemplo.csv`, todos com **dados fictícios**.
