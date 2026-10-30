# Auditoria focada — Planejador: o que falta implementar

**Data:** 30/10/2026  
**Repositório:** `marcelomaurin/EngenhariaArquitetura` · branch `fila`  
**Revisão-base:** `6b9b4e5bdd` (a última revisão consultada contém apenas atualizações de documentação sobre a base funcional de `a60c70437f`).  
**Escopo:** **somente o Planejador**. Não propor novos softwares ou alterar o propósito dos aplicativos de arquitetura.  
**Evidência:** inspeção dos fontes `planejador/src/{core,io,app}`, do teste `planejador/tests/test_planejador_core.lpr`, do README e dos contratos de `docs/Integracoes.md`. **Não houve compilação, execução de testes ou operação manual de interface nesta auditoria.**

## 1. Papel e limites

O Planejador é o **gerenciador de tarefas, prazos, dependências, recursos e entregas** da EngenhariaArquitetura. O Microsoft Project é referência funcional de gestão; o MultiProject/MultiCNC pode servir como referência de organização e padrão visual, **mas não é componente incorporado ao pacote**. O Planejador não cria plantas, sólidos, cenas, circuitos ou tubulações, tampouco substitui os aplicativos das disciplinas.

A integração é **por arquivos/pacotes versionados**: o Planejador cria/despacha tarefas, associa entradas e parâmetros, acompanha estados, recebe artefatos/relatórios e identifica revisões. Aplicativos continuam executáveis separados; uma tarefa pode ser preparada e validada com aplicativo ausente, sem fingir execução bem-sucedida.

## 2. Situação realmente observada

| Área | Estado do código consultado | Evidência |
|---|---|---|
| Cadastro de projeto/tarefa | **Implementado em nível básico** | `plan_tipos.pas`, `plan_documento.pas` |
| Dependências TI/II/TT/IT e latência | **Implementado** | `DefinirItens`, `AdicionarVinculo`, `RemoverVinculo` e `plan_cronograma.pas` |
| Rejeição de ciclos e vínculos inválidos na edição | **Implementado nas rotinas de edição** | `plan_documento.pas`, testes declarados |
| Cronograma, caminho crítico, folgas e Gantt | **Implementado em núcleo/interface** | `plan_cronograma.pas`, `plan_principal.pas`, bibliotecas CHATGPT |
| Diagrama de rede com vinculação por arraste | **Implementado antecipadamente de P3** | `plan_principal.pas` e README do Planejador |
| Salvar/abrir `.plan.json` | **Implementado, com salvaguardas a corrigir** | `plan_json.pas`, `AbrirArquivo` |
| Seleção do aplicativo responsável | **Somente cadastro** | Enum `TPLAplicativo` e seleção no painel; sem despacho/retorno |
| Abrir tarefa no CAD/Maquete/etc. | **Não implementado** | Não há execução de aplicativo, entradas/saídas de tarefa ou contrato completo no modelo `TPLTarefa` |
| Receber arquivos produzidos, versão/hash e retorno | **Não implementado** | Campos ausentes de `TPLTarefa` e serialização JSON |
| Bloqueio/liberação por conclusão de predecessoras | **Não implementado como regra de workflow** | Grafo agenda tarefas, mas estado `Situacao` é editável sem verificação de artefatos |
| Recursos/custos, linha de base, calendário visual, Curva S | **Não implementados na interface própria** | P3 em especificação; calendário base existe para cálculo de datas |
| Objetos, texturas e vínculos por tarefa | **Não implementados** | P4 depende de Maquete 3D/Editor/Skins |
| Relatórios e exportações gerenciais | **Não identificados no menu atual** | `plan_principal.pas` oferece menus Arquivo, Tarefa, Exibir e Ajuda |
| Testes e Linux | **Testes de núcleo presentes; homologação atual não demonstrada** | `test_planejador_core.lpr` cobre P1; não foi localizado pipeline `.github/workflows` nesta revisão |

**Não confundir:** ter o aplicativo como opção no campo `Aplicativo` **não** significa abrir a ferramenta; ter o campo `Situação` **não** significa validar liberação automática; ter calendário de cálculo **não** significa vista de calendário gerencial; ter arquivo JSON **não** significa cumprir todo o manifesto interaplicativos.

