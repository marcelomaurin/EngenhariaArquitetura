# SimuEletrica

| Campo | Valor |
|---|---|
| Tipo | Aplicativo independente, vinculado ao Elétrica 3D |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Sexta etapa: simulação elétrica, falhas, proteções e análise térmica do projeto elétrico |
| Recebe | Pacote elétrico do Elétrica 3D; referência espacial da maquete |
| Produz | Cenários, resultados, eventos, gráficos, mapas térmicos 3D e relatórios, sem alterar o projeto elétrico |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## Visão resumida

Importa a topologia e os parâmetros elétricos definidos no Elétrica 3D e a referência espacial da maquete para simular regimes de operação, cargas e falhas, atuação de proteções, efeitos resistivos/indutivos/capacitivos, aquecimento dos condutores e mapas térmicos 3D. **Não é incorporado ao Elétrica 3D** e não deve modificar automaticamente o projeto elétrico original. Seus resultados são estimativas dependentes das hipóteses e modelos selecionados, não laudos de segurança ou ensaios físicos.

## Descrição do projeto

**Nome:** SimuEletrica — Simulador de Instalações e Sistemas Elétricos 3D.  
**Objetivo:** receber os dados arquitetônicos e principalmente os dados de circuitos e componentes publicados pelo **Elétrica 3D**, construir um modelo matemático verificável, aplicar cenários de operação e falha, exibir grandezas elétricas e térmicas na rede e sobre as rotas de cabos na maquete.  
**Natureza:** software independente com executável, instalador, configurações, projeto nativo e relatórios próprios. O Elétrica 3D, a Maquete 3D e o MultiCNC **não integram seu instalador**. A abertura do pacote elétrico deve ser suficiente para operar offline, desde que dados e geometrias necessários acompanhem a exportação.

## Requisitos funcionais — núcleo e carga

| ID | Prioridade | Descrição verificável |
|---|---|---|
| SIM-001 | Essencial | Abrir pacote de instalação elétrica exportado pelo Elétrica 3D, sem exigir que o programa de origem esteja aberto ou instalado. |
| SIM-002 | Essencial | Validar referências de versão, unidades, revisões, identificadores únicos e integridade do arquivo de entrada. |
| SIM-003 | Essencial | Transformar circuitos físicos em grafo de nós, ramos, fontes, retornos, fases, neutro, proteção e terra, com rastreabilidade ao objeto 3D. |
| SIM-004 | Essencial | Exibir grafo/unifilar e maquete 3D sincronizados por seleção de equipamentos e segmentos. |
| SIM-005 | Essencial | Definir fonte monofásica, bifásica, trifásica ou CC, com tensão, frequência, impedância de fonte e limites fornecidos pelo usuário. |
| SIM-006 | Essencial | Atribuir cargas a tomadas, iluminação, máquinas e pontos; potência nominal, potência reativa/fator de potência, perfil temporal e modelo elétrico. |
| SIM-007 | Essencial | Executar regime permanente e calcular tensão, corrente, potência ativa/reativa/aparente, fator de potência e perdas. |
| SIM-008 | Essencial | Calcular queda de tensão por trecho/circuito, comprimento e propriedades do condutor, reportando premissas e método. |
| SIM-009 | Essencial | Exibir resultados por circuito, fase, nó, tomada, quadro, equipamento e caminho de cabo. |
| SIM-010 | Essencial | Salvar cenários independentes e compará-los sem sobrescrever o projeto elétrico original. |

## Requisitos funcionais — falhas e proteção

