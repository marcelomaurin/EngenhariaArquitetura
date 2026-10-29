# Planejador

| Campo | Valor |
|---|---|
| Tipo | Aplicativo independente |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Etapa P1 implementada em 29/10/2026; etapas P2 a P4 em especificação |
| Papel na linha de produção | Primeira etapa: cria, encadeia e acompanha as tarefas executadas em todos os aplicativos |
| Recebe | Retornos de tarefa (arquivo produzido, situação, alertas) |
| Produz | Tarefas, cronograma, dependências e vínculos objeto–textura |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

> **Origem desta seção:** consolidada a partir das definições passadas durante a concepção (28/10/2026). Itens marcados como *proposta* foram sugeridos durante a conversa e ainda dependem de confirmação.

## Descrição

O **Planejador** é a primeira etapa da linha de produção. Funciona como um gerenciador de projetos no estilo do Microsoft Project, voltado a empreendimentos de engenharia e arquitetura. Cada aplicativo da plataforma é uma etapa da linha; o Planejador cria as tarefas, define a ordem entre elas e acompanha sua execução. Ele **cria tarefas arquitetônicas que são executadas nos demais aplicativos**: por exemplo, a tarefa "Planta do térreo" abre no CAD 2D e a tarefa "Maquete da edificação" abre na Maquete 3D quando as plantas dos pavimentos estiverem concluídas.

## Requisitos funcionais

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RFP-001 | Essencial | Criar, abrir, salvar e versionar projetos de planejamento do empreendimento. |
| RFP-002 | Essencial | Criar tarefas com nome, descrição, duração, datas, responsáveis e situação. |
| RFP-003 | Essencial | Encadear tarefas em grafo, em cadeia ou em paralelo, com dependências entre elas. |
| RFP-004 | Essencial | Criar **tarefas arquitetônicas** vinculadas ao aplicativo que as executa (CAD 2D, Maquete 3D, Criador de Cenas, Elétrica 3D, SimuEletrica, SimuTubulações). |
| RFP-005 | Essencial | Abrir a tarefa no aplicativo responsável, entregando arquivos de entrada e parâmetros. |
| RFP-006 | Essencial | Receber de volta o arquivo produzido, a situação da tarefa e eventuais pendências ou alertas. |
| RFP-007 | Essencial | Liberar uma tarefa somente quando as tarefas de que depende estiverem concluídas. |
| RFP-008 | Essencial | Ao criar ou importar um objeto 3D, criar tarefas para ele ou anexá-lo a tarefas existentes. |
| RFP-009 | Essencial | Vincular texturas aos objetos por meio das tarefas; o vínculo é aplicado na Maquete 3D ao objeto inteiro ou a uma face dele. |
| RFP-010 | Essencial | Oferecer visão de cronograma e os gráficos usados comumente no Microsoft Project (ver 19.3). |

## Visões e gráficos (*proposta*)

- **Gráfico de Gantt:** barras no tempo, dependências, marcos e caminho crítico destacado.
- **Diagrama de rede (estilo PERT):** o grafo das tarefas, mostrando cadeia e paralelismo.
- **Calendário:** tarefas por dia, semana ou mês.
- **Uso de recursos:** alocação de pessoas e equipamentos, com aviso de sobrecarga.
- **Linha de base:** comparação entre o planejado e o realizado.
- **Curva S:** avanço físico ou financeiro acumulado, usual no acompanhamento de obras.

## Regras

- O Planejador não produz geometria nem edita os arquivos dos demais aplicativos; ele referencia arquivos e recebe retornos.
- A textura vinculada continua sendo uma entidade independente da biblioteca ([Gerador de Texturas](Gerador_Texturas.md)); o objeto guarda a referência à textura e o destino da aplicação (objeto ou face).
- Cada tarefa registra o aplicativo responsável, a versão dos arquivos de entrada e de saída e o histórico de situações.

## Contrato de tarefa (*proposta*)

```json
{
  "schema_version": "1.0",
  "task_id": "T-0012",
  "nome": "Planta do térreo",
  "aplicativo": "CAD2D",
  "depende_de": ["T-0010"],
  "entradas": [{"arquivo": "levantamento.dxf", "hash": "..."}],
  "parametros": {"pavimento": "terreo", "escala": "1:50"},
  "prazo": "2026-11-15",
  "retorno": {
    "situacao": "concluida",
    "saidas": [{"arquivo": "terreo.plan.json", "hash": "..."}],
    "alertas": []
  }
}
```

Exemplo de tarefa de objeto com vínculo de textura:

```json
{
  "task_id": "T-0031",
  "nome": "Acabamento da bancada da recepção",
  "aplicativo": "Maquete3D",
  "objeto": "bancada_recepcao_001",
  "texturas": [
    {"textura_id": "granito_cinza", "destino": "face", "face_id": "tampo"},
    {"textura_id": "mdf_branco", "destino": "objeto"}
  ]
}
```

## Questões em aberto

1. Quando uma textura da biblioteca é alterada, os objetos vinculados acompanham a mudança automaticamente ou mantêm a versão vinculada até atualização explícita?
2. O Planejador também vincula texturas às superfícies arquitetônicas geradas pela Maquete (paredes, pisos, lajes), ou apenas aos objetos?
3. Os aplicativos da plataforma reaproveitarão componentes da suíte CHATGPT (Lazarus/FPC), como ocorre no MultiCNC?

## Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| P1 — Tarefas e grafo | Projeto, tarefas, dependências em cadeia e paralelo, Gráfico de Gantt | RFP-001 a RFP-003, RFP-010 (Gantt) | Criar 20 tarefas com dependências, ver caminho crítico, salvar e reabrir |
| P2 — Tarefas nos aplicativos | Contrato de tarefa, abertura no aplicativo responsável, retorno e liberação automática | RFP-004 a RFP-007 | Tarefa "Planta do térreo" abre no CAD 2D e volta concluída com o arquivo produzido |
| P3 — Visões de acompanhamento | Diagrama de rede, calendário, uso de recursos, linha de base e curva S | RFP-010 | Comparar planejado e realizado de um cronograma de obra |
| P4 — Objetos e texturas | Tarefas de objetos e vínculo de texturas por objeto ou face | RFP-008, RFP-009 | Vincular duas texturas a uma bancada (tampo e corpo) e ver o resultado na Maquete 3D |

**Situação:** P1 concluída em 29/10/2026 (código em `planejador/`), usando o grafo, o calendário, o caminho crítico e o Gantt da suíte CHATGPT. Foi antecipada em relação à ordem do plano, que previa o CAD 2D antes. Na versão 0.2 entraram os vínculos no padrão do MultiProject (Ctrl+F2, painel Vínculos, Ctrl+Shift+F2) e o **diagrama de rede da etapa P3**, com arrastar para ligar; 52 verificações automatizadas.

**Dependências:** P2 exige o contrato de tarefa do [documento de integrações](Integracoes.md) e ao menos o CAD 2D na etapa 1; P4 exige a Maquete 3D com o Editor de Objetos e o Gerador de Texturas.
