# Visão geral da plataforma

**Versão:** 1.8 — 28/10/2026  
**Estado:** proposta de requisitos (ainda não implementada)  
**Referência funcional:** AutoCAD / AutoCAD Architecture, com interoperabilidade CAD/BIM  
**Arquitetura proposta:** seis aplicativos independentes (**Planejador**, **CAD Arquitetônico 2D**, **Maquete 3D**, **Criador de Cenas Realistas**, **Elétrica 3D** e **SimuEletrica**) conectados por contratos de intercâmbio versionados. O **Gerador de Texturas (Skins)** e o **Editor de Objetos 3D** são módulos internos da Maquete 3D. O **Elétrica 3D não é plugin e não integra o executável nem o instalador da Maquete 3D**. O Criador de Cenas também é um programa independente. **MultiCNC/MultiCAD é software externo, não incorporado, instalado ou exigido; dele são aceitos somente os arquivos de sólidos (STL e 3MF).**

> Este documento reúne o que vale para todos os componentes. Cada componente tem documento próprio, listado no [índice](README.md).

## 1. Aplicativos

### Planejador (aplicativo independente)
Gerenciador do empreendimento, tendo o Microsoft Project como referência funcional. Cria e encadeia tarefas em grafo (cadeia e paralelo), oferece visões de cronograma e gráficos de acompanhamento e cria **tarefas arquitetônicas executadas nas demais aplicações**. Ao criar ou importar um objeto 3D, pode criar tarefas ou anexá-lo a tarefas existentes e vincular texturas a ele. Especificação em [Planejador](Planejador.md).

Documento: [Planejador](Planejador.md).

### CAD Arquitetônico 2D
Editor de desenho técnico 2D para produzir plantas baixas, com ferramentas de precisão, objetos arquitetônicos inteligentes (paredes, portas, janelas), cotas, layers, documentação e importação/exportação dos formatos usuais de mercado. **Não é responsável pela renderização fotorrealista.**

Documento: [CAD Arquitetônico 2D](CAD_Arquitetonico_2D.md).

### Gerador de Maquetes 3D
Aplicativo para importar uma planta ou um conjunto de plantas baixas, reconhecer e associar pavimentos, reconstruir o volume 3D de uma edificação, **criar, editar e posicionar objetos tridimensionais em um editor 3D integrado**, organizar bibliotecas de componentes e visualizar o resultado em 3D com materiais e iluminação básica de trabalho. A renderização ultrarrealista e os movimentos avançados ficam no aplicativo independente Criador de Cenas. Recebe também modelos BIM e malhas 3D importadas. O Editor de Objetos 3D importa STL/3MF e outros formatos de mercado independentemente do aplicativo de origem. O Gerador de Texturas (Skins), integrado ao próprio projeto 3D, cria, importa, aplica e reutiliza materiais de aparência PBR em objetos e superfícies arquitetônicas.

Documento: [Maquete 3D](Maquete_3D.md).

### Criador de Cenas Realistas (aplicativo independente)
Recebe uma **maquete finalizada ou sua revisão**, incluindo geometria, objetos 3D, skins e respectivos metadados. Adiciona câmeras, animações, personagens, água em movimento, vegetação ao vento, abertura de portas, efeitos climáticos e iluminação realista; gera imagens, vídeos e passeios virtuais. Não é o editor técnico de plantas nem o editor de circuitos.

Documento: [Criador de Cenas](Criador_Cenas.md).

### Elétrica 3D (aplicativo independente, integrado à Maquete 3D)
Recebe a **maquete arquitetônica como referência**, sem duplicar ou substituir seu editor, e cria a disciplina elétrica tridimensional: eletrodutos, conduítes, eletrocalhas, cabos, caixas, tomadas, interruptores, pontos de luz, quadros e circuitos. Salva seu projeto elétrico próprio e entrega à Maquete 3D uma camada vinculada de instalações para coordenação e visualização. O Criador de Cenas pode consumir a posição de luminárias e comandos para simular a iluminação, sem calcular ou validar o projeto elétrico.

Documento: [Elétrica 3D](Eletrica_3D.md).

### SimuEletrica (aplicativo independente, integrado ao Elétrica 3D)
Importa a topologia e os parâmetros elétricos definidos no Elétrica 3D e a referência espacial da maquete para simular regimes de operação, cargas e falhas, atuação de proteções, efeitos resistivos/indutivos/capacitivos, aquecimento dos condutores e mapas térmicos 3D. **Não é incorporado ao Elétrica 3D** e não deve modificar automaticamente o projeto elétrico original. Seus resultados são estimativas dependentes das hipóteses e modelos selecionados, não laudos de segurança ou ensaios físicos.

Documento: [SimuEletrica](SimuEletrica.md).

## 2. Objetivos de negócio

- Aproveitar projetos já produzidos em AutoCAD, Revit, Archicad, SketchUp e outras ferramentas, sem exigir redesenho integral.
- Criar uma planta em 2D uma vez e aproveitá-la na maquete 3D.
- Suportar edifícios térreos ou com vários pavimentos, incluindo subsolos, cobertura, cortes e fachadas quando disponíveis.
- Evitar dependência de um fornecedor único por meio de formatos abertos e adaptadores de formatos proprietários.
- Permitir mobiliário, instalações, acabamentos e objetos personalizados por meio de um editor 3D e uma biblioteca reutilizável, sem exigir software externo para operações comuns.
- Permitir importar arquivos produzidos em ferramentas externas; do MultiCAD/MultiCNC, somente os arquivos de sólidos STL e 3MF. O usuário não precisa instalar ou executar o MultiCNC.
- Disponibilizar gerador de skins próprio, utilizável com paredes, pisos, tetos, móveis e peças importadas, mesmo sem nenhum software externo instalado.
- Permitir que o Criador de Cenas trabalhe com a maquete pronta, inclusive objetos, materiais e animações cinematográficas.
- Permitir que o Elétrica 3D opere com instalação e armazenamento próprios, vinculado à maquete sem incorporar seus executáveis ao pacote arquitetônico.
- Permitir simular eletricamente o projeto em um **SimuEletrica independente**, com cenários de carga, falhas, proteções, modelagem RLC, aquecimento e visualização espacial de resultados, sem alterar os dados-fonte sem aprovação.