| ID | Prioridade | Descrição verificável |
|---|---|---|
| SIM-011 | Essencial | Simular sobrecarga e indicar corrente calculada, capacidade admissível estimada e margem por circuito. |
| SIM-012 | Essencial | Injetar curto-circuito entre fases, fase-neutro e fase-terra em nós/trechos selecionados com impedância de falta configurável. |
| SIM-013 | Essencial | Calcular correntes de falta mínima/máxima conforme o método e os dados disponíveis; sinalizar topologias fora do modelo escolhido. |
| SIM-014 | Essencial | Simular disjuntores e fusíveis usando curvas tempo-corrente disponíveis e documentadas. |
| SIM-015 | Essencial | Modelar relés de comando e proteção, contatores, bobinas, contatos NA/NF, temporização e lógica de acionamento. |
| SIM-016 | Importante | Avaliar sequências de atuação, tempos estimados, seletividade e coordenação entre proteções com curvas e ajustes adequados. |
| SIM-017 | Importante | Incluir dispositivos DR e condições de fuga à terra mediante modelos apropriados, sem supor proteção garantida apenas pela simulação. |
| SIM-018 | Importante | Simular perda de fase, neutro interrompido, conexão de alta resistência, mau contato e circuito aberto. |
| SIM-019 | Importante | Simular partidas de motores e mudanças abruptas de carga com modelos de demanda e corrente transitória. |
| SIM-020 | Essencial | Registrar eventos temporais: injeção de falha, corrente de pico calculada, disparo, abertura de contatos, restabelecimento e alertas. |

## Requisitos funcionais — capacitância, indutância e interferências

| ID | Prioridade | Descrição verificável |
|---|---|---|
| SIM-021 | Importante | Representar resistências, indutâncias e capacitâncias concentradas ou distribuídas equivalentes por trecho, com parâmetros conhecidos ou estimados. |
| SIM-022 | Importante | Executar análises de transitórios RLC, ligação/desligamento de bobinas, surtos simplificados e comportamento temporal de relés. |
| SIM-023 | Importante | Executar análise em frequência e resposta a componentes harmônicas para circuitos suportados pelo solver. |
| SIM-024 | Importante | Avaliar distorção harmônica, desequilíbrio de fases e variações de tensão com modelos e perfis apropriados. |
| SIM-025 | Futuro | Simular acoplamento elétrico/magnético entre condutores e caminhos com parâmetros extraídos ou informados. |
| SIM-026 | Futuro | Integrar solver especializado de compatibilidade eletromagnética/campos 3D para EMI irradiada, quando disponível. |
| SIM-027 | Essencial | Diferenciar visualmente resultados medidos, resultados simulados, hipóteses e valores não disponíveis. |

**Limite técnico:** análise de harmônicos e acoplamento elétrico conduzido pode ser obtida por modelos de rede/RLC. Interferência eletromagnética **irradiada** e campos espaciais detalhados **não são determinados apenas pela planta 3D e pelo comprimento dos fios**; exigem modelos específicos de frequência, materiais, geometria de condutores e solvers de campo eletromagnético. Não anunciar precisão de EMI radiada sem validação do solver e medições de referência.

## Requisitos funcionais — aquecimento e mapa térmico

| ID | Prioridade | Descrição verificável |
|---|---|---|
| SIM-028 | Essencial | Calcular perdas Joule nos condutores por segmento a partir de corrente e resistência dependente da temperatura, com método e unidades explícitos. |
| SIM-029 | Essencial | Considerar seção, material, comprimento, número de condutores carregados, tipo de isolamento, método de instalação, agrupamento e temperatura ambiente. |
| SIM-030 | Essencial | Estimar temperatura em regime permanente com modelo térmico validado e propriedades conhecidas; sinalizar quando entradas forem insuficientes. |
| SIM-031 | Importante | Estimar evolução temporal de temperatura com rede térmica RC ou outro modelo transiente documentado. |
| SIM-032 | Essencial | Exibir mapa de calor 3D **sobre cada trecho de cabo e sua rota**, usando temperatura calculada e escala de cores com legenda numérica em °C. |
| SIM-033 | Essencial | Permitir corte da parede/shaft, ocultação de superfícies e isolamento por circuito para visualizar segmentos embutidos. |
| SIM-034 | Essencial | Selecionar cabo/trecho e consultar temperatura estimada, corrente, perdas W/m, limite aplicável, instante e grau de confiança/limitações do modelo. |
| SIM-035 | Importante | Mostrar evolução do mapa térmico ao longo de uma linha do tempo, com play/pause, avanço e seleção de instante. |
| SIM-036 | Importante | Identificar possíveis pontos quentes em emendas, conexões e bornes quando o usuário fornecer resistência de contato ou outro modelo apropriado. |
| SIM-037 | Essencial | Sinalizar ultrapassagem de limites de projeto, sem simular combustão ou temperaturas sem dados suficientes. |
| SIM-038 | Importante | Comparar cenários com diferentes bitolas, cargas, agrupamentos, isolamento e condições ambientais, sem modificar o projeto elétrico original. |