## 3. Itens prioritários a implementar (backlog específico)

Prioridades indicadas nesta auditoria: **P0 = condição para entrega confiável/fluxo P2**; **P1 = acompanhamento e usabilidade**; **P2 = expansão vinculada à Maquete 3D**.

| ID | Prioridade | Lacuna | Requisito e critério de aceite |
|---|---|---|---|
| **PL-001** | **P0** | Integridade ao abrir | Ler e validar novo arquivo em **documento temporário**; somente substituir o atual após sucesso. JSON inválido preserva tarefa, cronograma, caminho e modificações anteriores. |
| **PL-002** | **P0** | Edição de tarefa consistente | Validar campos antes de confirmar alterações; falha de duração/predecessora impede atualização parcial e exibe mensagem específica. |
| **PL-003** | **P0** | Persistência robusta | Salvar com arquivo temporário, substituição segura, esquema validado, backup/recuperação quando pertinente e teste de falha de escrita. |
| **PL-004** | **P0** | Modelo de tarefa P2 | Acrescentar ID persistente, status de execução/validação, aplicativo, entradas, saídas, parâmetros, diretório de trabalho, revisão, hash, avisos e histórico de retorno; serializar e migrar compatível com `.plan.json` antigo. |
| **PL-005** | **P0** | Contrato de despacho | Gerar pacote `.task.json` conforme o contrato em `docs/Planejador.md` e `docs/Integracoes.md`, com tarefa, entradas, dependências, parâmetros, versão e hashes. |
| **PL-006** | **P0** | Abrir no aplicativo | Localizar executável compatível por registro/configuração; lançar com argumentos explícitos e caminho seguro; informar indisponibilidade, erro ou cancelamento, sem marcar tarefa concluída. |
| **PL-007** | **P0** | Receber retorno | Ler e validar retorno da tarefa: arquivos, ID, revisão de entrada, hash das saídas, estado, avisos; rejeitar retorno incompatível e registrar rastreabilidade. |
| **PL-008** | **P0** | Liberação e atualização | Implementar estados `bloqueada/pronta/em execução/em revisão/concluída/falhou` (nomes ajustáveis); distinguir **vínculos de agendamento TI/II/TT/IT** das condições de liberação para entrega, evitando exigir o mesmo marco para todos os tipos. Conclusão exige política configurada e evidência de artefato válido. |
| **PL-009** | **P0** | Mudanças de origem | Comparar hash/revisão; quando insumo mudar, marcar tarefa e sucessoras dependentes como desatualizadas, sem apagar resultados; liberar reexecução após avaliação. |
| **PL-010** | **P0** | Testes P2 | Testes de contrato, despacho a aplicativo fictício, retorno válido/inválido, versão incompatível, dependência bloqueada, falha de processo, paths com espaços e encadeamento. |
| **PL-011** | **P0** | CI/portabilidade | Adicionar CI de compilação e testes no Windows e Linux, logs por módulo; teste de instalação limpa e execução em máquina sem fontes CHATGPT externos. |
| **PL-012** | **P1** | Interface P2 | Exibir colunas/abas Entradas, Saídas, Executar, Histórico e Pendências; mostrar estados reais e mensagens legíveis ao usuário. |
| **PL-013** | **P1** | Undo/redo e recuperação | Desfazer/refazer edição de tarefas, dependências e exclusões; proteger contra perda de alterações em erros e fechamento. |
| **PL-014** | **P1** | Recursos e equipes P3 | Cadastro de pessoas, equipes, máquinas e materiais; alocação, capacidade, disponibilidade, sobrecarga e nivelamento com registro da decisão. |
| **PL-015** | **P1** | Custos e orçamento P3 | Custos por hora/unidade, material, custo fixo e total planejado/real, com atualização por tarefa e recursos. |
| **PL-016** | **P1** | Linha de base P3 | Congelar versões do cronograma para comparar datas, custos e avanço planejado versus realizado; histórico de baselines. |
| **PL-017** | **P1** | Acompanhamento e gráficos P3 | Calendário mensal/semanal, Curva S física/financeira, progresso por tarefa, indicadores de atraso e previsão de término. O diagrama de rede já existe: evoluir, não recriar. |
| **PL-018** | **P1** | Relatórios | Exportar e imprimir Gantt, tarefas, vínculos, cronograma, recursos, custos e situação em PDF/CSV (escopo e bibliotecas a confirmar). |
| **PL-019** | **P1** | Intercâmbio gerencial | Considerar CSV e XML compatível com cronogramas de mercado (ex.: MSPDI) com relatório de campos não suportados; não prometer `.mpp` nativo sem conversor. |
| **PL-020** | **P2** | Tarefas de objetos P4 | Criar tarefas relacionadas a `object_id` da Maquete 3D, com origem/revisão, e anexar artefatos de objetos existentes. |
| **PL-021** | **P2** | Skins por objeto/face P4 | Vínculo versionado de `texture_id` por `object_id`/`face_id`, sem manipular geometria ou modificar a biblioteca da Maquete diretamente. |
| **PL-022** | **P2** | Acompanhamento de objetos P4 | Ao receber confirmação da Maquete, registrar vínculo aplicado/pendente/conflitante e manter histórico de revisões. |

