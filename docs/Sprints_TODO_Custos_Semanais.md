# Sprints, TO-DO e evolução semanal dos custos

## Custos do projeto

O resumo do projeto e a etapa **7 Custos / relatórios** apresentam:

- **Custo previsto:** soma da previsão das tarefas; opcionalmente pode ser fixado
  como orçamento do projeto, pelo botão **Orçamento previsto**.
- **Custo computado:** soma dos componentes marcados como contabilizados nas
  tarefas (custos diretos, consumíveis e recursos/hora). Preserva o cálculo de
  custo de saída implementado na versão anterior.
- **Desvio:** computado menos previsto. Valores positivos destacam ultrapassagem.

Fixar o orçamento mantém a referência, mesmo quando a composição das tarefas
muda. Assim, o computado pode ultrapassar o previsto sem a aplicação elevar
silenciosamente o orçamento. Desmarcar a opção volta à previsão automática.
O limite monetário do orçamento total é o mesmo do total do projeto.

## Relatório e gráfico semana a semana

O Planejador guarda apurações datadas dos totais previsto e computado dentro do
arquivo do projeto. No uso normal, registra o estado atual ao recalcular ou salvar
o planejamento identificado. No mesmo dia, conserva a última apuração; registros
de dias e semanas anteriores permanecem preservados.

Para registrar ou corrigir explicitamente uma data, escolha-a no campo junto de
**Registrar apuração**. Essa ação registra os totais atuais na data informada.
Uma data retroativa não recupera valores antigos automaticamente: ela é uma
apuração/correção fornecida pelo usuário. O arquivo do projeto deve ser salvo
para persistir todas as alterações.

A tabela e o gráfico usam semanas de segunda a domingo, exibindo o último estado
apurado em cada semana. São apresentados previsto, computado, desvio, variação
semanal do previsto, variação do computado e sua variação percentual. Quando a
base anterior é zero, a porcentagem fica indisponível. Reduções ou estornos de
contabilização aparecem como variações negativas.

A primeira semana é a **base inicial**; seu total não é tratado como gasto
ocorrido integralmente naquela semana. Semanas sem nova apuração mantêm os
últimos valores e são identificadas. Não há reconstrução fictícia de custos
anteriores ao primeiro registro. Trata-se da evolução dos totais apurados, não de
uma distribuição estimada de desembolsos nem de confirmação de pagamento.

Use **Exportar CSV** ou **Relatório HTML**. O HTML inclui gráfico e tabela,
funciona sem conexão e pode ser impresso pelo navegador. O CSV é UTF-8 com BOM.
O instalador inclui `relatorio_custos_exemplo.html` e `.csv`, com dados fictícios,
para mostrar aumento, ultrapassagem, uma semana sem registro e uma correção.

## Sprints por período

Abra **6 TO-DO / Sprints** e clique **Nova sprint**. Informe nome, início e fim
(inclusive). A duração é livre até dez anos; a sugestão inicial é de duas semanas.
Após a primeira, a sugestão começa no dia seguinte ao fim da última cadastrada.
Não é permitido duplicar o mesmo período; períodos parcialmente sobrepostos são
permitidos, pois são agrupamentos de planejamento.

A composição automática inclui:

1. Todas as tarefas cujo intervalo calculado intersecta o período, inclusive
   tarefas em andamento que começaram antes e marcos que caem no período.
2. Tarefas de períodos anteriores que ainda não foram concluídas, identificadas
   como origem em pendência anterior.

As tarefas continuam únicas no projeto. Uma tarefa pode participar de várias
sprints, mas aparece apenas uma vez dentro de cada uma. Criar uma sprint não
altera duração, dependências ou datas das tarefas. Novas tarefas elegíveis são
incluídas ao recalcular; **Atualizar tarefas** força a atualização.

Uma vez incluída, a tarefa permanece no agrupamento após a conclusão, para que
seu cartão possa ser visto em Concluídas. Uma sprint nova não traz tarefas já
concluídas de períodos anteriores. O quadro mostra a situação atual das tarefas;
não é uma reprodução da situação em uma data passada.

**Editar período** recalcula a composição se as datas mudarem. **Excluir sprint**
remove apenas o agrupamento, preservando todas as tarefas. Excluir uma tarefa
remove suas referências nas sprints. Os exemplos UBS e ala hospitalar contêm dois
períodos ilustrativos, preenchidos pelas mesmas regras da aplicação.

## Visualização TO-DO e filtros

O quadro apresenta **A fazer**, **Em andamento** e **Concluída**, com cartões,
contagens e uma barra de distribuição por situação. Escolha uma sprint ou Todas
as tarefas, e filtre por **Usuário / recurso**. O filtro considera tanto o executor
vinculado à pessoa quanto as alocações explícitas, incluindo equipes e equipamentos.
Os recursos vêm do catálogo do projeto, que pode receber usuários pela etapa Recursos.

Selecione um cartão e use o botão da situação desejada. Concluir define progresso
em 100%; reabrir em A fazer redefine para zero; iniciar mantém um progresso entre
1% e 99%. Duplo clique abre os detalhes da tarefa no Planejador. A mudança de
situação não contabiliza custos automaticamente nem torna arquivos obrigatórios.

Os cartões concluídos que vieram de pendências mantêm a indicação de origem,
sem serem tratados como pendência atual. Barras e filtros se adaptam a janelas
menores por quebra dos controles em linhas.

## Persistência, acesso e limites

O esquema `.plan.json` é **1.3**, com orçamento, histórico de custos e sprints
opcionais na leitura. Projetos antigos continuam aceitos, com previsão automática,
sem histórico inventado e sem sprints artificiais. Use o executável atual para
preservar os novos campos ao salvar. Dados inválidos são recusados antes de trocar
o projeto ativo.

O acesso mantém as permissões do Planejador: Administrador e Usuário gerenciam o
planejamento; perfis restritos/visualizadores continuam na gestão permitida. Um
filtro por recurso é uma seleção da visão, não uma mudança de permissões.
O quadro não sincroniza pela nuvem nem consolida projetos distintos. Alterações
nas tarefas publicadas para o CAD continuam seguindo o envio/retorno já existente.

As sprints e apurações pertencem ao projeto aberto. Não há burndown, velocidade,
controle financeiro bancário, pagamento ou estoque automático. A revisão visual
manual completa e a instalação em ambiente limpo continuam pendentes; testes
LCL verificam os fluxos e a adaptação das barras a janelas menores.

A entrega 009 inclui [relatórios associados à sprint e horas por usuário](Relatorios_Sprint_Carga_Usuarios.md). Atividade apontada no período também associa a tarefa à sprint, inclusive quando concluída fora do prazo originalmente planejado.