**Método:** perdas resistivas e temperatura do condutor não são iguais à temperatura visual da parede. A exibição 3D deve especificar se a cor corresponde ao **condutor**, à **isolação**, à **superfície do eletroduto** ou a uma **estimativa superficial**. Utilizar parâmetros e metodologia documentados; não inferir uma temperatura absoluta apenas de `I²R` sem condições térmicas de contorno. O padrão de avaliação de capacidade e perdas em regime permanente pode se apoiar na família **IEC 60287**, conforme sua aplicabilidade.

## Requisitos funcionais — ferramentas e resultados

| ID | Prioridade | Descrição verificável |
|---|---|---|
| SIM-039 | Essencial | Criar cenários denominados: operação normal, carga máxima, pico simultâneo, falha selecionada e variação de temperatura ambiente. |
| SIM-040 | Essencial | Disponibilizar painéis de resultados por circuito/pavimento/trecho, com filtros de severidade e busca. |
| SIM-041 | Importante | Exibir gráficos de corrente, tensão, potência, temperatura e atuação dos dispositivos no tempo. |
| SIM-042 | Importante | Permitir sondas virtuais em pontos ou trechos selecionados no modelo 3D ou unifilar. |
| SIM-043 | Essencial | Exportar relatórios PDF/CSV/JSON com parâmetros, limites, eventos, resultados, unidades e revisão de origem. |
| SIM-044 | Essencial | Apresentar lista de advertências: dados faltantes, modelo não convergente, resultado fora do domínio de validação, referência rompida. |
| SIM-045 | Essencial | Preservar resultados reproduzíveis com versão do modelo, parâmetros, pacote de entrada e motor de cálculo. |
| SIM-046 | Importante | Exportar camada opcional de resultados para visualização no Elétrica 3D/Maquete 3D sem alterar sua fonte elétrica. |
| SIM-047 | Importante | Oferecer modelo de dispositivo editável e biblioteca de relés/proteções com curvas reais quando licenciadas/disponíveis. |
| SIM-048 | Futuro | Permitir automação em lote de centenas de cenários e comparação estatística de risco operacional. |

## Interface mínima do SimuEletrica

- **Menu Arquivo:** abrir projeto, importar elétrica, salvar cenário, exportar resultados.
- **Painel esquerdo:** pavimentos, quadros, fontes, circuitos, dispositivos, cenários, sondas e avisos.
- **Área central:** abas **Maquete Elétrica 3D**, **Diagrama Elétrico/Unifilar**, **Osciloscópio**, **Mapa de Calor** e **Comparação**.
- **Painel direito:** propriedades da carga/proteção/condutor e resultados do ponto selecionado.
- **Barra inferior:** estado do solver, instante, convergência, faltas ativas, modo de análise e precisão/validade do cálculo.
- **Barra de simulação:** preparar, validar entrada, iniciar, pausar, avançar instante, reiniciar e gerar relatório.
- **Cores do mapa:** escala configurável com legenda numérica. Nunca usar cor isoladamente para indicar risco; apresentar unidade, limite e rótulo.

## Modelo de dados e intercâmbio

Contrato de arquivo lógico `simuelectrica-scenario.json` no pacote próprio de simulação; extensão definitiva a homologar. Exemplo conceitual (IDs e valores não representam instalação aprovada):

