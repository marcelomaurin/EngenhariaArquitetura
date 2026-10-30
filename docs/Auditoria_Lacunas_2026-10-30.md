# Auditoria de lacunas e plano de implementação — EngenhariaArquitetura

**Data:** 30/10/2026  
**Repositório:** `marcelomaurin/EngenhariaArquitetura`, branch `fila`  
**Base inspecionada:** commit `a60c70437f` (29/10/2026); estrutura de diretórios, READMEs, documentos de `docs/`, fontes e testes presentes no repositório.  
**Estado deste documento:** diagnóstico de lacunas de implementação e propostas de priorização; **não** significa que os recursos abaixo tenham sido implementados, compilados ou homologados.  
**Referência de organização:** MultiCNC/MultiSuite (separação de responsabilidades, componentes comuns, integração por arquivos, UI consistente, testes e empacotamento). **O MultiCNC não faz parte deste projeto nem de seus instaladores.** A compatibilidade de peças limita-se a arquivos exportados (STL/3MF).

## 1. Conclusão executiva

A lacuna principal da **EngenhariaArquitetura** é operacionalizar os contratos já especificados e entregar uma cadeia mínima testável **planta 2D → maquete 3D → disciplinas e cenas**, antes de ampliar o escopo. Não é necessário incorporar o MultiCNC nem criar vários programas extras neste momento.

O repositório documenta **sete aplicativos independentes**: Planejador, CAD Arquitetônico 2D, Maquete 3D, Criador de Cenas, Elétrica 3D, SimuEletrica e SimuTubulações. O Editor de Objetos 3D e o Gerador de Texturas são **módulos internos da Maquete 3D**. A integração entre programas deve ocorrer **somente por pacotes/arquivos versionados**, com IDs estáveis, origem, unidades e revisão.

**Constatação:** o Planejador tem implementação inicial e `bin/planejador.exe`, exemplos e testes; os seis outros aplicativos possuem especificações e README, mas não apresentam árvores de código de aplicação comparáveis na revisão consultada. Não há diretório `.github/workflows` no repositório e, portanto, não se encontrou CI de GitHub Actions configurado nesta revisão. **Não foram executados builds ou testes nesta auditoria**; registros de implementação foram confrontados com presença de arquivos, não com prova de execução atual.

## 2. Situação observada por aplicativo

| Componente | Situação observada | Próxima entrega concreta |
|---|---|---|
| **Planejador** | Fontes Lazarus em `planejador/src`; testes em `planejador/tests`; exemplo, Gantt, diagrama de rede e binário Win64 documentados; P1 antecipada. | **P2:** abrir tarefa no aplicativo designado, entregar parâmetros/artefatos e receber retorno verificável; depois P3/P4. |
| **CAD Arquitetônico 2D** | Especificação em `docs/CAD_Arquitetonico_2D.md`; README sem aplicativo implementado. | Canvas 2D com coordenadas exatas, seleção, layers, persistência; depois paredes, aberturas, cotas, ambientes e DXF. |
| **Maquete 3D** | Especificação em `docs/Maquete_3D.md` e módulos Editor/Skins documentados. | Reconstruir pavimentos de uma planta/duas plantas 2D e manter vínculos em atualizações. |
| **Criador de Cenas** | Especificado, sem executável identificado. | Importar maquete completa e renderizar imagem com câmera/luzes/materiais; animação após esse marco. |
| **Elétrica 3D** | Especificado como aplicativo independente, não plugin. | Editar, persistir e exportar circuitos/cabos/eletrodutos sobre referência arquitetônica. |
| **SimuEletrica** | Especificado, sem solver integrado identificado. | Importar modelo elétrico, executar caso analítico simples e apresentar resultados rastreáveis; falhas/térmica depois. |
| **SimuTubulações** | Especificado como editor e simulador no mesmo executável. | Editar rede, validar topologia e resolver caso hidráulico simples; gases/esgoto exigem solvers apropriados. |

**Importante:** “em especificação” não é sinônimo de bug. Só promover um item a “implementado” depois de código, testes repetíveis, validação e documentação atualizados.

## 3. Backlog recomendado — lacunas obrigatórias

As prioridades **P0/P1/P2** abaixo são recomendações desta auditoria; não substituem os IDs funcionais existentes.