## 3. Escopo e delimitação

| Responsabilidade | CAD 2D | Maquete 3D | Criador de Cenas | Elétrica 3D | SimuEletrica |
|---|---|---|---|---|---|
| Desenho técnico e plantas | **Principal** | Consulta | Não | Não | Não |
| Edificação volumétrica e biblioteca de objetos/skins | Fornece dados | **Principal** | Consome | Referência | Referência espacial |
| Câmeras, pessoas, água, vento, render final | Não | Prévia | **Principal** | Não | Não |
| Cabos, eletrodutos, tomadas, quadros e diagramas elétricos | Não | Exibe vínculo | Visualização opcional | **Principal** | Consome topologia |
| Cargas, curto-circuito, atuação de relés e sobrecarga | Não | Não | Não | Fornece dados | **Principal** |
| Capacitância, indutância, harmônicos e análise transitória | Não | Não | Não | Fornece dados | **Principal, por modelo** |
| Aquecimento de cabos e mapa térmico espacial | Não | Exibe resultado opcional | Não | Fornece geometria | **Principal** |
| Importação CAD/BIM e dados semânticos | **Principal** | **Principal** | Modelos/maquetes | Maquete/instalação | Pacote elétrico versionado |
| Instalação própria e arquivos nativos | Sim | Sim | Sim | Sim | Sim |
| Dependência de instalação do MultiCNC | Não | Não | Não | Não | Não |

**Planejador:** não aparece na tabela porque não produz geometria; ele cria, encadeia e acompanha as tarefas executadas em todos os aplicativos acima ([Planejador](Planejador.md)).

**Separação:** o Elétrica 3D é a fonte da verdade do projeto elétrico; o SimuEletrica é a fonte da verdade dos cenários e resultados simulados. Simulações não alteram circuitos, bitolas, rotas ou proteções originais automaticamente.

## 4. Requisitos não funcionais comuns

| ID | Requisito |
|---|---|
| RNF-001 | Precisão: armazenar coordenadas em dupla precisão, unidades explícitas e tolerâncias configuráveis. |
| RNF-002 | Portabilidade: preferir núcleo multiplataforma, com adaptadores opcionais para SDKs dependentes de sistema operacional. |
| RNF-003 | Robustez: arquivo não reconhecido não deve corromper o projeto; falhas devem gerar log e permitir cancelamento. |
| RNF-004 | Rastreamento: cada objeto convertido deve preservar vínculo com a entidade de origem quando possível. |
| RNF-005 | Segurança: importação não pode executar conteúdo ativo dos arquivos nem acessar caminhos externos sem consentimento. |
| RNF-006 | Extensibilidade: cada formato deve ser um adaptador testável, com versão e capacidades declaradas. |
| RNF-007 | Desempenho: realizar testes de referência com modelos pequenos, médios e grandes e estabelecer metas após medição. |
| RNF-008 | Usabilidade: assistente de importação deve expor erros de unidade, escala, georreferência e objetos ignorados. |
| RNF-009 | Integridade: importação e reimportação devem preservar a versão anterior até a confirmação do usuário. |
| RNF-010 | Compatibilidade: matriz de versões de arquivos e provedores homologados deve acompanhar cada release. |
| RNF-011 | Independência: Maquete 3D e Gerador de Texturas deverão instalar e operar sem MultiCNC, MultiCAD ou MultiSuite. |
| RNF-012 | Reprodutibilidade: geradores procedurais deverão restaurar resultado com a mesma configuração, versão e semente. |
| RNF-013 | Interoperabilidade: pacote de skin deve preservar seus mapas e metadados; exportação GLB deve relatar eventuais limitações. |

## 5. Fontes técnicas de referência

- Autodesk — formatos de importação do AutoCAD: https://www.autodesk.com/br/support/technical/article/caas/sfdcarticles/sfdcarticles/PTB/What-file-formats-can-AutoCAD-import.html
- buildingSMART — Industry Foundation Classes: https://www.buildingsmart.org/standards/bsi-standards/industry-foundation-classes/
- Open Design Alliance — Drawings SDK (DWG/DGN): https://www.opendesign.com/products/drawings
- Autodesk — Revit e IFC: https://www.autodesk.com/support/technical/article/Revit-to-IFC-and-back-to-Revit/
- Khronos — glTF Registry: https://registry.khronos.org/glTF/
- FreeCAD — componentes adicionais / conversores DWG: https://github.com/FreeCAD/FreeCAD-documentation/blob/main/wiki/Installing_additional_components.md
- Repositório MultiCNC, branch `fila` — README da suíte: https://github.com/marcelomaurin/multicnc/blob/fila/README.md
- MultiCAD, branch `fila` — `.mcad`, STL e 3MF: https://github.com/marcelomaurin/multicnc/blob/fila/multicad/README.md

**Nota:** **MultiCNC/MultiCAD não integra o pacote e não é dependência de instalação ou execução.** Os modelos são recebidos por arquivos exportados. Esta especificação descreve o comportamento desejado e as alternativas técnicas. Ela não afirma que importadores, licenças ou compatibilidade com formatos proprietários já estejam implementados.