```json
{
  "schema_version": "1.0",
  "application": "SimuEletrica",
  "project_id": "sim-001",
  "electrical_ref": {
    "project_id": "eletrica-001",
    "revision": "rev-011",
    "hash": "sha256-do-pacote-eletrico"
  },
  "architecture_ref": {"project_id": "maquete-001", "revision": "rev-008"},
  "units": {"length": "mm", "voltage": "V", "current": "A", "temperature": "degC"},
  "simulation": {
    "scenario_id": "carga-maxima",
    "analysis": "steady_state_and_thermal",
    "supply": {"type": "AC_single_phase", "voltage_v": 127, "frequency_hz": 60},
    "load_overrides": [{"object_id": "tomada-101", "power_w": 1500, "power_factor": 1.0}],
    "ambient_temperature_c": 30
  },
  "results": {
    "status": "not_computed",
    "segment_results": []
  }
}
```

**Responsabilidades dos dados:** Elétrica 3D disponibiliza conectividade, rotas físicas, tipo de condutor, seção, isolamento, proteções, cargas e identificadores; SimuEletrica adiciona cenários, parâmetros de modelo e resultados; Maquete 3D fornece referência geométrica para posicionamento. O resultado jamais se faz passar por medição real.

## Motores de simulação — alternativas técnicas

- **Análise de rede e falhas:** motor de fluxo de potência em rede de baixa tensão, com implementação própria verificada ou integração como serviço isolado com **OpenDSS** para estudos de rede, faltas, harmônicos e perfis temporais. Validar adequação às topologias internas de edifícios e às proteções específicas.
- **Relés, circuitos RLC e transitórios:** integrar **ngspice** por API/processo ou outro solver de circuito validado. Modelos e licenças serão avaliados antes da distribuição.
- **Aquecimento e capacidade de cabo:** implementar solver térmico específico com tabelas técnicas e resistência térmica, permitindo evolução de temperatura e correções de agrupamento/instalação. Em fase avançada, avaliar acoplamento com malha térmica/FEA.
- **EMI tridimensional:** manter para fase posterior com solver de campos eletromagnéticos apropriado e ensaios de verificação.
- **Interface:** Lazarus/Free Pascal pode hospedar visualizador, UI e orquestração; solvers podem executar como processos ou bibliotecas multiplataforma isoladas. Desempenho e licença deverão ser homologados para Windows e Linux.

## Requisitos não funcionais específicos

| ID | Descrição |
|---|---|
| RNF-SIM-01 | Nunca aplicar tensão elétrica física nem enviar comandos a hardware durante a simulação; ambiente virtual por padrão. |
| RNF-SIM-02 | Isolar falhas do solver; timeout/cancelamento não corrompem o projeto elétrico importado. |
| RNF-SIM-03 | Manter versão de algoritmo, parâmetros, dados de fabricante e hipóteses acessíveis em cada relatório. |
| RNF-SIM-04 | Validar resultados contra casos de referência, cálculos independentes e exemplos técnicos revisados. |
| RNF-SIM-05 | Distinguir cálculos de regime permanente, transitórios e mapas térmicos; apresentar avisos de aplicabilidade. |
| RNF-SIM-06 | Não informar conformidade ABNT, capacidade de proteção contra choque ou ausência de risco apenas com base em simulação. |
| RNF-SIM-07 | Preservar IDs dos cabos e circuitos na exportação para sobreposição na Maquete 3D. |
| RNF-SIM-08 | Abrir e calcular offline com pacote autocontido, sem exigir execução dos outros aplicativos. |

## Testes de aceitação específicos