| ID | Prioridade | Área | Lacuna / ação | Critério objetivo de aceite |
|---|---|---|---|---|
| AUD-001 | **P0** | Núcleo comum | Implementar `ea_geometria` (coordenadas, tolerâncias, interseções, polígonos) e testes. | Desenho 4.000 × 3.000 mm mantém medidas; áreas e interseções validadas. |
| AUD-002 | **P0** | Contrato de dados | Implementar `ea_modelo`, `ea_pacote`, manifesto, schema versionado, hashes, IDs estáveis, unidades e sistema de eixos. | Salvar, reabrir e comparar projeto com dois pavimentos sem perdas de identidade/geometria. |
| AUD-003 | **P0** | Segurança e interoperabilidade | Importação transacional e segura; rastrear proveniência, recusar arquivo incompatível, nunca sobrescrever fonte. | Arquivos inválidos não corrompem projeto; relatório lista entidades perdidas. |
| AUD-004 | **P0** | CAD 2D | Criar aplicação Lazarus 2D real: viewport, seleção, zoom/pan, snap, grid, comando numérico, undo/redo e layers. | Desenhar e editar planta em mm, salvar/reabrir sem alterar geometria. |
| AUD-005 | **P0** | CAD arquitetônico | Paredes paramétricas, união, portas/janelas com vãos, áreas e cotas associativas básicas. | Alterar parede move abertura vinculada e atualiza cotas/áreas corretamente. |
| AUD-006 | **P0** | Arquivos de mercado | Implementar importação/exportação DXF essencial e suíte de arquivos reais; prévia e calibração. | DXF preserva medidas, layers e objetos suportados, com relatório de diferenças. |
| AUD-007 | **P0** | Planejador | Concluir P2 e contrato de tarefa/retorno entre programas, com falha explícita se aplicativo indisponível. | Tarefa do CAD inicia com parâmetros e retorna artefato/revisão rastreável. |
| AUD-008 | **P0** | Qualidade | Criar CI para Windows/Linux, testes de console/GUI sem hardware, empacotamento e registro de versões. | Pipeline verde e artefatos testados, com manifesto e SHA-256. |
| AUD-009 | **P1** | Maquete 3D | Converter paredes, aberturas, lajes e pavimentos do modelo canônico em malhas 3D. | Dois pavimentos alinhados, portas/janelas abertas corretamente, órbita/zoom e salvamento. |
| AUD-010 | **P1** | Atualização | Implementar comparação de revisões, vínculos por ID, âncoras e resolução explícita de conflitos. | Mudar posição de parede atualiza geometria vinculada sem perder material e sem apagar objetos órfãos. |
| AUD-011 | **P1** | Objetos 3D | Importar STL/3MF **como arquivos**, inspecionar malha/unidade/orientação e salvar em biblioteca; sem depender do MultiCNC. | Um STL externo é posicionado e reaberto na maquete, sem alteração do original. |
| AUD-012 | **P1** | Skins | Gerar/importar texturas, mapear UV ou triplanar, associar materiais PBR por objeto ou face e exportar GLB. | Reabrir GLB mantendo materiais e ligações aos objetos; STL sem UV é tratado explicitamente. |
| AUD-013 | **P1** | Mercado/BIM | Escolher e licenciar estratégia DWG/IFC, definir subconjunto, testar exemplos reais e perdas. | DWG e IFC com múltiplos pavimentos importados com métricas e relatório; nada de prometer cobertura universal. |
| AUD-014 | **P1** | Coordenação | Definir visualização federada e detecção de interferências entre arquitetura/elétrica/tubulações como função compartilhada; **não criar aplicativo extra por padrão**. | Detectar eletroduto cruzando tubulação ou elemento arquitetônico e gerar ocorrência com ID e localização. |
| AUD-015 | **P1** | Elétrica 3D | Criar editor próprio com conectividade/topologia elétrica, cabos, eletrodutos, quadros, pontos, circuitos e exportação. | Circuito completo persistido com relação explícita a espaços e objetos da maquete. |
| AUD-016 | **P1** | SimuEletrica | Integrar solver isolado e validado para cargas, tensões/correntes, proteções e falhas. | Comparar circuito de referência com cálculo analítico; registrar hipóteses, solver e erros. |
| AUD-017 | **P1** | SimuTubulações | Implementar editor topológico e solver por domínio; separar água pressurizada, gás/ar compressível e esgoto por gravidade. | Casos de referência conferidos com balanço de massa e condições de contorno. |
| AUD-018 | **P1** | Documentação | Produzir pranchas 2D em PDF com escala, cotas, carimbo, layers e identificação de revisão. | Imprimir 1:50 e medir referência física válida em página exportada. |
| AUD-019 | **P2** | Criador de Cenas | Integrar renderizador em processo isolado, câmeras, luzes, PBR e imagem final; depois keyframes, pessoas, vegetação/água e vídeos. | Renderizar cenas diurna/noturna e exportar vídeo com trajetória de câmera e porta animada. |
| AUD-020 | **P2** | Planejador completo | Concluir P3/P4: recursos, baseline, curva S, tarefas de objetos e vínculo de skins. | Persistir e reabrir linha de base e vínculos por objeto/face. |
| AUD-021 | **P2** | Release e suporte | Instaladores independentes ou seleção de módulos, versões compatíveis, diagnósticos, importação/exportação e teste de instalação limpa. | Uma instalação sem MultiCNC abre pacote exportado por outro aplicativo. |