## 4. Fragilidades específicas encontradas na leitura do código

### PL-001 — risco de perder o documento atual ao abrir um arquivo inválido

Em `plan_json.pas`, `PLProjetoDeJSON` chama `Doc.Novo(...)` **antes** de validar todas as tarefas/vínculos do JSON. Se uma entrada posterior falhar, o documento atual já foi alterado. Em `plan_principal.pas`, `AbrirArquivo` ainda chama `FDoc.Novo('Novo projeto', Date)` no `except`. Portanto, uma tentativa de abertura com erro pode substituir o conteúdo corrente; o comportamento é observável na lógica, embora não tenha sido reproduzido em execução. **Correção:** carregar em instância temporária, validar grafo e só então trocar o documento.

### PL-002 — potencial aplicação parcial de alterações

Em `plan_principal.pas`, `AoAplicarTarefa` pode editar `Nome`, `Aplicativo`, `Situação`, `Responsável`, `Notas` e `Progresso` mesmo quando a duração ou predecessor gera `Err`, seguido de `MarcarModificado`. **Correção:** validação transacional, commit somente se todos os campos forem válidos; testes cobrindo rollback.

### PL-003 — gravação sem estratégia explícita de substituição atômica

`PLSalvarProjeto` escreve diretamente no destino com `TStringList.SaveToFile`. Em interrupção, o arquivo anterior pode ser comprometido. **Correção:** gravar em arquivo temporário no mesmo diretório, confirmar escrita, substituir com tratamento de falhas e preservar recuperação.

### PL-008 — cronograma não equivale a workflow

`TPLSituacao` tem apenas `a fazer`, `em andamento` e `concluída`; `AoAplicarTarefa` permite escolher `concluída` e força progresso a 100% sem conferir se as entradas/saídas estão válidas. A validação de vínculo protege o **grafo**, não a liberação das entregas. **Correção:** modelar estado de execução e validação de artefato, não substituir simplesmente `Situacao` sem migração.

### PL-004 a PL-007 — falta modelo de integração

`TPLTarefa` contém `Id`, `Nome`, `Responsavel`, `Notas`, `Duracao`, `Marco`, `Aplicativo`, `Situacao`, `Progresso` e `Predecessoras`, mas ainda não contém entradas, saídas, parâmetros, hash/revisão ou retorno. `plan_json.pas` serializa o modelo básico. **Correção:** acrescentar classes/records para os artefatos e contratos e testar ida/volta JSON de versões antigas e novas.

## 5. Sequência de execução indicada