1. Abrir pacote do Elétrica 3D com dois pavimentos, quadro, circuitos, tomadas, lâmpadas e rotas completas, sem ter os outros programas instalados.
2. Aplicar duas cargas em um circuito conhecido e conferir corrente/potência/queda de tensão contra cálculo independente, usando tolerância definida no plano de testes.
3. Injetar curto fase-neutro com impedância declarada; comparar corrente e tempo estimado de proteção contra caso de referência consistente com o método adotado.
4. Simular sobrecarga e verificar indicação por circuito sem falsamente considerar o disparo instantâneo em dispositivo com curva temporizada.
5. Incluir relé comandando bobina e contato NA/NF; validar transições e registro temporal.
6. Simular circuito RLC simples; conferir a resposta transitória contra solução analítica conhecida ou caso de referência do solver.
7. Atribuir cabos de seção e material definidos, carga constante e ambiente conhecido; gerar mapa térmico com legenda de °C, indicação de condutor/superfície e método.
8. Alterar uma conexão com resistência de contato explicitamente definida e verificar a variação térmica local estimada.
9. Selecionar cabo na maquete e obter exatamente o mesmo identificador e resultados do diagrama e do relatório.
10. Alterar a versão do projeto elétrico de origem: o SimuEletrica deve detectar a divergência e oferecer revisão sem alterar o cenário anterior.
11. Exportar relatório contendo entradas, versões, limitações, avisos, séries temporais e referências de validação.
12. Com dados térmicos ou de fonte insuficientes, apresentar erro/intervalo de incerteza em vez de temperatura absoluta ou corrente de curto fictícia.

## Etapas de desenvolvimento (plano de entregas)

| Entrega | Escopo | Aceite |
|---|---|---|
| S1 — Núcleo | Importação, grafo, fontes, cargas e cálculo estacionário | Tensões/correntes/perdas conferidas contra casos conhecidos |
| S2 — Proteção | Sobrecarga, faltas, disjuntor, fusível e relés | Curvas e eventos reproduzíveis por cenário |
| S3 — Térmica | Resistência dependente de temperatura, modelo térmico e mapa 3D | Valores rastreáveis, legenda e alertas calibrados |
| S4 — Qualidade | RLC, chaveamento, harmônicos e análise de resposta temporal | Casos referência por solver e tipo de estudo |
| S5 — Avançado | EMI conduzida detalhada, campos 3D, automação de cenários | Dependente de solver e dados físicos homologados |

**Dependências:** a etapa S1 exige o Elétrica 3D na etapa E3 e o pacote elétrico definido no [documento de integrações](Integracoes.md); a decisão sobre uso do OpenDSS e do ngspice (licenças e forma de integração) é necessária antes de S1 e S4.

## Normas e responsabilidade técnica

- **ABNT NBR 5410:2004 (versão corrigida 2008)** — referência nacional de projeto e verificação de instalações elétricas de baixa tensão (conferir edição aplicável na data do projeto).
- **NR-10 (Brasil)** — segurança em instalações e serviços em eletricidade; simulação não substitui procedimentos, ensaios ou responsabilidades técnicas.
- **IEC 60909-0:2026** — método de cálculo de correntes de curto-circuito em redes trifásicas CA dentro de seu escopo. Não aplicar indiscriminadamente a circuitos DC e todas as falhas.
- **IEC 60287-1-1:2023** — corrente admissível e perdas em cabos sob condições de regime permanente dentro de seu escopo.
- **IEC 60255-1:2022** — referência para equipamentos de medição, relés e proteção.

**Segurança:** o software é para **estudo, dimensionamento assistido, análise e comparação de cenários**. Simulação não valida por si só segurança contra choque, incêndio, arco elétrico ou atendimento normativo. Projetos e intervenções reais exigem responsável técnico, verificação e ensaios correspondentes.

## Referências técnicas

- ABNT catálogo NBR 5410: https://www.abntcatalogo.com.br/
- NR-10 Ministério do Trabalho: https://www.gov.br/trabalho-e-emprego/pt-br/acesso-a-informacao/participacao-social/conselhos-e-orgaos-colegiados/comissao-tripartite-partitaria-permanente/normas-regulamentadora/normas-regulamentadoras-vigentes/norma-regulamentadora-no-10-nr-10
- IEC 60909-0:2026: https://webstore.iec.ch/en/publication/68454
- IEC 60287-1-1:2023: https://webstore.iec.ch/en/publication/68118
- IEC 60255-1:2022: https://webstore.iec.ch/en/publication/59762
- EPRI OpenDSS: https://opendss.epri.com/
- ngspice: https://ngspice.sourceforge.io/docs/ngspice-manual.pdf
