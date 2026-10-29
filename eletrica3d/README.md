# Elétrica 3D

Aplicativo independente para o **projeto das instalações elétricas** usando a maquete 3D como referência. **Não é um plugin da Maquete 3D**: tem instalador, executável, arquivos e versões próprios.

> **Estado:** em especificação. Especificação completa e etapas de desenvolvimento em [docs/Eletrica_3D.md](../docs/Eletrica_3D.md); integrações em [docs/Integracoes.md](../docs/Integracoes.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Maquete 3D (somente leitura) | Projeto elétrico, camada elétrica vinculada, diagramas, quantitativos e relatórios | Maquete 3D (sobreposição), Criador de Cenas (iluminação), SimuEletrica (simulação) |

## Funcionalidades

### Elementos
- Tomadas, interruptores, luminárias e pontos de luz, quadros de distribuição e caixas de passagem.
- Eletrodutos, eletrocalhas, leitos e perfilados em rotas 3D, com diâmetro, material e instalação aparente ou embutida.
- Cabos com identificação, seção, material, isolação, função e circuito.

### Projeto
- Visualização interna de paredes e lajes, com corte e isolamento de pavimentos.
- Agrupamento em circuitos, com identificação do quadro de origem.
- Cálculo do comprimento dos cabos pelas rotas, com margens parametrizadas.
- Verificação de interferências com lajes, vigas, portas e outras disciplinas.
- Diagramas unifilares, quantitativos e relatórios em CSV e PDF.
- Verificações configuráveis com base na ABNT NBR 5410, sem declaração automática de conformidade.

### Integração com a arquitetura
- Cada elemento fica preso à parede, superfície ou ambiente por **âncora persistente** (identificador da parede, distância ao longo dela, altura e face).
- Ao receber nova versão da maquete, compara as mudanças e sinaliza os itens afetados, **sem apagar** instalações automaticamente.
- O elétrico **não altera** paredes, lajes, portas e janelas. Rasgos, furos e aberturas geram **solicitações de coordenação** para aprovação na Maquete.

## Interface

- **Esquerda:** pavimentos, quadros, circuitos e grupos.
- **Centro:** maquete com navegação 3D, modo corte e vista superior.
- **Direita:** propriedades do elemento selecionado.
- **Rodapé:** unidades, comprimento da rota, circuito, advertências e revisão da maquete.
- **Fluxo:** abrir maquete → definir quadros → inserir pontos → criar eletrodutos → passar cabos → revisar interferências → quantificar → publicar camada elétrica.

## Requisitos

| Faixa | Assunto |
|---|---|
| RFE-001 a RFE-004 | Projeto próprio e maquete em referência |
| RFE-005 a RFE-013 | Pontos, quadros, eletrodutos, cabos e circuitos |
| RFE-014 a RFE-018 | Comprimentos, âncoras, exportação e revisões |
| RFE-019 a RFE-028 | Interferências, roteamento, cargas, diagramas, quantitativos e verificações |
| RFE-029 a RFE-030 | Intercâmbio IFC e relações com o Criador de Cenas |

## Intercâmbio

O IFC tem entidades próprias para instalações elétricas (tomadas, interruptores, luminárias, quadros, segmentos de cabo e eletroduto), o que dá ao Elétrica 3D um formato aberto de exportação a homologar.

## Entregas

| Entrega | Conteúdo |
|---|---|
| I | Pontos, quadros, eletrodutos e cabos |
| J | Circuitos, quantitativos, diagramas e conflitos |
| K | Coordenação com a Maquete 3D |
| L | Estados de iluminação para o Criador de Cenas |

## Critérios de aceite (resumo)

- Instalar sem a Maquete 3D e abrir um pacote arquitetônico válido.
- Importar maquete de dois pavimentos preservando escala e coordenadas.
- Inserir pontos ancorados em paredes, traçar eletrodutos e cabos e calcular quantitativos.
- Exportar a camada elétrica e abri-la sobreposta na Maquete 3D.
- Mover uma parede, reimportar e exigir confirmação antes de reposicionar elementos.

> Os cálculos e alertas são assistivos e não substituem projeto, responsabilidade técnica ou inspeção por profissional habilitado.
