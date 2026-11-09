# Recursos, arquivos de entrada/saída e custos

## Cadastro e disponibilidade

No Planejador, abra **4 Recursos**. A etapa está habilitada e contém o cadastro
com os tipos Pessoa, Equipe, Equipamento, Material/consumível e Arquivo/link.
Use Novo recurso, Editar ou Importar usuários. Pessoas podem estar vinculadas a
usuários; o executor de uma tarefa aparece como recurso com dedicação implícita
de 100%, salvo quando houver uma alocação explícita desse mesmo recurso.

Capacidade de 100% representa uma unidade de trabalho; 200% representa duas.
Equipes são recursos agregados: a capacidade deve ser indicada pelo gestor,
sem inferência automática de integrantes. O recurso pode usar o calendário do
projeto ou uma jornada própria (dias da semana e intervalos com pausa). A aba de
disponibilidade permite delimitar datas e cadastrar férias/afastamentos, com
uma data ou intervalo por linha, no formato `2026-11-10..2026-11-15`.

A visão inferior, baseada em AIResourceView do projeto CHATGPT, apresenta as
alocações ao longo do tempo. Sobrecargas são destacadas. Duplo clique em uma barra
abre a tarefa. O cálculo AIResourceLoad considera capacidade e tempo útil. Tarefas
fora da jornada/disponibilidade recebem aviso próprio. Os alertas não bloqueiam
salvamento e não remanejam datas automaticamente. A apuração é do projeto aberto.
Materiais e arquivos não são tratados como pessoas nem geram sobrecarga horária.

## Recursos e arquivos na tarefa

Nos detalhes da tarefa, clique **Recursos / arquivos de entrada e saída**.
Adicione quantos recursos forem necessários, com dedicação percentual para
trabalho/equipe/equipamento e quantidade para material consumível.
A mesma alocação não pode ser repetida; use Atualizar para alterar a quantidade.

O botão **Arquivos de entrada/saída** permite adicionar, editar, remover e abrir
vínculos. Cada vínculo tem nome, caminho/URL e direção:

- Entrada (input): referência, documento, levantamento ou outra informação usada.
- Saída (output): arquivo entregue ou entrega prevista.

Os vínculos são opcionais. A tarefa pode não ter arquivo algum, pode ter várias
entradas e saídas e pode indicar um arquivo de saída ainda inexistente. Arquivos
são registrados no catálogo como recursos reutilizáveis. Os vínculos não copiam,
enviam nem embutem o conteúdo dos arquivos. Caminhos relativos são resolvidos na
pasta do projeto ao abrir ou enviar a tarefa; salvar o projeto permite resolver
esses caminhos com segurança. Links HTTP/HTTPS são abertos no navegador apenas
quando o usuário solicita. A abertura pelo gerenciador bloqueia extensões de
executáveis e scripts. A associação principal ao desenho CAD continua separada.

Ao enviar ao CAD, os arquivos de entrada/saída acompanham a tarefa. Na gestão,
o executor pode atualizar os vínculos da própria tarefa; o visualizador pode
consultar e abrir, sem alterar. Ao aplicar o retorno no Planejador, a lista é
atualizada, incluindo remoções, preservando alocações de trabalho e consumíveis.

## Custos compostos e consumíveis

O cadastro de recurso aceita preço unitário: por hora para pessoa/equipe/equipamento
e por unidade para material consumível. Ao alocar, o preço é copiado para a
alocação e pode ser ajustado. Alterar o preço do catálogo depois não altera os
preços já alocados. O executor implícito não é cobrado automaticamente: aloque-o
explicitamente com preço e contabilização para compor o custo de trabalho.

**Consumíveis são sempre recursos de entrada.** A direção é definida pela
interface e validada também no modelo e na leitura do arquivo. A lista é variável,
com quantidade, preço unitário e marcação **Contabilizar custo** para cada item.

Em **Compor custos da tarefa**, adicione uma lista variável de custos diretos,
cada um com descrição, quantidade, valor unitário e marcação de contabilização.
Isso permite compor serviços, taxas e outros componentes sem obrigar o cadastro
de um consumível correspondente.

As saídas monetárias são calculadas, sem duplicar subtotais:

- Consumível: quantidade × preço unitário alocado.
- Recurso de trabalho: duração da tarefa em horas × dedicação × preço/hora alocado.
- Custo direto: quantidade × valor unitário do componente.
- **Custo de saída da tarefa:** soma dos componentes contabilizados acima.
- **Custo previsto:** mesma soma incluindo os componentes ainda não contabilizados.
- **Custo de saída do projeto:** soma dos custos de saída de suas tarefas.

Exemplo: 10 folhas a R$ 1,50 + 0,1 unidade de toner a R$ 100,00 + acabamento de
R$ 25,00 resultam em **R$ 50,00 de saída**, se todos forem contabilizados.
Os arquivos vinculados não geram custo por si. A saída monetária não é somada
novamente como entrada de outra tarefa. Preços são guardados em centavos e cada
componente é arredondado ao centavo antes da soma.

A coluna Custo de saída do Gantt, os detalhes da tarefa e o resumo do projeto
mostram os valores. Ao enviar uma tarefa ao CAD, os totais são publicados para
consulta na gestão; a exportação CSV das tarefas inclui previsto e saída. A
alteração da composição de custos permanece no planejamento, conforme as permissões.

## Persistência, exemplos e limites

O arquivo `.plan.json` passa ao esquema **1.1**. As listas `recursos`, `alocacoes`
e `custos` são opcionais na leitura; projetos antigos continuam aceitos. Os
campos `custo_saida_centavos` são resultados informativos: a aplicação recalcula
a soma dos componentes. Arquivos inválidos não substituem o projeto ativo.
Use o executável 007 para preservar esses novos campos; programas antigos podem
ignorá-los ao salvar.

Os exemplos UBS e ala hospitalar mantêm 14 tarefas e agora mostram estação CAD,
papel, toner, composição de custo e vínculos de arquivos previstos. **Os preços
são fictícios e apenas demonstrativos.** Nenhum arquivo ou usuário real é criado
por esses exemplos. A biblioteca gráfica médica não gera orçamento automaticamente.

Esta entrega não inclui estoque, compras, notas fiscais, tributação automática,
nivelamento automático nem consolidação de recursos
entre projetos. A contabilização indica quais componentes compõem o total; não
representa confirmação de pagamento. A base por hora usa duração e dedicação
configuradas na tarefa. A revisão visual manual completa e a instalação em máquina
limpa permanecem pendentes; os fluxos essenciais de interface possuem testes LCL.

A entrega 009 acrescenta [apontamentos e relatórios de sprint](Relatorios_Sprint_Carga_Usuarios.md). As horas registradas são separadas da composição monetária, sem cobrança automática.