| Ciclo | Escopo | Critério de conclusão |
|---|---|---|
| **A — Proteger dados** | PL-001, PL-002, PL-003 | Abrir arquivo inválido e editar campo inválido não perde dados; salvar não destrói versão anterior em falha. |
| **B — Contrato de tarefas P2** | PL-004, PL-005, PL-007, PL-010 | Aplicativo simulado recebe tarefa e devolve artefato/resultado com IDs e hash validados. |
| **C — Fluxo P2 completo** | PL-006, PL-008, PL-009, PL-011, PL-012 | Planejador despacha tarefa, recebe retorno, libera sucessoras quando admissível, reage a revisão da origem. |
| **D — Gestão completa P3** | PL-013 a PL-019 | Recursos/custos, linha de base, Curva S, calendário e relatórios persistem e são comparáveis. |
| **E — Objetos/Skins P4** | PL-020 a PL-022 | Tarefa referencia objeto, textura e face; resposta da Maquete registra associação aplicada e revisão. |

**Sem bloqueio artificial:** o **contrato P2 pode ser testado com um aplicativo fictício** antes de CAD 2D estar pronto. A homologação ponta a ponta com CAD real ocorre quando o aplicativo estiver funcional; o Planejador não precisa aguardar todas as disciplinas para desenvolver seu próprio motor de tarefas.

## 6. Testes de aceitação novos

| Teste | Cenário e resultado |
|---|---|
| PL-AT-01 | Projeto com 20 tarefas, vínculos múltiplos e marcos: salvar/abrir preserva tudo, cronograma igual. |
| PL-AT-02 | Abrir JSON malformado/versão desconhecida: mensagem clara; projeto atual permanece idêntico. |
| PL-AT-03 | Editar nome e duração inválida simultaneamente: nenhuma alteração parcial é confirmada. |
| PL-AT-04 | Falha ao salvar (sem permissão/disco cheio simulado): preservar arquivo anterior e permitir recuperação. |
| PL-AT-05 | Tarefa `T-0012` envia `.task.json` a simulador de aplicativo com entradas, hash e revisão. |
| PL-AT-06 | Retorno com ID/hash incorreto ou saída ausente: rejeitado, nunca marcar concluída. |
| PL-AT-07 | Encadeamento de tarefas: uma bloqueada não é executada; ao completar entrega válida, a sucessora pode ser liberada conforme regra. |
| PL-AT-08 | Alterar insumo depois da conclusão: identificar desatualização sem apagar histórico nem resultado anterior. |
| PL-AT-09 | Recursos e baseline: tarefa atrasada altera previsão/Curva S, mas não a linha de base registrada. |
| PL-AT-10 | Tarefa de objeto/face: referências sobrevivem a salvar/abrir e retorno compatível da Maquete 3D. |
| PL-AT-11 | Build/teste em Windows e Linux a partir de checkout limpo, sem depender de pasta local do desenvolvedor. |
| PL-AT-12 | Instalar apenas Planejador: abre projeto, gerencia tarefas e informa claramente que aplicativo destino está indisponível. |

## 7. Limites e dependências

- Reaproveitar `AIProjectCore` e `AIProject` da biblioteca CHATGPT sem criar duas implementações divergentes de grafo/calendário/cronograma; preservar opção `third_party/chatgpt` para build reproduzível.
- **Não copiar o MultiCNC/MultiProject inteiro**, nem incluir seus executáveis no instalador.
- Planejador só transfere tarefas e referências; cada aplicativo permanece dono dos seus arquivos.
- Os formatos de troca devem seguir `docs/Integracoes.md` e `docs/Planejador.md`.
- Os testes de P4 com objeto/skin reais dependem da Maquete 3D; o contrato pode ser testado antes usando objetos fictícios com IDs fixos.
- Qualquer funcionalidade implementada deve atualizar documentação, estado dos testes e versão do Planejador antes de ser marcada como concluída.

## 8. Referências internas

- [Requisitos principais do Planejador](Planejador.md)
- [Contrato geral de integrações](Integracoes.md)
- [Plano de desenvolvimento](Plano_Desenvolvimento.md)
- [Auditoria geral](Auditoria_Lacunas_2026-10-30.md)
- [README do aplicativo](../planejador/README.md)

**Resumo:** priorizar **segurança de arquivos (PL-001 a PL-003)** e **P2 — despacho, retorno, liberação e revisão de tarefas (PL-004 a PL-012)**. Depois completar P3; P4 entra quando houver contratos de objetos/skins. Nenhum código foi alterado nesta revisão.