### Escopo e limites que não podem ser violados

1. O **CAD 2D** edita plantas e documentação técnica; **não** faz renderização fotorrealista.
2. A **Maquete 3D** reconstrói edifícios e edita objetos/skins; não substitui o Criador de Cenas.
3. O **Criador de Cenas** gera imagens/vídeos/animações; não altera unilateralmente a geometria arquitetônica.
4. **Elétrica 3D** é programa independente; **SimuEletrica** apenas calcula e devolve resultados vinculados, sem alterar a fonte.
5. **SimuTubulações** é independente, com editor de redes e simulações apropriadas a cada fluido no próprio programa, no escopo atual.
6. O **Planejador** coordena tarefas e arquivos, não executa geometria nem cálculos das disciplinas.
7. **MultiCNC/MultiCAD não são incorporados**: apenas importar STL/3MF exportados. `.mcad` e `.msuite` não são compatíveis.
8. Cada ferramenta lê pacotes versionados e salva seu próprio documento; importação/revisão exige confirmação para mudanças destrutivas.

## 4. Entregas priorizadas e dependências

### Entrega 0 — Base transversal (primeiro)

- AUD-001, AUD-002, AUD-003 e AUD-008.
- Definir formato nativo canônico, diretrizes de unidades (mm), eixos Z-up para troca 3D, transformações por pavimento, IDs e esquema de revisão.
- Testar serialização, conversão de unidades e integridade de pacotes antes de produzir UI extensa.

### Entrega 1 — CAD 2D funcional

- AUD-004, AUD-005 e AUD-006, com DXF antes de DWG.
- Percurso mínimo: criar planta retangular com paredes, porta, janela, ambiente, cotas, salvar, reabrir, exportar e importar DXF.
- O Planejador pode seguir em paralelo, mas P2 só deve ser homologada quando houver um aplicativo de destino funcional.

### Entrega 2 — Maquete 3D e acabamentos

- AUD-009, AUD-010, AUD-011 e AUD-012.
- Importar uma planta e conjunto de pavimentos; reconstruir paredes, lajes, vãos e escadas com revisão assistida.
- Biblioteca de objetos STL/3MF e skins, exportação GLB com material e identificação por objeto.

### Entrega 3 — Engenharia sobre a maquete

- AUD-014 a AUD-017.
- Persistir instalações de elétrica e tubulações como disciplinas independentes, visualizáveis sem editar o modelo arquitetônico.
- Simulações reproduzíveis com classificação **estimativa / análise de engenharia / validada**. Para gás, curtos e aquecimento, não apresentar simulação como certificado de segurança ou autorização de operação.

### Entrega 4 — Documentação e apresentação

- AUD-018 a AUD-021.
- Exportação técnica em escala, Criador de Cenas com render inicial antes das animações, planejamento completo e instaladores por aplicação.

## 5. Decisões técnicas pendentes

| Tema | Recomendação inicial | Bloqueia |
|---|---|---|
| Formato nativo | JSON versionado no MVP; pacote com manifesto e GLB para trocas maiores | Entrega 0 |
| Qualidade das coordenadas | Milímetros e Double, sistema de eixos explícito e transformações por pavimento | Entrega 0 |
| DXF | Implementar subconjunto priorizado e testar roundtrip real | Entrega 1 |
| DWG | Escolher SDK/conversor com licença compatível | Importação de mercado |
| IFC | Preferir adaptador externo isolado, com versões suportadas explicitadas | BIM/intercâmbio |
| STL e 3MF | Ler arquivos produzidos por qualquer ferramenta, sem dependência do produtor | Entrega 2 |
| Texturas | Versionar por ID e preservar versão aplicada até comando de atualização (proposta) | Entrega 2 |
| Render final | Processo separado para não acoplar interface ao motor de renderização | Entrega 4 |
| Solvers | Interface definida por contrato, testes com benchmarks e avisos de limites | Entrega 3 |
| Sistemas operacionais | Suportar Windows/Linux com CI; ampliar plataformas só após homologação | Releases |

A seleção final de bibliotecas, licenças e extensão nativa continua em aberto; não há decisão inventada nesta auditoria.

## 6. Lacunas de gestão do desenvolvimento

