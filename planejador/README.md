# Planejador

Gerenciador de projetos de engenharia e arquitetura, tendo o Microsoft Project como referência funcional. É a **primeira etapa da linha de produção**: cria as tarefas do empreendimento, define a ordem entre elas e acompanha sua execução nos demais aplicativos da plataforma.

> **Estado:** em especificação. Detalhamento completo na seção 19 da [especificação da plataforma](../docs/Especificacao_Plataforma_Arquitetura.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Retornos de tarefa (arquivo produzido, situação, alertas) de todos os aplicativos | Tarefas, cronograma, dependências e vínculos | CAD 2D, Maquete 3D, Criador de Cenas, Elétrica 3D, SimuEletrica |

O Planejador **não produz geometria** e não edita os arquivos dos outros aplicativos: ele referencia arquivos e recebe os retornos.

## Funcionalidades

### Tarefas
- Criação de tarefas com nome, descrição, duração, datas, responsáveis e situação.
- Encadeamento em grafo, em cadeia ou em paralelo, com dependências.
- Liberação automática de uma tarefa quando as anteriores estiverem concluídas.

### Tarefas arquitetônicas
- Cada tarefa pode ser vinculada ao aplicativo que a executa. Exemplo: "Planta do térreo" abre no CAD 2D; "Maquete da edificação" abre na Maquete 3D quando as plantas dos pavimentos estiverem concluídas.
- O Planejador entrega ao aplicativo os arquivos de entrada e os parâmetros e recebe de volta o arquivo produzido.

### Objetos e texturas
- Ao criar ou importar um objeto 3D, o Planejador pode criar tarefas para ele ou anexá-lo a tarefas existentes.
- Pelas tarefas, vincula texturas aos objetos; o vínculo é aplicado na Maquete 3D ao objeto inteiro ou a uma face dele.
- A textura continua sendo uma entidade independente da biblioteca; o objeto guarda a referência.

### Visões e gráficos (*proposta*)
| Visão | Uso |
|---|---|
| Gráfico de Gantt | Barras no tempo, dependências, marcos e caminho crítico |
| Diagrama de rede (PERT) | Grafo das tarefas, com cadeia e paralelismo |
| Calendário | Tarefas por dia, semana ou mês |
| Uso de recursos | Alocação de pessoas e equipamentos, com aviso de sobrecarga |
| Linha de base | Planejado comparado ao realizado |
| Curva S | Avanço físico ou financeiro acumulado da obra |

## Requisitos

| Faixa | Assunto |
|---|---|
| RFP-001 a RFP-003 | Projeto, tarefas e grafo de dependências |
| RFP-004 a RFP-007 | Tarefas executadas nos outros aplicativos e retorno |
| RFP-008 a RFP-009 | Tarefas de objetos e vínculo de texturas |
| RFP-010 | Cronograma e gráficos |

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
  "retorno": {"situacao": "concluida", "saidas": [], "alertas": []}
}
```

Tarefa de objeto com vínculo de textura:

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

1. Quando uma textura é alterada, os objetos vinculados acompanham a mudança ou mantêm a versão vinculada?
2. O Planejador também vincula texturas a paredes, pisos e lajes, ou apenas a objetos?
