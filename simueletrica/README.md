# SimuEletrica

Simulador de sistemas elétricos, proteção e análise térmica. Aplicativo independente que transforma o projeto do **Elétrica 3D** em um modelo computacional, simula o funcionamento da instalação, testa situações de falha e mostra os resultados nos cabos, equipamentos e circuitos da maquete.

> **Estado:** em especificação. Detalhamento na seção 18 da [especificação da plataforma](../docs/Especificacao_Plataforma_Arquitetura.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Pacote elétrico do Elétrica 3D; referência espacial da maquete | Cenários, resultados, alertas, gráficos, mapas térmicos e relatórios | Elétrica 3D e Maquete 3D (visualização opcional) |

O SimuEletrica **não modifica** o projeto elétrico original. Os resultados são estimativas dependentes das hipóteses e dos modelos escolhidos, e não laudos ou ensaios.

## Funcionalidades

| Área | Funcionalidades |
|---|---|
| Núcleo | Grafo elétrico (nós, ramos, fases, neutro, terra), fontes mono, bi e trifásicas ou CC, cargas por ponto |
| Regime permanente | Corrente, tensão, potências, fator de potência, perdas e queda de tensão |
| Falhas | Curtos fase-fase, fase-neutro e fase-terra; sobrecarga; perda de fase; neutro interrompido; mau contato |
| Proteção | Disjuntores, fusíveis, relés, contatores, dispositivos DR, seletividade e registro de eventos |
| RLC e qualidade | Transitórios, chaveamento de bobinas, partida de motores, harmônicos e desequilíbrio |
| Térmica | Perdas por efeito Joule, temperatura em regime e ao longo do tempo, pontos quentes em conexões |
| Mapa de calor 3D | Cor sobre cada trecho de cabo na maquete, com legenda em °C, corte de paredes e linha do tempo |
| Resultados | Cenários comparáveis, sondas virtuais, gráficos, relatórios PDF, CSV e JSON |

## Interface

- **Esquerda:** pavimentos, quadros, fontes, circuitos, dispositivos, cenários, sondas e avisos.
- **Centro:** abas Maquete Elétrica 3D, Diagrama Unifilar, Osciloscópio, Mapa de Calor e Comparação.
- **Direita:** propriedades e resultados do item selecionado.
- **Barra de simulação:** preparar, validar, iniciar, pausar, avançar, reiniciar e gerar relatório.

## Motores de cálculo

| Motor | Uso |
|---|---|
| OpenDSS | Redes, cargas, faltas, harmônicos e perfis temporais |
| ngspice | Relés, circuitos RLC e transitórios |
| Módulo térmico próprio | Aquecimento dos condutores, acoplado aos resultados elétricos |

Os motores rodam como processos ou bibliotecas isolados, orquestrados pela interface em Lazarus/Free Pascal. Interferência eletromagnética irradiada fica para fase posterior, com solucionador de campos específico.

## Requisitos

| Faixa | Assunto |
|---|---|
| SIM-001 a SIM-010 | Núcleo, fontes, cargas e regime permanente |
| SIM-011 a SIM-020 | Falhas, proteção e eventos |
| SIM-021 a SIM-027 | Capacitância, indutância, harmônicos e interferências |
| SIM-028 a SIM-038 | Aquecimento e mapa térmico |
| SIM-039 a SIM-048 | Cenários, painéis, relatórios e biblioteca de dispositivos |
| RNF-SIM-01 a RNF-SIM-08 | Requisitos não funcionais específicos |

## Entregas

| Entrega | Escopo |
|---|---|
| S1 — Núcleo | Importação, grafo, fontes, cargas e cálculo em regime permanente |
| S2 — Proteção | Sobrecarga, faltas, disjuntores, fusíveis e relés |
| S3 — Térmica | Modelo térmico e mapa de calor 3D |
| S4 — Qualidade | RLC, chaveamento e harmônicos |
| S5 — Avançado | Interferência detalhada, campos 3D e cenários em lote |

## Normas de referência

ABNT NBR 5410, NR-10, IEC 60909-0 (curto-circuito), IEC 60287-1-1 (capacidade e perdas em cabos) e IEC 60255-1 (relés e proteção), conforme aplicabilidade.

> A simulação é ferramenta de estudo e dimensionamento assistido. Não valida, por si só, segurança contra choque, incêndio ou arco elétrico, nem substitui ensaios, inspeções ou a responsabilidade técnica.