- **CI ausente na revisão:** criar `.github/workflows` com compilação e testes Lazarus/FPC Windows/Linux. Disponibilizar logs e falhas por módulo.
- **Teste não executado nesta auditoria:** presença de `planejador/tests/test_planejador_core.lpr` não comprova aprovação atual; compilar e executar no pipeline.
- **Build de entrega parcial:** há `bin/planejador.exe` e instalador 002, mas ainda não existe uma distribuição dos sete aplicativos operacionais. A instalação modular deverá distinguir programas prontos de protótipos.
- **Contradição documental:** o cabeçalho de `docs/Plano_Desenvolvimento.md` declara “nenhuma fase iniciada”, mas sua tabela marca a Fase 3 em andamento com P1 concluída; corrigir a síntese sem alterar o histórico.
- **Homologação de arquivos reais:** preparar fixtures DXF/DWG/IFC/STL/3MF e medir propriedades preservadas. Não usar apenas exemplos sintéticos.
- **Critérios de entrega:** marcar cada funcionalidade como `Especificada`, `Em implementação`, `Compilada`, `Testada automaticamente`, `Validada manualmente` e `Homologada`, sem saltar estados.
- **Auditoria de integração:** não basta o lançador abrir o executável; o aplicativo destino deve carregar o pacote e devolver um resultado coerente, com revisão/ID/hash.

## 7. Casos de aceitação ponta a ponta

| Teste | Procedimento | Resultado exigido |
|---|---|---|
| EA-E2E-01 | CAD cria sala de 4 × 3 m, parede 150 mm, porta e janela; salva e reabre | Paredes, vãos, medidas, cotas e IDs preservados |
| EA-E2E-02 | Exporta DXF, reimporta e compara entidades | Diferenças dentro de tolerância explícita; perdas relatadas |
| EA-E2E-03 | Abre térreo e andar, configura 0 e +3.000 mm | Dois pavimentos alinhados, sem paredes desconectadas |
| EA-E2E-04 | Importa STL externo, corrige unidades, aplica skin de madeira e exporta GLB | Geometria e material persistidos; nenhuma dependência de MultiCNC |
| EA-E2E-05 | Altera parede no CAD e atualiza maquete | Vão/âncoras atualizados; vínculos preservados ou conflitos explícitos |
| EA-E2E-06 | Cria circuito elétrico e um ramal hidráulico no mesmo modelo | Camadas independentes e interferências indicadas |
| EA-E2E-07 | Simula circuito com carga conhecida e rede hidráulica com referência | Resultados reproduzíveis com hipóteses, limites e versão do solver |
| EA-E2E-08 | Importa cena, posiciona câmera e renderiza | Imagem gerada com os materiais esperados, sem editar maquete original |
| EA-E2E-09 | Planejador despacha tarefa de planta e recebe retorno | Contrato validado, artefato reconhecido e revisão registrada |
| EA-E2E-10 | Instala apenas CAD ou Maquete em máquina limpa | Aplicativo abre seus arquivos sem exigir MultiCNC nem outras aplicações |

## 8. Funcionalidades futuras: não confundir com lacunas do MVP

Estruturas/FEM, topografia, orçamento de obras e climatização podem ser avaliados **futuramente como extensões de escopo**, caso exista requisito de produto. Não fazem parte das sete aplicações aprovadas nem impedem o fluxo inicial. **Não abrir projetos extras automaticamente**. Recursos de detecção de colisão e coordenação já cabem em `ea_geometria`, `ea_modelo`, `Integrações` e interfaces dos módulos existentes.

## 9. Referências internas

- [Índice da documentação](README.md)
- [Visão geral](Visao_Geral_Plataforma.md)
- [Núcleo comum](Nucleo_Comum.md)
- [Motor de importação](Motor_Importacao.md)
- [Integrações e manifesto](Integracoes.md)
- [Plano de desenvolvimento](Plano_Desenvolvimento.md)
- [Decisões](Decisoes.md)
- [Planejador](Planejador.md)
- [CAD 2D](CAD_Arquitetonico_2D.md)
- [Maquete 3D](Maquete_3D.md)
- [Editor de Objetos](Editor_Objetos_3D.md)
- [Gerador de Texturas](Gerador_Texturas.md)
- [Criador de Cenas](Criador_Cenas.md)
- [Elétrica 3D](Eletrica_3D.md)
- [SimuEletrica](SimuEletrica.md)
- [SimuTubulações](SimuTubulacoes.md)

**Regra de documentação:** toda implementação deverá atualizar seu documento de componente, este backlog se pertinente e os testes de aceitação. Esta auditoria não altera código nem declara recursos prontos.
