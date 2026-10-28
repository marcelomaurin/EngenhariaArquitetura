# Especificação de Requisitos — Plataforma de Arquitetura, Instalações e Simulação Elétrica

**Versão:** 1.8 — 28/10/2026  
**Estado:** proposta de requisitos (ainda não implementada)  
**Referência funcional:** AutoCAD / AutoCAD Architecture, com interoperabilidade CAD/BIM  
**Arquitetura proposta:** seis aplicativos independentes (**Planejador**, **CAD Arquitetônico 2D**, **Maquete 3D**, **Criador de Cenas Realistas**, **Elétrica 3D** e **SimuEletrica**) conectados por contratos de intercâmbio versionados. O **Gerador de Texturas (Skins)** e o **Editor de Objetos 3D** são módulos internos da Maquete 3D. O **Elétrica 3D não é plugin e não integra o executável nem o instalador da Maquete 3D**. O Criador de Cenas também é um programa independente. **MultiCNC/MultiCAD é software externo, não incorporado, instalado ou exigido; dele são aceitos somente os arquivos de sólidos (STL e 3MF).**

## 1. Visão geral

### Projeto P — Planejador (aplicativo independente)
Gerenciador do empreendimento, tendo o Microsoft Project como referência funcional. Cria e encadeia tarefas em grafo (cadeia e paralelo), oferece visões de cronograma e gráficos de acompanhamento e cria **tarefas arquitetônicas executadas nas demais aplicações**. Ao criar ou importar um objeto 3D, pode criar tarefas ou anexá-lo a tarefas existentes e vincular texturas a ele. Especificação na seção 19.

### Projeto A — CAD Arquitetônico 2D
Editor de desenho técnico 2D para produzir plantas baixas, com ferramentas de precisão, objetos arquitetônicos inteligentes (paredes, portas, janelas), cotas, layers, documentação e importação/exportação dos formatos usuais de mercado. **Não é responsável pela renderização fotorrealista.**

### Projeto B — Gerador de Maquetes 3D
Aplicativo para importar uma planta ou um conjunto de plantas baixas, reconhecer e associar pavimentos, reconstruir o volume 3D de uma edificação, **criar, editar e posicionar objetos tridimensionais em um editor 3D integrado**, organizar bibliotecas de componentes e visualizar o resultado em 3D com materiais e iluminação básica de trabalho. A renderização ultrarrealista e os movimentos avançados ficam no aplicativo independente Criador de Cenas. Recebe também modelos BIM e malhas 3D importadas. O Editor de Objetos 3D importa STL/3MF e outros formatos de mercado independentemente do aplicativo de origem. O Gerador de Texturas (Skins), integrado ao próprio projeto 3D, cria, importa, aplica e reutiliza materiais de aparência PBR em objetos e superfícies arquitetônicas.

### Projeto C — Criador de Cenas Realistas (aplicativo independente)
Recebe uma **maquete finalizada ou sua revisão**, incluindo geometria, objetos 3D, skins e respectivos metadados. Adiciona câmeras, animações, personagens, água em movimento, vegetação ao vento, abertura de portas, efeitos climáticos e iluminação realista; gera imagens, vídeos e passeios virtuais. Não é o editor técnico de plantas nem o editor de circuitos.

### Projeto D — Elétrica 3D (aplicativo independente, integrado à Maquete 3D)
Recebe a **maquete arquitetônica como referência**, sem duplicar ou substituir seu editor, e cria a disciplina elétrica tridimensional: eletrodutos, conduítes, eletrocalhas, cabos, caixas, tomadas, interruptores, pontos de luz, quadros e circuitos. Salva seu projeto elétrico próprio e entrega à Maquete 3D uma camada vinculada de instalações para coordenação e visualização. O Criador de Cenas pode consumir a posição de luminárias e comandos para simular a iluminação, sem calcular ou validar o projeto elétrico.

### Projeto E — SimuEletrica (aplicativo independente, integrado ao Elétrica 3D)
Importa a topologia e os parâmetros elétricos definidos no Elétrica 3D e a referência espacial da maquete para simular regimes de operação, cargas e falhas, atuação de proteções, efeitos resistivos/indutivos/capacitivos, aquecimento dos condutores e mapas térmicos 3D. **Não é incorporado ao Elétrica 3D** e não deve modificar automaticamente o projeto elétrico original. Seus resultados são estimativas dependentes das hipóteses e modelos selecionados, não laudos de segurança ou ensaios físicos.

### Objetivos de negócio
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

## 2. Escopo e delimitação

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

**Planejador:** não aparece na tabela porque não produz geometria; ele cria, encadeia e acompanha as tarefas executadas em todos os aplicativos acima (seção 19).

**Separação:** o Elétrica 3D é a fonte da verdade do projeto elétrico; o SimuEletrica é a fonte da verdade dos cenários e resultados simulados. Simulações não alteram circuitos, bitolas, rotas ou proteções originais automaticamente.

## 3. Requisitos funcionais — CAD 2D

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RF2D-001 | Essencial | Criar, abrir, salvar, duplicar e versionar projetos 2D. |
| RF2D-002 | Essencial | Desenhar linha, polilinha, arco, círculo, retângulo, polígono e hachura. |
| RF2D-003 | Essencial | Selecionar, mover, copiar, rotacionar, espelhar, escalar, aparar, estender e aplicar offset. |
| RF2D-004 | Essencial | Trabalhar com coordenadas absolutas/relativas, entrada numérica, unidades configuráveis e desenho 1:1. |
| RF2D-005 | Essencial | Oferecer grid, snap em extremidade/meio/interseção/perpendicular, modo ortogonal e rastreamento angular. |
| RF2D-006 | Essencial | Administrar layers com nome, visibilidade, bloqueio, cor, espessura e tipo de linha. |
| RF2D-007 | Essencial | Criar paredes paramétricas com largura, altura, material, eixo, alinhamento e conexões. |
| RF2D-008 | Essencial | Inserir portas e janelas com posicionamento, dimensões e abertura automática do vão na parede. |
| RF2D-009 | Essencial | Reconhecer ambientes fechados e calcular perímetro, área e identificador. |
| RF2D-010 | Essencial | Inserir cotas lineares, alinhadas, angulares e de raio/diâmetro, vinculáveis à geometria. |
| RF2D-011 | Essencial | Importar DWG e DXF por mecanismos documentados, com relatório de entidades não suportadas. |
| RF2D-012 | Essencial | Importar PDF vetorial, SVG e imagens de referência (PNG/JPEG/TIFF), preservando ou calibrando escala. |
| RF2D-013 | Essencial | Pré-visualizar importação, selecionar folhas/layers/blocos e configurar escala, unidades e origem. |
| RF2D-014 | Essencial | Criar, editar e reutilizar blocos/símbolos, inclusive móveis e símbolos arquitetônicos. |
| RF2D-015 | Essencial | Gerar pranchas, configurar escalas, carimbo e exportar PDF, DXF e SVG. |
| RF2D-016 | Essencial | Desfazer/refazer operações e manter arquivo original de importação intacto. |
| RF2D-017 | Importante | Importar DGN e extrair vistas 2D de modelos IFC, preservando informações possíveis. |
| RF2D-018 | Importante | Atualizar desenhos vinculados e sinalizar diferenças entre revisões. |
| RF2D-019 | Futuro | Suportar referências externas complexas (XREF), objetos personalizados e recursos avançados de DWG. |
| RF2D-020 | Futuro | Validar parâmetros de representação e acessibilidade mediante regras configuráveis. |

## 4. Requisitos funcionais — Gerador de Maquetes 3D

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RF3D-001 | Essencial | Importar uma planta baixa isolada ou várias plantas em uma única operação. |
| RF3D-002 | Essencial | Importar desenho técnico DWG/DXF e modelos BIM IFC; aceitar formato interno do CAD 2D. |
| RF3D-003 | Essencial | Identificar ou solicitar ao usuário a associação dos arquivos a térreo, pavimentos, subsolo e cobertura. |
| RF3D-004 | Essencial | Alinhar pavimentos por origem, eixos, pontos de controle ou transformações assistidas. |
| RF3D-005 | Essencial | Definir cotas de nível, pé-direito, espessuras de lajes, alturas das paredes e níveis de cobertura. |
| RF3D-006 | Essencial | Converter paredes 2D em volumes 3D e executar junções, encontros e recortes. |
| RF3D-007 | Essencial | Gerar vãos, portas, janelas e respectivos posicionamentos a partir dos dados da planta. |
| RF3D-008 | Essencial | Gerar pisos, lajes, ambientes e estrutura simplificada conforme dados disponíveis. |
| RF3D-009 | Essencial | Reconhecer escadas e relacionar pavimentos, com confirmação de parâmetros ambíguos. |
| RF3D-010 | Essencial | Permitir orbit, pan, zoom, câmera em perspectiva/ortográfica e ocultação de pavimentos. |
| RF3D-011 | Essencial | Exibir prévia da maquete e registrar alertas sobre ausências ou ambiguidades da origem. |
| RF3D-012 | Essencial | Salvar e reabrir maquete, preservando a associação com cada arquivo importado. |
| RF3D-013 | Importante | Importar geometria 3D de referência em STL, 3MF, OBJ, glTF/GLB, DAE e FBX, com adaptações conforme o formato. |
| RF3D-014 | Importante | Importar IFC2x3, IFC4 e IFC4.3, inclusive hierarquia de pavimentos e objetos semânticos. |
| RF3D-015 | Importante | Aplicar skins, transparência, materiais e iluminação de **pré-visualização** para montagem da maquete. |
| RF3D-016 | Importante | Disponibilizar vistas internas/externas e exportar a cena geométrica completa, com objetos e skins, ao Criador de Cenas externo. |
| RF3D-017 | Importante | Comparar versões das plantas e atualizar somente elementos alterados, preservando ajustes manuais quando possível. |
| RF3D-018 | Importante | Exportar maquete em glTF/GLB, OBJ, imagens e, quando viável, IFC com dados arquitetônicos. |
| RF3D-019 | Importante | Permitir importação de SKP/RVT por adaptador licenciado, plugin ou conversão para IFC/DXF, com indicação de perdas. |
| RF3D-020 | Futuro | Reconstruir parcialmente plantas rasterizadas por vetorização e interpretação assistida, mediante revisão humana. |
| RF3D-021 | Futuro | Criar telhados complexos a partir de plantas de cobertura, cortes e fachadas. |
| RF3D-022 | Importante | Exibir disciplinas externas vinculadas (como Elétrica 3D) e verificar conflitos geométricos simples sem editar os circuitos desses aplicativos. |

## 4A. Módulo obrigatório — Editor e Biblioteca de Objetos 3D

### 4A.1. Descrição e finalidade
O **Editor de Objetos 3D** é um módulo nativo do **Projeto B (Gerador de Maquetes 3D)**, com janela/área de edição própria, mas integrado à cena da maquete. Deve permitir **criar, importar, ajustar, catalogar e reutilizar objetos tridimensionais**, como móveis, bancadas, equipamentos hospitalares, luminárias, portas especiais, esquadrias, árvores, veículos e elementos decorativos. Não faz parte do editor CAD 2D. Este módulo **não substitui um modelador profissional completo** na primeira versão: começará com primitivas, transformações, edição básica de malhas e materiais, ampliando depois para ferramentas avançadas.

### 4A.2. Requisitos funcionais específicos

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RF3D-023 | **Essencial** | Abrir o Editor de Objetos 3D a partir da maquete ou da biblioteca, em modo de criação ou edição de um objeto existente. |
| RF3D-024 | **Essencial** | Criar objetos com primitivas: caixa, plano, cilindro, esfera, cone e combinações simples, com medidas reais. |
| RF3D-025 | **Essencial** | Selecionar, mover, rotacionar, redimensionar proporcionalmente ou por eixo X/Y/Z, duplicar e excluir objetos; oferecer entrada numérica e manipuladores 3D. |
| RF3D-026 | **Essencial** | Configurar origem/pivô do objeto, alinhamento por eixos, snap em grade/superfície, orientação e unidades. |
| RF3D-027 | **Essencial** | Importar modelos externos em STL (ASCII/binário), 3MF, GLB/glTF e OBJ, preservando os atributos disponíveis e indicando perdas; STL deverá ser suportado mesmo sem materiais ou UV. |
| RF3D-028 | **Essencial** | Gerenciar biblioteca de objetos com categorias, pesquisa, miniaturas, tags, dimensões, autoria, licença e versões. |
| RF3D-029 | **Essencial** | Inserir objeto por arrastar e soltar ou comando de inserção, com pré-visualização de posicionamento e dimensões na maquete. |
| RF3D-030 | **Essencial** | Editar posição, rotação, escala, visibilidade e propriedades de cada instância inserida sem modificar automaticamente o objeto da biblioteca. |
| RF3D-031 | **Essencial** | Aplicar cores, materiais, texturas, transparência e, quando suportados, parâmetros PBR; permitir materiais distintos por partes do objeto. |
| RF3D-032 | **Essencial** | Salvar objetos em formato nativo versionado, incluindo geometria, unidades, origem, materiais, metadados e miniatura; exportar em GLB/glTF. |
| RF3D-033 | **Essencial** | Oferecer desfazer/refazer, copiar/colar e agrupamento/desagrupamento com confirmação para ações destrutivas. |
| RF3D-034 | **Essencial** | Associar objetos a pavimento e, quando pertinente, à superfície de apoio (piso, parede, teto), com encaixe e altura de instalação. |
| RF3D-035 | **Essencial** | Preservar objetos manuais e vínculos ao regenerar ou atualizar a maquete a partir de plantas 2D, sinalizando âncoras inválidas/conflitos. |
| RF3D-036 | **Importante** | Oferecer edição básica de malhas: selecionar vértices/arestas/faces, extrudar faces, ajustar normais, unir/separar malhas, excluir faces e recalcular geometria. |
| RF3D-037 | **Importante** | Fornecer operações booleanas de união, diferença e interseção para objetos compatíveis. |
| RF3D-038 | **Importante** | Criar objetos paramétricos de biblioteca, como mesa, armário, bancada, porta, janela e luminária, com dimensões editáveis e regeneração controlada. |
| RF3D-039 | **Importante** | Editar UV e escala/rotação de texturas; detectar texturas ausentes e oferecer relocalização/empacotamento. |
| RF3D-040 | **Importante** | Criar e reutilizar conjuntos hierárquicos, instâncias vinculadas e substituição em lote de um modelo da biblioteca, com prévia das alterações. |
| RF3D-041 | **Importante** | Detectar interseções e sugerir alinhamento, assentamento sobre superfícies, afastamentos e encaixes, sem alteração automática não confirmada. |
| RF3D-042 | **Importante** | Importar e exportar FBX e DAE por adaptadores; para STL/3MF, priorizar importação nativa e oferecer exportação compatível quando aplicável, validando o que se preserva. |
| RF3D-043 | **Futuro** | Permitir geração ou adaptação assistida por IA a partir de descrições e referências, sempre com revisão do usuário. |
| RF3D-044 | **Futuro** | Incluir modificadores avançados, detalhamento fino de topologia, animações e níveis de detalhe (LOD). |

### 4A.3. Interface mínima
- **Biblioteca de Objetos:** categorias (móveis, cozinha, banheiro, portas/esquadrias, iluminação, equipamentos hospitalares, instalações, vegetação, decoração e personalizados), busca, filtros e miniaturas.
- **Viewport 3D de edição:** órbita, pan, zoom, vistas frontal/lateral/superior e perspectiva; grade, eixos e gizmos de manipulação.
- **Árvore de componentes:** partes/meshes, grupos e instâncias, com seleção, visibilidade e bloqueio.
- **Painel de propriedades:** dimensões reais, origem, transformação, material, textura, categoria, tags e vínculos de instalação.
- **Painel de materiais:** biblioteca de materiais, visualização e substituição por componente.
- **Comandos:** Novo objeto, Abrir, Importar, Salvar como objeto, Exportar, Adicionar à biblioteca, Inserir na maquete, Editar instância, Aplicar/Substituir modelo e Desfazer/Refazer.

### 4A.4. Modelo de dados sugerido
- **Definição do objeto (asset):** `asset_id`, `version`, `category`, `name`, `units`, `pivot`, `meshes`, `materials`, `textures`, `bounds`, `thumbnail`, `source`, `license` e `metadata`.
- **Instância na maquete:** `instance_id`, `asset_id`, `asset_version`, `floor_id`, `position_xyz`, `rotation_xyz`, `scale_xyz`, `anchor`, `material_overrides` e `visibility`.
- **Arquivos:** armazenar em pacote nativo próprio com JSON de metadados, malhas, texturas e miniatura; usar GLB/glTF como formato prioritário de intercâmbio. As edições de instância não podem sobrescrever o asset sem comando explícito.
- **Sincronização:** IDs persistentes e âncoras em `floor_id`/`wall_id` para reposicionar instâncias após alterações da planta; vínculos quebrados ficam pendentes de revisão.

### 4A.5. Regras de qualidade e segurança
- Preservar unidades e proporções; nunca converter automaticamente centímetros em metros sem aviso.
- Informar polígonos excessivos, geometria degenerada, texturas ausentes, materiais não suportados e origem/pivô inconsistentes.
- Importar arquivos sem executar scripts/macros e tratar referências externas de forma segura.
- Permitir otimização de malhas e instâncias para manter responsividade em cenas com muitos objetos.
- Objeto importado como malha não ganha automaticamente semântica BIM; propriedades arquitetônicas são associadas pelo usuário ou por reconhecimento validado.

### 4A.6. Cenários de aceite
1. Criar uma mesa com primitivas, definir largura de 1.200 mm, profundidade de 700 mm e altura de 750 mm, aplicar material, salvar na biblioteca e reinserir na maquete, incluindo uma variante de skin.
2. Importar um arquivo GLB com múltiplas partes, modificar escala/orientação, editar seu material, salvar uma versão e inserir duas instâncias em pavimentos diferentes.
3. Posicionar uma luminária no teto e uma bancada contra uma parede; manter as alturas e identificar colisões relevantes.
4. Alterar a localização de uma parede na planta 2D, regenerar a maquete e comprovar que móveis não afetados continuam intactos; para objeto ancorado em parede removida, exigir aviso de conflito.
5. Exportar objeto para GLB, reimportá-lo e comparar limites geométricos, orientação, materiais e unidades com tolerância documentada.

## 4B. Interoperabilidade com arquivos externos (MultiCAD/MultiCNC inclusive) e sistema de skins

### 4B.1. Finalidade
O Editor de Objetos 3D do **Projeto B** deverá consumir modelos STL, 3MF e outros formatos de mercado, inclusive arquivos de sólidos (STL e 3MF) exportados por **MultiCAD/MultiCNC**, que permanecem **programas externos**; arquivos de projeto desses programas (`.mcad`, `.msuite`) não são lidos. Não há incorporação de seus executáveis, bibliotecas, instaladores, serviços ou código no pacote Maquete 3D. A saída do Editor de Objetos 3D será um objeto visual reutilizável, com geometria, dimensões reais, materiais, skin, miniatura e metadados, pronto para inserção na maquete. **Não é obrigação do editor reproduzir as operações paramétricas do MultiCAD ou gerar G-code**.

**Definição de skin neste projeto:** conjunto reutilizável de propriedades visuais e mapas de textura aplicado a um objeto, a uma parte da malha ou a uma superfície arquitetônica. Uma mesma geometria pode ter várias skins, como `madeira_carvalho`, `metal_escovado`, `pintura_branca` e `vidro_fume`. O editor deverá também permitir variantes visuais com partes substituíveis, quando a geometria oferecer essa divisão.

### 4B.2. Requisitos funcionais de integração e skins

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| **RF3D-045** | **Essencial** | Importar STL **ASCII e binário** de qualquer origem, inclusive criado no MultiCAD, com pré-visualização, correção de unidades, orientação, normais e tamanho; não presumir material ou UV inexistentes. |
| **RF3D-046** | **Essencial** | Importar arquivos **3MF** de qualquer origem, inclusive gerados no MultiCAD, preservando malhas e metadados de unidade e, se existirem e forem suportados, cores e materiais. |
| **RF3D-047** | **Essencial** | Exibir assistente genérico **"Importar objeto 3D"**, aceitando STL/3MF, identificando origem (quando disponível), eixos, unidades e problemas geométricos; arquivos exportados pelo MultiCAD usam o mesmo fluxo, sem exigir o aplicativo de origem. |
| **RF3D-048** | **Essencial** | Permitir editar e reparar malhas STL/3MF: orientar eixo, centralizar pivô, corrigir/gerar normais, remover faces degeneradas, separar componentes e reduzir polígonos sem alterar silenciosamente medidas. |
| **RF3D-049** | **Essencial** | Criar skins a partir de cores, materiais predefinidos, texturas importadas e padrões procedurais como madeira, concreto, cerâmica, metal, pedra, tecido e vidro. |
| **RF3D-050** | **Essencial** | Importar imagens de textura PNG, JPEG, WEBP e TIFF; vincular canais PBR (cor/base color, normal, rugosidade, metalicidade, oclusão, altura opcional, opacidade e emissão). |
| **RF3D-051** | **Essencial** | Gerar ou ajustar coordenadas **UV** quando o objeto importado não as contiver, oferecendo projeção plana, cúbica, cilíndrica e mapeamento triplanar quando suportado. |
| **RF3D-052** | **Essencial** | Ajustar escala real do padrão, repetição, deslocamento, rotação, cor e intensidade de cada mapa; pré-visualizar skin aplicada em tempo real. |
| **RF3D-053** | **Essencial** | Aplicar materiais por objeto ou por face (ou grupo de faces) e manter várias variantes de skin para a mesma geometria, sem duplicar a malha original. |
| **RF3D-054** | **Essencial** | Salvar uma skin com identificação, mapas, parâmetros, miniatura, autoria, licença e versão, permitindo reutilização na biblioteca e aplicação em outras maquetes. |
| **RF3D-055** | **Essencial** | Exportar objeto final, com material e texturas compatíveis, em **GLB/glTF** e em pacote nativo do editor; importar esse mesmo objeto diretamente no software da maquete 3D. |
| **RF3D-056** | **Essencial** | Ao substituir/reimportar um STL/3MF atualizado, oferecer correspondência de partes e preservar skins, posicionamento e instâncias da maquete quando a geometria permitir, solicitando revisão em caso de incompatibilidade. |
| ~~RF3D-057~~ | Removido (v1.4) | Leitura de `.mcad` excluída: do MultiCNC/MultiCAD só são aceitos arquivos de sólidos STL/3MF. |
| ~~RF3D-058~~ | Removido (v1.4) | Leitura de `.msuite` excluída pelo mesmo motivo do RF3D-057. |
| **RF3D-059** | **Importante** | Criar skins com base em imagens de referência do usuário e em geradores procedurais, com ajuste manual, pré-visualização e indicação da origem do material. |
| **RF3D-060** | **Importante** | Oferecer exportação/importação de **pacote de skin** autocontido, com manifesto JSON e imagens, incluindo validação de caminhos e compatibilidade de versão. |
| **RF3D-061** | **Futuro** | Usar IA para sugerir ou gerar texturas e mapas PBR a partir de descrição textual ou imagem, sempre com aprovação e condições de uso registradas. |
| **RF3D-062** | **Futuro** | Permitir intercâmbio de bibliotecas de skins por arquivos exportáveis/importáveis; a sincronização com aplicativos externos será sempre opcional e sem dependência de runtime do MultiSuite. |

### 4B.3. Compatibilidade com arquivos produzidos por ferramentas externas

A documentação consultada da branch `fila` do repositório `marcelomaurin/multicnc` descreve o **MultiCAD** como editor paramétrico de peças, usando `.mcad` para projetos e exportação de **STL**, além de **3MF** nas operações de malha. Somente os arquivos de sólidos STL e 3MF serão aceitos; a Maquete 3D não depende do MultiCAD nem do MultiCNC.

- **STL:** transportar malha; **não** esperar que contenha textura, UV, material PBR ou peças com nomes. Exigir confirmação de unidade quando ausente.
- **3MF:** usar atributos de unidade e possíveis informações de aparência quando presentes; não pressupor mapas PBR equivalentes a GLB.
- **`.mcad` / `.msuite`:** não suportados. Ao recebê-los, recusar com mensagem clara orientando exportar STL/3MF no software de origem.
- **G-code (`.gcode`, `.nc`):** código de máquina **não é modelo sólido autoritativo**. Não utilizá-lo como entrada geométrica principal. Qualquer reconstrução futura de trajetórias deve ser separada e explicitamente aproximada.
- **Eixos e unidades:** o README do MultiCAD cita `Y` para cima nas vistas da tela, mas informa que o STL é exportado "em pé para o MultiSlicer" (fatiadores usam `Z` vertical). A convenção real dos arquivos exportados deve ser **confirmada no exportador** antes de definir a conversão padrão, para não girar a peça duas vezes. O importador deverá exibir eixo de origem/destino e comparação dimensional antes da confirmação. A unidade padrão para arquivos do MultiCAD é o milímetro (sistema métrico documentado).

### 4B.4. Processo de geração e aplicação das skins

1. **Importação:** carregar STL/3MF, detectar dimensões da malha, conferir unidade e orientação.
2. **Preparação:** reparar malha, dividir em partes quando possível, preparar UV/projeção de textura e calcular caixa delimitadora.
3. **Criação da skin:** escolher um material da biblioteca, gerar padrão procedural ou carregar imagens/mapas PBR; associar canal e espaço de cor corretos.
4. **Ajustes:** definir escala física do revestimento (por exemplo, paginação de cerâmica em mm), repetição e orientação; permitir acabamento diferente para partes do objeto.
5. **Biblioteca:** salvar objeto e skins como entidades versionadas independentes, com miniaturas e metadados.
6. **Publicação:** exportar GLB ou pacote nativo autocontido e disponibilizar a opção **Inserir na Maquete 3D**.
7. **Atualização:** permitir trocar a skin sem substituir a geometria e atualizar a malha sem descartar skins quando o mapeamento continuar válido.

### 4B.5. Contrato de dados proposto

A maquete deverá referenciar separadamente o **asset geométrico**, a **variante de skin** e a **instância posicionada**. O formato nativo abaixo é uma **proposta de contrato**, não um arquivo existente do MultiCNC:

```json
{
  "schema_version": "1.0",
  "asset_id": "mesa_001",
  "source": {
    "application": "MultiCAD",
    "file": "mesa.stl",
    "format": "STL",
    "units_at_import": "mm",
    "axis_conversion": "A_CONFIRMAR_NO_EXPORTADOR"
  },
  "geometry": {"file": "mesa.glb", "pivot": "bottom_center"},
  "skins": [
    {
      "id": "carvalho_claro",
      "name": "Madeira carvalho claro",
      "material_model": "PBR_METALLIC_ROUGHNESS",
      "maps": {
        "base_color": "textures/carvalho_color.png",
        "normal": "textures/carvalho_normal.png",
        "roughness": "textures/carvalho_roughness.png"
      },
      "uv_repeat": [1, 1]
    }
  ],
  "default_skin_id": "carvalho_claro",
  "dimensions_mm": [1200, 700, 750]
}
```

**Pacote de skin sugerido:** diretório/ZIP autocontido contendo `manifest.json`, arquivos de imagem, miniatura e licença; a extensão própria só deverá ser definida após o contrato ser estabilizado. **Pacote de objeto:** manifesto semelhante, geometria GLB e skins vinculadas. A troca com ferramentas externas deverá priorizar GLB/glTF para evitar depender de extensão proprietária.

### 4B.6. Interface mínima complementar
- Aba **Importar Objeto 3D**: selecionar STL/3MF/GLB/OBJ, independentemente da ferramenta que gerou o arquivo; visualizar unidade, orientação, escala e submalhas.
- Aba **Geometria**: corrigir normais, pivô, dimensões, orientação, componentes e UV.
- Aba **Skins e Materiais**: importar imagens, gerar material procedural, criar variante, editar mapas PBR, aplicar por parte, visualizar antes/depois.
- Aba **Biblioteca**: objetos, skins, variantes e categorias com filtro por origem/projeto.
- Comandos **Salvar Objeto**, **Salvar Skin**, **Exportar GLB**, **Inserir na Maquete 3D** e **Atualizar a partir de novo STL/3MF**.

### 4B.7. Requisitos de qualidade
- Validar tamanho do arquivo, quantidade de triângulos, normais, coordenadas não finitas, objetos não-manifold, excesso de textura e referências inseguras em pacotes ZIP.
- Nunca executar macros/scripts importados nem aceitar caminhos relativos que escapem do diretório seguro de extração.
- Registrar hash da origem, adaptador, unidades, eixos, perdas, correções, skin usada e versão.
- Preservar licença/autoria das imagens e texturas; impedir alegações automáticas de propriedade intelectual.
- Limitar texturas e usar cache/instâncias para não duplicar a mesma geometria em várias posições.
- Evitar perda silenciosa de qualidade: informar quando o material de origem não for representável no formato de destino.

### 4B.8. Critérios de aceite específicos
1. Exportar uma peça real do MultiCAD como STL; importar no editor, confirmar dimensões em mm e orientar o eixo corretamente.
2. Importar a mesma peça em 3MF, comparar volume e dimensões com o STL, registrando diferenças de tolerância.
3. Criar uma skin de madeira procedural e outra a partir de textura PNG, aplicar ambas a instâncias da mesma peça e salvar na biblioteca.
4. Importar STL sem UV, gerar projeção adequada, aplicar normal map e rugosidade, exportar GLB e reabrir com acabamento preservado.
5. Inserir três instâncias do mesmo objeto na maquete em pavimentos distintos, usando skins diferentes e sem duplicar a geometria de origem.
6. Alterar a peça no MultiCAD, exportar novo STL e atualizar a maquete preservando posições/skins compatíveis; emitir aviso quando não puder mapear partes.
7. Importar pacote de objeto com textura ausente ou caminho inválido e obter relatório claro sem corromper a biblioteca.
8. Tentar importar um `.mcad` ou `.msuite` e obter recusa clara, com orientação para exportar STL/3MF.

## 4C. Módulo obrigatório — Gerador de Texturas (Skins)

### 4C.1. Definição e localização

O **Gerador de Texturas** é uma funcionalidade **nativa da Maquete 3D**, acessível pelo menu **Ferramentas > Gerador de Texturas** e pelos painéis **Materiais** do Editor de Objetos 3D e do Editor de Maquete. Não é necessário criar um terceiro aplicativo, conectar à internet nem instalar o MultiCNC. O módulo poderá funcionar em janela independente dentro do aplicativo.

Uma **textura** é uma imagem ou padrão aplicado a uma superfície; um **material/skin** reúne um ou mais mapas, parâmetros PBR, regras de escala e opções de aplicação. Um STL importado normalmente contém apenas triângulos, portanto precisará de projeção/UV para usar texturas 2D. Skins devem ser entidades **independentes das geometrias**, reaproveitáveis em diversos objetos.

### 4C.2. Requisitos funcionais — geração de texturas

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| **RFTX-001** | **Essencial** | Abrir um **Gerador de Texturas** próprio, disponível com ou sem objeto selecionado. |
| **RFTX-002** | **Essencial** | Criar texturas **procedurais** por parâmetros editáveis, com semente reproduzível, sem conexão à internet. |
| **RFTX-003** | **Essencial** | Oferecer padrões iniciais para madeira, pedra, mármore, concreto, tijolos, azulejos, pintura, metal e tecido. |
| **RFTX-004** | **Essencial** | Ajustar cor, paleta, ruído, veios, juntas, padrão de assentamento, frequência, variação, escala física e aleatoriedade conforme o material. |
| **RFTX-005** | **Essencial** | Criar uma **textura contínua (seamless/tileable)** com repetição sem emendas visíveis nos limites do ladrilho. |
| **RFTX-006** | **Essencial** | Importar foto ou imagem PNG/JPG/WEBP/TIFF, permitir recorte, rotação, correção simples de perspectiva, contraste e brilho. |
| **RFTX-007** | **Essencial** | Permitir transformar imagem importada em textura repetível, com pré-visualização da junção; oferecer correção manual de emendas. |
| **RFTX-008** | **Essencial** | Gerar e editar material PBR do tipo **metallic-roughness**: cor/base color, normal, rugosidade, metalicidade, oclusão ambiente e parâmetros de transparência/emissão quando pertinentes. |
| **RFTX-009** | **Essencial** | Estimar mapas de altura, normal e rugosidade a partir de imagens **como aproximação editável**, com aviso de que os resultados não são medições físicas. |
| **RFTX-010** | **Essencial** | Apresentar prévia do material em **esfera, cubo, parede, piso** e no objeto 3D selecionado, em iluminação controlada. |
| **RFTX-011** | **Essencial** | Ajustar escala real em milímetros/metros, repetição, offset, rotação, orientação, UV ou projeção triplanar, conforme o renderizador. |
| **RFTX-012** | **Essencial** | Permitir salvar, nomear, categorizar, etiquetar, duplicar, versionar e pesquisar skins em biblioteca própria. |
| **RFTX-013** | **Essencial** | Aplicar uma skin em faces, submalhas, paredes, pisos, tetos e objetos importados; permitir múltiplas skins no mesmo objeto. |
| **RFTX-014** | **Essencial** | Exportar **mapas PNG** e **pacote de material** autocontido (manifesto JSON, imagens e prévia) que possa ser importado na Maquete 3D. |
| **RFTX-015** | **Essencial** | Preservar skins ao salvar/reabrir a maquete e compartilhar o projeto com seus recursos vinculados, sem exigir diretórios locais externos. |
| **RFTX-016** | **Importante** | Trabalhar com resolução configurável de 512, 1024, 2048 e 4096 pixels, limitando o uso de VRAM e memória conforme o hardware. |
| **RFTX-017** | **Importante** | Criar grupos/camadas de mistura procedural, máscaras, gradientes, manchas, desgaste, sujeira e variação de cor por região. |
| **RFTX-018** | **Importante** | Produzir variantes por lote com sementes e parâmetros diferentes e comparar resultados antes de salvar. |
| **RFTX-019** | **Importante** | Definir mapeamento e materiais específicos por face ou por material ID ao aplicar skins em STL/3MF/OBJ/GLB. |
| **RFTX-020** | **Importante** | Exportar objeto com material compatível em **GLB/glTF**; relatar mapas que não forem suportados pelo formato ou renderizador. |
| **RFTX-021** | **Futuro** | Gerar texturas e variações com auxílio de **IA local opcional** a partir de descrição textual ou imagem de referência; a IA não será dependência para as funções essenciais. |
| **RFTX-022** | **Futuro** | Permitir IA remota opcional com consentimento explícito, aviso de envio de imagens/dados e tratamento das condições de uso. |
| **RFTX-023** | **Importante** | Permitir desfazer/refazer operações, salvar presets e reproduzir resultados a partir da mesma semente e configuração. |
| **RFTX-024** | **Essencial** | Funcionar integralmente sem MultiCNC, MultiCAD, MultiSuite, softwares de criação 3D externos ou conta online. |

### 4C.3. Interface sugerida

- **Painel esquerdo:** Biblioteca de materiais, categorias e presets (madeira, concreto, pedra, pintura, metal, tecido etc.).
- **Centro:** Visualização 2D dos mapas e prévia 3D alternável (esfera, cubo, parede, piso ou modelo carregado).
- **Painel direito:** Parâmetros procedurais, paleta, dimensões físicas, UV/projeção, canais PBR e opções de exportação.
- **Barra superior:** Novo, Abrir Imagem, Gerar, Tornar Contínua, Salvar Skin, Exportar Mapas, Aplicar ao Objeto.
- **Rodapé:** resolução, consumo estimado de memória, espaço de cor, estado de salvamento e avisos de compatibilidade.

### 4C.4. Formatos e parâmetros técnicos

- **Entrada:** PNG/JPG/WEBP/TIFF e pacotes de skin próprios; GLB/glTF e OBJ podem fornecer materiais existentes para adaptação. STL e 3MF entram via Editor de Objetos, não são formatos de textura.
- **Saída:** arquivos PNG por mapa; pacote próprio de skin com manifesto JSON e imagens; aplicação em materiais glTF 2.0 compatíveis.
- **Mapas PBR:** base color (sRGB), normal (linear), roughness/metallic (linear), AO (linear); altura/parallax e outros canais são internos ou dependentes de extensão, pois não fazem parte do material PBR básico do glTF.
- **Prévia:** iluminação e exposição configuráveis; exibir aviso quando a aparência no renderizador diferir do exportado.
- **Persistência:** identidade e versão de skin distintas das de objeto. Alterar a skin pode atualizar instâncias vinculadas ou criar uma variante, conforme escolha explícita.
- **Robustez:** validar imagens, limites de memória, licenças e caminhos; nunca executar código ou scripts a partir de arquivos importados.

### 4C.5. Fluxo de utilização

1. **Criar:** escolher preset procedural (por exemplo, mármore) ou carregar foto de revestimento.
2. **Gerar:** ajustar padrão, cor, medidas físicas, repetição e tornar contínuo.
3. **Compor PBR:** configurar mapa de cor, normais, rugosidade e demais propriedades visuais.
4. **Visualizar:** conferir repetição sobre parede/piso e objetos com diferentes iluminações.
5. **Publicar na biblioteca:** salvar a skin independente de qualquer objeto.
6. **Aplicar:** selecionar uma superfície da maquete ou objeto importado STL/3MF e atribuir a skin.
7. **Exportar/compartilhar:** empacotar a skin com recursos e metadados ou exportar objeto GLB com material compatível.

### 4C.6. Testes de aceitação

1. Em um computador **sem MultiCNC/MultiCAD instalado**, criar uma skin procedural de madeira, salvá-la e aplicá-la a uma parede da maquete.
2. Gerar material de azulejo com dimensões físicas de 300 × 600 mm e comprovar que a repetição na parede preserva essas medidas.
3. Importar uma imagem de mármore, torná-la contínua, gerar mapas auxiliares, salvar pacote de skin, fechar o programa e reimportar sem perder configurações.
4. Importar um STL de origem genérica sem UV, atribuir projeção triplanar ou gerar UV, aplicar a skin e exportar um GLB com aparência verificável em leitor compatível.
5. Aplicar a mesma skin a cinco objetos, trocar somente uma instância para uma variante e verificar que as outras quatro permanecem inalteradas.
6. Exportar PNG dos canais, conferir resoluções, nomes, espaços de cor e registrar perdas de materiais sem corromper o projeto.
7. Simular falta de textura ou de GPU compatível e verificar mensagens úteis, fallback disponível e preservação de arquivos já salvos.

## 5. Matriz de formatos de importação de mercado

**A classificação abaixo é prioridade de produto, não confirmação de implementação.** Preservação semântica depende do conteúdo do arquivo e das bibliotecas/conversores licenciados.

| Formato | Origem típica | CAD 2D | Maquete 3D | Estratégia / observações |
|---|---|---|---|---|
| **DWG** | AutoCAD e compatíveis | **Essencial** | **Essencial** | SDK CAD compatível ou conversor; objetos 2D podem exigir reconhecimento de paredes |
| **DXF** | AutoCAD, LibreCAD, outros CAD | **Essencial** | **Essencial** | Leitura vetorial e de layers, blocos e cotas; extração 3D assistida |
| **IFC / IFCZIP** | Revit, Archicad e ferramentas BIM | Importante | **Essencial** | IFC2x3, IFC4, IFC4.3; preserva mais semântica arquitetônica |
| **PDF vetorial** | Pranchas de projeto | **Essencial** | Importante | Extração da geometria quando presente; conferir unidade/escala |
| **PDF digitalizado** | Digitalização de desenhos | Referência/calibração | Referência/calibração | Não é geometria CAD; requer vetorização ou reconstrução assistida |
| **SVG** | CAD vetorial, ilustração | **Essencial** | Importante | Geometria 2D; exige verificação de unidade e classificação |
| **PNG / JPG / TIFF** | Imagens de planta | **Essencial como referência** | Importante como referência | Escala ajustada manualmente; reconhecimento automático é módulo futuro |
| **DGN** | Bentley MicroStation | Importante | Importante | Requer biblioteca/conversor compatível |
| **RVT** | Autodesk Revit | Futuro / via IFC | Importante, via adaptador | Proprietário; integração direta depende de SDK/licença; fallback IFC |
| **SKP** | SketchUp | Futuro / extração 2D | Importante, via adaptador | Proprietário; pode ser necessário SDK ou conversão |
| **OBJ / MTL** | Modeladores 3D | Não prioritário | Importante | Malha e materiais; não garante semântica de parede/porta |
| **glTF / GLB** | Visualização 3D e web | Não prioritário | Importante | Malha, cena e materiais; bom intercâmbio de visualização |
| **FBX / DAE / 3DS** | DCC e visualização 3D | Não prioritário | Importante | Intercâmbio de cena; importadores específicos |
| **STL (ASCII/binário)** | MultiCAD, impressão 3D e malhas | Não prioritário | **Essencial no editor de objetos** | Apenas malha: criar UV e aplicar skins no editor; exigir unidade quando ausente |
| **3MF** | MultiCAD / MultiSlicer | Não prioritário | **Essencial no editor de objetos** | Malha e unidades; preservar aparências disponíveis, sem prometer PBR completo |
| **.mcad** | Projeto nativo MultiCAD | Não suportado | Não suportado | Arquivo de projeto de sistema externo; exportar STL/3MF no MultiCAD |
| **.msuite** | Projeto integrado MultiSuite | Não suportado | Não suportado | Arquivo de projeto de sistema externo; exportar STL/3MF |
| **STEP / STP** | CAD sólido e industrial | Futuro | Futuro | Geometria sólida; sem objetos arquitetônicos garantidos |

### Regras sobre qualidade dos formatos
- Não declarar uma malha OBJ ou STL como modelo BIM editável; preservar sua natureza de malha.
- Não supor que linhas de DWG/DXF são paredes: identificar por layers, espessuras, padrões, blocos ou confirmação manual.
- Não assumir que qualquer PDF contém vetores: separar tratamento de PDF vetorial e rasterizado.
- Quando IFC já apresentar `IfcWall`, `IfcDoor`, `IfcWindow`, `IfcSlab` e `IfcBuildingStorey`, preservar as informações compatíveis.
- Permitir adaptação a novas versões de formatos sem alterar o motor central.

## 6. Requisitos funcionais — Motor de Importação e Interoperabilidade

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RFI-001 | Essencial | Reconhecer formato e versão real do arquivo, sem confiar apenas na extensão. |
| RFI-002 | Essencial | Permitir seleção de arquivo único ou lote com múltiplas plantas e referências. |
| RFI-003 | Essencial | Exibir informações prévias: formato, versão, tamanho, folhas, layers, unidades, extensões e pavimentos detectados. |
| RFI-004 | Essencial | Configurar unidades (mm, cm, m, polegadas, pés), fator de escala, rotação, origem e sistema de coordenadas. |
| RFI-005 | Essencial | Importar e mapear linhas, polilinhas, curvas, arcos, círculos, textos, cotas, hachuras, layers, blocos e referências na medida do suporte. |
| RFI-006 | Essencial | Converter entidades para um modelo interno canônico, conservando ID de origem, geometria e metadados disponíveis. |
| RFI-007 | Essencial | Informar objetos importados, ignorados, convertidos com aproximação e erros por arquivo. |
| RFI-008 | Essencial | Permitir selecionar layers e entidades a importar, além de ignorar anotações, mobiliário ou referências. |
| RFI-009 | Essencial | Manter cópia não modificada do arquivo-fonte e registrar caminho, hash, data e versão do conversor. |
| RFI-010 | Essencial | Detectar escala ausente, unidades inconsistentes, coordenadas extremas, geometria aberta e sobreposição problemática. |
| RFI-011 | Essencial | Permitir corrigir manualmente reconhecimento e associação de objetos antes de gerar a maquete. |
| RFI-012 | Essencial | Não executar macros, scripts nem links externos embutidos nos arquivos importados. |
| RFI-013 | Importante | Disponibilizar adaptadores instaláveis para formatos proprietários com controle de licença e versão. |
| RFI-014 | Importante | Executar importação em lote por linha de comando, produzindo relatórios verificáveis. |
| RFI-015 | Importante | Comparar a origem reimportada por ID e geometria e apresentar inclusões, alterações e exclusões. |
| RFI-016 | Importante | Preservar referências externas ou sinalizar arquivos ausentes e solicitar sua localização. |
| RFI-017 | Importante | Permitir importar cortes e fachadas como documentos de apoio à determinação de alturas. |
| RFI-018 | Futuro | Criar perfis de importação por fornecedor, padrão de layers e tipo de projeto. |
| RFI-019 | Essencial | Incluir importador STL/3MF no editor 3D com seleção de unidades, orientação, inspeção de malha e vínculo da origem MultiCAD. |
| RFI-020 | Essencial | Importar, gerar, visualizar e atribuir skins e materiais com pacote reutilizável, independente da malha. |
| RFI-021 | Importante | Recusar arquivos de projeto do MultiCAD/MultiSuite (`.mcad`/`.msuite`) com orientação para exportar STL/3MF. |

### Fluxo obrigatório de importação
**Selecionar arquivo(s) → Identificar e validar → Pré-visualizar → Definir unidades/escala → Mapear layers e objetos → Associar pavimentos → Converter → Revisar advertências → Confirmar importação → Salvar vínculo de origem.**

## 7. Modelo arquitetônico interno e comunicação entre aplicativos

O projeto deve ter um modelo interno que não dependa de DWG, RVT ou outro formato específico.

- Projeto: ID, nome, unidades, sistema de coordenadas, versões e referências externas.
- Pavimento: ID, nome, cota base, pé-direito, espessura de laje e transformação XY.
- Objeto: ID persistente, classe (parede, porta, janela etc.), geometria, layer, propriedades, vínculos e origem.
- Material: ID, nome, parâmetros físicos básicos e propriedades visuais 3D.
- Origem de importação: arquivo, formato, versão, hash, ID externo, adaptador e data.
- Regras de interoperabilidade: serialização versionada em JSON/arquivo nativo, sem perda das dimensões reais.
- Modelo 3D: armazenar transformações, modificações e materiais próprios sem sobrescrever automaticamente a planta 2D.

### Exemplo simplificado
```json
{
  "schema_version": "1.0",
  "project_id": "arquitetura-001",
  "units": "mm",
  "floors": [
    {"id": "terreo", "elevation_mm": 0, "wall_height_mm": 2800},
    {"id": "piso1", "elevation_mm": 3000, "wall_height_mm": 2800}
  ],
  "objects": [
    {
      "id": "wall-001", "type": "wall", "floor_id": "terreo",
      "start_mm": [0,0], "end_mm": [5000,0],
      "thickness_mm": 150, "height_mm": 2800,
      "source": {"format": "DWG", "external_id": "ABC123"}
    }
  ]
}
```

## 8. Recursos e componentes técnicos previstos

**Camada comum de geometria:** vetores 2D/3D, tolerância numérica, interseções, polígonos, offsets, transformações, testes de fechamento, índices espaciais e colisões.

**Aplicativo CAD 2D:** interface desktop, viewport, mouse/teclado, comandos, gerenciamento de objetos, undo/redo, layers, cotas, biblioteca de símbolos e impressão.

**Aplicativo Maquete 3D:** gerador de malhas/volumes a partir das plantas, viewport de montagem, câmera de trabalho, materiais, iluminação de prévia e exportadores de modelo. Incluir **Editor de Objetos 3D**, importação genérica STL/3MF/GLB/OBJ, **Gerador e Editor de Texturas (Skins) próprio e offline**, biblioteca de objetos e materiais, UV/projeção de texturas, edição PBR/procedural, gizmos de transformação e instanciamento com âncoras por pavimento/superfície.

**Importadores com adaptadores:**
- DXF: motor próprio limitado ao subconjunto especificado ou biblioteca consolidada (p. ex., ezdxf via serviço Python).
- DWG/DGN: avaliar SDK ODA Drawings ou conversor externo compatível e suas licenças; não prometer cobertura integral sem SDK testado.
- IFC: avaliar IfcOpenShell e validar versões/categorias efetivamente suportadas.
- RVT/SKP: plugins licenciados, SDKs ou conversão para IFC/DXF/glTF; tratar dependências de aplicação instalada.
- PDF/SVG/imagens: bibliotecas de leitura vetorial/raster, mais módulo de calibração e revisão.
- Malhas 3D: importadores STL (ASCII/binário), 3MF, OBJ, glTF/GLB, FBX e DAE, preservando somente atributos efetivamente presentes; OBJ/GLB para materiais; STL exige materialização posterior.
- MultiCNC/MultiCAD: **não são componentes do produto Maquete 3D**. O usuário pode exportar STL/3MF no aplicativo de origem e importar via diálogo comum; arquivos `.mcad` e `.msuite` não são lidos. Não distribuir dependências dessas aplicações no pacote.

**Plataformas propostas:** Windows e Linux; núcleo independente da interface. Lazarus/Free Pascal pode hospedar a interface e invocar bibliotecas/serviços de conversão isolados. Compatibilidade real por SO, arquitetura e licença deverá ser homologada.

## 9. Requisitos não funcionais

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

## 10. Critérios de aceitação (testes mínimos)

1. Importar um DXF com layers, blocos, polilinhas, cotas e textos; comparar coordenadas e dimensões com o original.
2. Importar um DWG real de origem AutoCAD usando o adaptador escolhido; abrir com escala correta, emitir relatório sobre entidades incompatíveis e não alterar o original.
3. Importar PDF vetorial e calibrar escala por uma medida conhecida; distinguir PDF digitalizado, sem prometer que ele vira CAD automaticamente.
4. Importar IFC com dois pavimentos e reconhecer pavimentos, paredes, portas, janelas e lajes onde essas entidades existem.
5. Importar dois DXF separados (térreo e superior), alinhá-los e montar uma maquete com níveis parametrizados.
6. Importar um glTF/GLB, OBJ ou STL como geometria de referência, sem classificar automaticamente suas faces como objetos BIM.
7. Alterar uma parede na planta 2D, reimportar e revisar diferenças antes de atualizar a maquete 3D.
8. Testar arquivos com unidade desconhecida, referência ausente, geometria aberta e arquivo inválido; exigir mensagens úteis e proteção de dados.
9. Verificar os relatórios de perdas (objetos ignorados, atributos descartados, aproximações geométricas) e a possibilidade de corrigir manualmente.
10. Demonstrar que documentos com diferentes pavimentos e origens podem ser organizados sem perder coordenadas ou relações.
11. Criar, importar, editar, salvar e inserir objetos 3D reutilizáveis na maquete, preservando dimensões e materiais.
12. Regenerar a maquete após revisão de planta, preservando instâncias manuais e emitindo aviso para âncoras inválidas.
13. Importar STL/3MF exportado pelo MultiCAD; conferir medidas, corrigir orientação/eixos e garantir geração de UV quando necessário.
14. Criar/importar duas skins para uma única malha, salvar variantes independentes, exportar GLB e inserir na maquete sem perda de material suportado.
15. Atualizar uma malha de origem MultiCAD preservando skins e instâncias quando o remapeamento for possível, informando conflitos.
16. Instalar e executar Maquete 3D em máquina sem MultiCNC/MultiCAD, gerar skins localmente e importar STL externo.
17. Criar texturas procedurais contínuas, salvar presets e reproduzir mapa por semente; aplicar em paredes/pisos e exportar materiais.

## 11. Planejamento por entregas

### Entrega A — CAD 2D operacional
Viewport, ferramentas de desenho preciso, camadas, paredes, portas, janelas, cotas, salvamento, importação DXF, PDF vetorial/SVG/imagens e exportação de documentação.

### Entrega B — Importação CAD de mercado
Homologar mecanismo DWG; criar assistente de importação, mapeamento de layers/entidades e relatório de compatibilidade. Acrescentar DGN conforme biblioteca selecionada.

### Entrega C — Maquete 3D automática
Criar modelo de intercâmbio, associar pavimentos, gerar paredes/vãos/lajes e reconstrução a partir de DXF/DWG e projeto nativo.

### Entrega D — Editor de Objetos 3D e biblioteca
Criar e modificar objetos por primitivas, importar **STL/3MF de qualquer origem** e GLB/glTF/OBJ, preparar UV, criar/importar skins e materiais PBR/procedurais por **gerador próprio offline**, montar biblioteca de objetos e variantes de skins, instanciar na maquete, posicionar em pavimentos/superfícies e preservar objetos em atualizações da planta.

### Entrega D2 — Gerador próprio de Skins (obrigatório)
Gerar texturas procedurais offline, importar fotos, torná-las contínuas, gerar/editar mapas PBR, pré-visualizar em superfícies e modelos, salvar skins em biblioteca própria, aplicar a objetos ou superfícies e exportar pacotes/autores. Homologar instalação sem MultiCNC/MultiCAD.

### Entrega E — BIM e visualização de montagem
Importação IFC, objetos semânticos e hierarquia de pavimentos; materiais, câmera de trabalho e iluminação básica de prévia. Importar malhas 3D de referência. **Renderização ultrarrealista pertence ao Criador de Cenas independente.**

### Entrega F — Interoperabilidade avançada e modelagem 3D avançada
Adaptadores SKP/RVT, atualização incremental, geração assistida de skins por IA, interpretações assistidas de plantas digitalizadas, exportação BIM, edição avançada de malhas, objetos paramétricos de biblioteca e validações avançadas.

**Observação:** suporte a DWG é requisito essencial do produto, embora sua homologação possa ocorrer após o motor DXF; a disponibilidade não será anunciada antes de funcionar em arquivos de teste reais.

## 12. Fontes técnicas de referência

- Autodesk — formatos de importação do AutoCAD: https://www.autodesk.com/br/support/technical/article/caas/sfdcarticles/sfdcarticles/PTB/What-file-formats-can-AutoCAD-import.html
- buildingSMART — Industry Foundation Classes: https://www.buildingsmart.org/standards/bsi-standards/industry-foundation-classes/
- Open Design Alliance — Drawings SDK (DWG/DGN): https://www.opendesign.com/products/drawings
- Autodesk — Revit e IFC: https://www.autodesk.com/support/technical/article/Revit-to-IFC-and-back-to-Revit/
- Khronos — glTF Registry: https://registry.khronos.org/glTF/
- FreeCAD — componentes adicionais / conversores DWG: https://github.com/FreeCAD/FreeCAD-documentation/blob/main/wiki/Installing_additional_components.md
- Repositório MultiCNC, branch `fila` — README da suíte: https://github.com/marcelomaurin/multicnc/blob/fila/README.md
- MultiCAD, branch `fila` — `.mcad`, STL e 3MF: https://github.com/marcelomaurin/multicnc/blob/fila/multicad/README.md

**Nota:** **MultiCNC/MultiCAD não integra o pacote e não é dependência de instalação ou execução.** Os modelos são recebidos por arquivos exportados. Esta especificação descreve o comportamento desejado e as alternativas técnicas. Ela não afirma que importadores, licenças ou compatibilidade com formatos proprietários já estejam implementados.


---

## 13. Aplicativo independente C — Criador de Cenas Realistas 3D

### 13.1. Descrição
O Criador de Cenas abre uma **maquete 3D preparada**, com todos os objetos, materiais e skins já associados, e permite adicionar efeitos visuais e dinâmicos. O resultado esperado são **imagens realistas, vídeos, visitas virtuais e experiências navegáveis**. A maquete original permanece vinculada e não é alterada diretamente. A cena utiliza um arquivo nativo próprio com referências à maquete-base e aos recursos externos.

### 13.2. Requisitos funcionais

| ID | Prioridade | Descrição |
|---|---|---|
| RFC-001 | Essencial | Importar uma maquete completa com pavimentos, geometria, componentes, materiais, UVs, skins e IDs persistentes. |
| RFC-002 | Essencial | Abrir/salvar projetos de cena com vínculo à versão da maquete original. |
| RFC-003 | Essencial | Criar câmeras com posição, orientação, projeção, campo de visão, distância focal, foco e profundidade de campo. |
| RFC-004 | Essencial | Posicionar câmeras e definir enquadramento com pré-visualização interativa. |
| RFC-005 | Essencial | Criar trajetórias de câmera e animações por keyframes numa linha do tempo. |
| RFC-006 | Essencial | Configurar luz solar, horário, orientação norte, céu e luzes artificiais. |
| RFC-007 | Essencial | Importar materiais PBR da maquete e respeitar os mapas de textura e coordenadas UV compatíveis. |
| RFC-008 | Essencial | Gerar imagens fotorrealistas com controle de qualidade, resolução e amostras. |
| RFC-009 | Essencial | Renderizar sequência de quadros e exportar vídeo com FPS e resolução configuráveis. |
| RFC-010 | Importante | Inserir personagens 3D com animações de caminhada, espera e trajetórias. |
| RFC-011 | Importante | Animar portas e outros elementos articulados por pivôs e limites configurados. |
| RFC-012 | Importante | Simular água com normal maps, ondulações, reflexão e refração aproximada ou física conforme modo de render. |
| RFC-013 | Importante | Simular movimento de árvores e plantas por vento e oscilação de folhas. |
| RFC-014 | Importante | Controlar chuva, neblina, nuvens e efeitos atmosféricos quando suportados. |
| RFC-015 | Importante | Oferecer passeio virtual em primeira pessoa e vista aérea. |
| RFC-016 | Importante | Aceitar estados de luzes e interruptores vindos da disciplina elétrica vinculada, quando fornecidos. |
| RFC-017 | Importante | Reconciliar revisão de maquete sem perder câmeras, animações e efeitos independentes. |
| RFC-018 | Importante | Disponibilizar biblioteca de pessoas, vegetação, ambientes e efeitos, com licenças e atribuições. |
| RFC-019 | Importante | Produzir prévia rápida e render final de maior fidelidade como modos distintos. |
| RFC-020 | Futuro | Renderizar panoramas 360°, estereoscopia e visitas em realidade virtual. |

### 13.3. Regras
- A qualidade final depende dos modelos, iluminação, texturas, hardware e motor de renderização: **ultrarrealismo é meta de qualidade, não garantia automática**.
- A camada elétrica é uma **entrada opcional**, usada como referência de pontos de luz e estados; o Criador de Cenas **não valida segurança elétrica**.
- Materiais criados no Gerador de Skins poderão ser reinterpretados pelo renderizador, registrando incompatibilidades de efeitos avançados.
- O Criador de Cenas deve funcionar sem instalar MultiCNC/MultiCAD ou Elétrica 3D.

## 14. Aplicativo independente D — Elétrica 3D

### 14.1. Descrição do projeto
O **Elétrica 3D** será um **programa próprio**, com instalador, executável, menus, arquivos de projeto, biblioteca e ciclo de versões independentes. **Não é um plugin da Maquete 3D.** Ele se conecta à Maquete 3D por um contrato de troca de dados: importa a edificação (preferencialmente em formato estruturado preservando IDs, geometria e pavimentos), oferece ferramentas de instalação elétrica e devolve uma **disciplina elétrica vinculada**, capaz de ser exibida como sobreposição na maquete.

Ele deve ser útil para projetar e revisar a distribuição espacial de infraestrutura elétrica. Os cálculos e avisos assistidos não substituem projeto, responsabilidade técnica ou inspeção por profissional habilitado conforme normas e regras vigentes.

### 14.2. Requisitos funcionais do Elétrica 3D

| ID | Prioridade | Descrição |
|---|---|---|
| RFE-001 | Essencial | Criar, abrir, salvar e versionar arquivo próprio de projeto elétrico. |
| RFE-002 | Essencial | Importar a maquete arquitetônica por arquivo/intercâmbio, respeitando coordenadas, unidades, níveis e IDs de objetos. |
| RFE-003 | Essencial | Trabalhar com a arquitetura em referência **somente leitura**, sem sobrescrever a maquete-base. |
| RFE-004 | Essencial | Exibir, ocultar e isolar pavimentos, paredes, lajes, forros e elementos estruturais. |
| RFE-005 | Essencial | Inserir tomadas com posição, altura de instalação, orientação, classificação e propriedades. |
| RFE-006 | Essencial | Inserir interruptores e vincular logicamente os pontos comandados. |
| RFE-007 | Essencial | Inserir luminárias, pontos de luz e suas cargas declaradas. |
| RFE-008 | Essencial | Inserir quadros elétricos, caixas de passagem e pontos de conexão. |
| RFE-009 | Essencial | Desenhar rotas de eletrodutos/conduítes entre pontos usando segmentos e curvas 3D. |
| RFE-010 | Essencial | Definir diâmetro, material, ocupação, suporte e instalação aparente/embutida dos conduítes. |
| RFE-011 | Essencial | Inserir eletrocalhas, leitos e perfilados quando necessários. |
| RFE-012 | Essencial | Definir condutores/cabos com identificação, seção nominal, material, isolação, função e circuito. |
| RFE-013 | Essencial | Agrupar pontos e condutores em circuitos e identificar o quadro de origem. |
| RFE-014 | Essencial | Calcular comprimentos geométricos de rotas e permitir margens técnicas parametrizadas. |
| RFE-015 | Essencial | Associar elementos elétricos a superfícies/ambientes/pavimentos por âncoras persistentes. |
| RFE-016 | Essencial | Exportar camada elétrica 3D com metadados, IDs e vínculo à maquete de referência. |
| RFE-017 | Essencial | Reimportar uma revisão arquitetônica, comparar mudanças e sinalizar itens afetados sem apagar automaticamente instalações. |
| RFE-018 | Essencial | Exibir erros de conexão, itens órfãos e roteamentos interrompidos. |
| RFE-019 | Importante | Identificar interferências entre eletrodutos, lajes, vigas, portas, hidráulica e outros elementos disponíveis. |
| RFE-020 | Importante | Propor percursos assistidos respeitando zonas proibidas e obstáculos; exigir confirmação. |
| RFE-021 | Importante | Apoiar estimativas de cargas, divisão de circuitos, ocupação de eletrodutos e quadros com parâmetros configuráveis. |
| RFE-022 | Importante | Gerar diagramas unifilares e identificação de pontos/circuitos. |
| RFE-023 | Importante | Gerar quantitativos de tomadas, interruptores, pontos de luz, caixas, eletrodutos, cabos e acessórios. |
| RFE-024 | Importante | Exportar listas e relatórios em CSV, PDF e formatos estruturados para orçamento e revisão. |
| RFE-025 | Importante | Oferecer visualizações por circuito, tensão, categoria, pavimento e estado de validação. |
| RFE-026 | Importante | Permitir biblioteca de componentes configuráveis com dimensões, símbolos e dados de fabricantes, sem exigência de marcas específicas. |
| RFE-027 | Importante | Disponibilizar verificações normativas configuráveis e registrar sua versão, sem declaração automática de conformidade total. |
| RFE-028 | Importante | Suportar comparação visual e por IDs entre revisão elétrica anterior e posterior. |
| RFE-029 | Futuro | Trocar dados BIM/MEP em IFC, quando a compatibilidade semântica for homologada. |
| RFE-030 | Futuro | Exportar relações entre interruptores e luminárias para animação de cenas, sem exportar detalhes elétricos sensíveis desnecessários. |

### 14.3. Interface mínima do Elétrica 3D
- **Menus próprios:** Arquivo, Editar, Exibir, Inserir, Circuitos, Roteamento, Verificação, Relatórios, Ferramentas e Ajuda.
- **Esquerda:** árvore de pavimentos, quadros, circuitos, grupos e disciplinas vinculadas.
- **Centro:** maquete arquitetônica com navegação 3D, modo corte, vista superior/ortográfica e seleção de rotas e equipamentos.
- **Direita:** propriedades do elemento elétrico selecionado.
- **Rodapé:** status de unidades, comprimento da rota, circuito, advertências e revisão-base.
- **Fluxo:** Abrir maquete → Definir quadros → Inserir pontos → Criar conduítes → Roteamento de cabos → Revisar interferências → Quantificar → Publicar disciplina elétrica.

### 14.4. Separação de dados e responsabilidade
- **Maquete 3D:** arquitetura e objetos de decoração (fonte da geometria arquitetônica).
- **Elétrica 3D:** objetos elétricos, circuitos, conexões, rotas, validações e documentação (fonte de verdade elétrica).
- **Criador de Cenas:** estados e representações visuais de luminárias, quando disponibilizados pela camada elétrica (sem cálculos normativos).
- Uma modificação no elétrico **não altera paredes, lajes, portas e janelas** na Maquete 3D. Alterações que exijam rasgos, furos, shafts ou aberturas devem criar **solicitações de coordenação** ou propostas para aprovação no modelo arquitetônico.
- O Elétrica 3D deverá ser **instalável e executável sozinho**; para produzir instalações em uma edificação, recebe arquivo ou pacote arquitetônico compatível, sem exigir que a Maquete 3D esteja executando no mesmo computador.

## 15. Contrato de integração entre os cinco aplicativos

### 15.1. Princípios
1. Compartilhar arquivos/pacotes versionados, não bancos internos de outros aplicativos.
2. Utilizar **IDs estáveis**, unidades explícitas, eixos e matrizes de transformação em cada camada.
3. **Não sobrescrever o arquivo do outro software**: cada aplicativo produz seu projeto e arquivos derivados próprios.
4. Permitir revisão offline por arquivo, com sincronização opcional futura.
5. Identificar **versão da origem**, hash e adaptador de conversão.
6. Distinguir geometria de visualização (GLB/STL/OBJ) de propriedades semânticas (paredes, tomadas, circuitos, ancoragem): glTF/GLB sozinho não garante informações MEP completas.

### 15.2. Pacotes de interoperabilidade propostos

| Pacote lógico | Origem | Destino | Conteúdo |
|---|---|---|---|
| Tarefa | Planejador | Qualquer aplicativo | Tarefa, aplicativo responsável, entradas, parâmetros, prazo e dependências |
| Retorno de tarefa | Qualquer aplicativo | Planejador | Arquivo produzido, situação, pendências e alertas |
| Vínculo objeto–textura | Planejador | Maquete 3D | Tarefa, objeto, textura e destino (objeto inteiro ou face) |
| Arquitetura 2D | CAD 2D | Maquete 3D | Pavimentos, paredes, portas, janelas, cotas e relações |
| Maquete arquitetônica | Maquete 3D | Elétrica 3D | Superfícies, volumes, níveis, IDs de objeto, transformações |
| Disciplina elétrica | Elétrica 3D | Maquete 3D | Condutos, cabos, caixas, tomadas, luminárias, circuitos e âncoras |
| Cena visual | Maquete 3D | Criador de Cenas | Geometria, materiais, skins, objetos e seus pivôs |
| Estado de iluminação | Elétrica 3D (opcional) | Criador de Cenas | IDs de pontos de luz, interruptores e comandos; sem pretensão de validar elétrica |
| Modelo elétrico para simulação | Elétrica 3D | SimuEletrica | Topologia (nós/arestas), circuitos, fases, condutores, fontes, equipamentos, proteções, modelos e links com malha 3D |
| Cenário de simulação | SimuEletrica | SimuEletrica | Perfil de carga, condições iniciais, falhas injetadas, tempo, versão do solver e hipóteses |
| Resultados simulados | SimuEletrica | Elétrica 3D / Maquete 3D (visualização opcional) | Correntes, tensões, temperaturas estimadas, disparos, alertas, segmentos e instantes, sem modificar projeto-fonte |

**Formato recomendado:** pacote nativo de intercâmbio com manifest JSON versionado + malhas GLB + texturas + propriedades/IDs. **IFC** pode ser oferecido em paralelo para BIM conforme homologação. A nomenclatura final das extensões nativas deve ser definida na implementação, evitando conflito com `.msuite` do MultiSuite.

### 15.3. Exemplo conceitual do vínculo elétrico
```json
{
  "schema_version": "1.0",
  "discipline": "electrical",
  "project_id": "eletrica-001",
  "architecture_ref": {
    "project_id": "maquete-001",
    "revision": "rev-008",
    "hash": "sha256-da-versao-validada"
  },
  "units": "mm",
  "objects": [
    {
      "id": "tomada-101",
      "type": "socket",
      "floor_id": "terreo",
      "anchor": {"host_id": "parede-12", "offset_mm": [1200, 0, 300]},
      "circuit_id": "circuito-01"
    }
  ]
}
```

## 16. Critérios de aceitação da expansão

### 16.1. Elétrica 3D
1. Instalar o Elétrica 3D sem Maquete 3D ou MultiCNC instalados; abrir um pacote arquitetônico válido.
2. Importar maquete com dois pavimentos preservando escala, coordenadas e alinhamentos.
3. Inserir tomadas, interruptores, quadros e pontos de luz associados a paredes e níveis.
4. Traçar eletrodutos 3D e cabos associados a circuitos, calculando comprimentos e quantitativos.
5. Produzir relatório de conflitos com lajes/vigas e de pontos sem conexão.
6. Exportar disciplina elétrica e abri-la sobreposta na Maquete 3D, mantendo IDs e posições.
7. Mudar a posição de uma parede no arquivo da Maquete 3D; reimportar, detectar o impacto e exigir confirmação antes de reposicionar ou desconectar elementos.
8. Salvar e reabrir o projeto elétrico sem perda de circuitos, rotas e vínculos.
9. Gerar relatório claro das verificações e marcar itens pendentes de validação profissional.

### 16.2. Criador de Cenas
1. Importar uma maquete com objetos STL convertidos e skins PBR.
2. Inserir câmera, realizar percurso e renderizar sequência com frames e configuração repetíveis.
3. Demonstrar pessoa caminhando, vegetação movida por vento, água animada e porta abrindo.
4. Renderizar cena diurna e noturna, com luzes artificiais.
5. Reabrir cena e manter vínculos de objetos, materiais e animações.
6. Opcionalmente importar estados de luminárias publicados pelo Elétrica 3D, preservando sua separação funcional.

## 17. Entregas adicionais e dependências

| Entrega | Aplicativo | Pré-requisito de integração | Resultado |
|---|---|---|---|
| Q — Planejador | Planejador | Contrato de tarefa (seção 19.5) | Tarefas em grafo, Gantt, vínculos com aplicativos e objetos |
| G — Cenas iniciais | Criador de Cenas | Maquete exportável | Câmeras, iluminação e render estático |
| H — Cenas dinâmicas | Criador de Cenas | G + objetos com pivô | Pessoas, vento, água, portas e vídeo |
| I — Elétrica básica | Elétrica 3D | Contrato de maquete e importador | Pontos, quadros, eletrodutos e cabos |
| J — Circuitos e relatórios | Elétrica 3D | I | Circuitos, quantitativos, diagramas e conflitos |
| K — Coordenação 3D | Maquete 3D + Elétrica 3D | J + IDs estáveis | Sobreposição, revisões e solicitações de alteração |
| L — Interop iluminação | Elétrica 3D + Criador de Cenas | H + J | Estados de luminárias para simulações visuais |
| M — SimuEletrica inicial | SimuEletrica | J + contrato da disciplina elétrica | Grafo elétrico, cargas, perfis, fluxo de potência e queda de tensão |
| N — Proteção e falhas | SimuEletrica | M + modelos e parâmetros de dispositivos | Curtos, sobrecargas, disparos e cenários comparáveis |
| O — Térmica e visualização 3D | SimuEletrica | N + rotas 3D, cabos e dados térmicos | Temperaturas estimadas, evolução temporal e mapa de calor por segmento |
| P — RLC, qualidade e transitórios | SimuEletrica | O + motor especializado | Efeitos capacitivos/indutivos, harmônicos, chaveamento e estudo de interferência conduzida |

**Normas e responsabilidade técnica:** consultar e aplicar a versão vigente das normas ABNT e dos requisitos legais aplicáveis, em particular às instalações elétricas de baixa tensão e, quando pertinente, a edificações especiais. Verificações automáticas serão assistivas e testadas, **não equivalem a aprovação ou assinatura de projeto elétrico**.

**Estado:** todos os requisitos nesta versão são especificações de produto. A existência de funções nos softwares externos não implica que a integração já esteja implementada.

---

## 18. Aplicativo independente E — SimuEletrica

### 18.1. Descrição do projeto

**Nome:** SimuEletrica — Simulador de Instalações e Sistemas Elétricos 3D.  
**Objetivo:** receber os dados arquitetônicos e principalmente os dados de circuitos e componentes publicados pelo **Elétrica 3D**, construir um modelo matemático verificável, aplicar cenários de operação e falha, exibir grandezas elétricas e térmicas na rede e sobre as rotas de cabos na maquete.  
**Natureza:** software independente com executável, instalador, configurações, projeto nativo e relatórios próprios. O Elétrica 3D, a Maquete 3D e o MultiCNC **não integram seu instalador**. A abertura do pacote elétrico deve ser suficiente para operar offline, desde que dados e geometrias necessários acompanhem a exportação.

### 18.2. Requisitos funcionais — núcleo e carga

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

### 18.3. Requisitos funcionais — falhas e proteção

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

### 18.4. Requisitos funcionais — capacitância, indutância e interferências

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

### 18.5. Requisitos funcionais — aquecimento e mapa térmico

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

### 18.6. Requisitos funcionais — ferramentas e resultados

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

### 18.7. Interface mínima do SimuEletrica

- **Menu Arquivo:** abrir projeto, importar elétrica, salvar cenário, exportar resultados.
- **Painel esquerdo:** pavimentos, quadros, fontes, circuitos, dispositivos, cenários, sondas e avisos.
- **Área central:** abas **Maquete Elétrica 3D**, **Diagrama Elétrico/Unifilar**, **Osciloscópio**, **Mapa de Calor** e **Comparação**.
- **Painel direito:** propriedades da carga/proteção/condutor e resultados do ponto selecionado.
- **Barra inferior:** estado do solver, instante, convergência, faltas ativas, modo de análise e precisão/validade do cálculo.
- **Barra de simulação:** preparar, validar entrada, iniciar, pausar, avançar instante, reiniciar e gerar relatório.
- **Cores do mapa:** escala configurável com legenda numérica. Nunca usar cor isoladamente para indicar risco; apresentar unidade, limite e rótulo.

### 18.8. Modelo de dados e intercâmbio

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

### 18.9. Motores de simulação — alternativas técnicas

- **Análise de rede e falhas:** motor de fluxo de potência em rede de baixa tensão, com implementação própria verificada ou integração como serviço isolado com **OpenDSS** para estudos de rede, faltas, harmônicos e perfis temporais. Validar adequação às topologias internas de edifícios e às proteções específicas.
- **Relés, circuitos RLC e transitórios:** integrar **ngspice** por API/processo ou outro solver de circuito validado. Modelos e licenças serão avaliados antes da distribuição.
- **Aquecimento e capacidade de cabo:** implementar solver térmico específico com tabelas técnicas e resistência térmica, permitindo evolução de temperatura e correções de agrupamento/instalação. Em fase avançada, avaliar acoplamento com malha térmica/FEA.
- **EMI tridimensional:** manter para fase posterior com solver de campos eletromagnéticos apropriado e ensaios de verificação.
- **Interface:** Lazarus/Free Pascal pode hospedar visualizador, UI e orquestração; solvers podem executar como processos ou bibliotecas multiplataforma isoladas. Desempenho e licença deverão ser homologados para Windows e Linux.

### 18.10. Requisitos não funcionais específicos

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

### 18.11. Testes de aceitação específicos

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

### 18.12. Plano de entregas do SimuEletrica

| Entrega | Escopo | Aceite |
|---|---|---|
| S1 — Núcleo | Importação, grafo, fontes, cargas e cálculo estacionário | Tensões/correntes/perdas conferidas contra casos conhecidos |
| S2 — Proteção | Sobrecarga, faltas, disjuntor, fusível e relés | Curvas e eventos reproduzíveis por cenário |
| S3 — Térmica | Resistência dependente de temperatura, modelo térmico e mapa 3D | Valores rastreáveis, legenda e alertas calibrados |
| S4 — Qualidade | RLC, chaveamento, harmônicos e análise de resposta temporal | Casos referência por solver e tipo de estudo |
| S5 — Avançado | EMI conduzida detalhada, campos 3D, automação de cenários | Dependente de solver e dados físicos homologados |

### 18.13. Normas e responsabilidade técnica

- **ABNT NBR 5410:2004 (versão corrigida 2008)** — referência nacional de projeto e verificação de instalações elétricas de baixa tensão (conferir edição aplicável na data do projeto).
- **NR-10 (Brasil)** — segurança em instalações e serviços em eletricidade; simulação não substitui procedimentos, ensaios ou responsabilidades técnicas.
- **IEC 60909-0:2026** — método de cálculo de correntes de curto-circuito em redes trifásicas CA dentro de seu escopo. Não aplicar indiscriminadamente a circuitos DC e todas as falhas.
- **IEC 60287-1-1:2023** — corrente admissível e perdas em cabos sob condições de regime permanente dentro de seu escopo.
- **IEC 60255-1:2022** — referência para equipamentos de medição, relés e proteção.

**Segurança:** o software é para **estudo, dimensionamento assistido, análise e comparação de cenários**. Simulação não valida por si só segurança contra choque, incêndio, arco elétrico ou atendimento normativo. Projetos e intervenções reais exigem responsável técnico, verificação e ensaios correspondentes.

### 18.14. Referências técnicas

- ABNT catálogo NBR 5410: https://www.abntcatalogo.com.br/
- NR-10 Ministério do Trabalho: https://www.gov.br/trabalho-e-emprego/pt-br/acesso-a-informacao/participacao-social/conselhos-e-orgaos-colegiados/comissao-tripartite-partitaria-permanente/normas-regulamentadora/normas-regulamentadoras-vigentes/norma-regulamentadora-no-10-nr-10
- IEC 60909-0:2026: https://webstore.iec.ch/en/publication/68454
- IEC 60287-1-1:2023: https://webstore.iec.ch/en/publication/68118
- IEC 60255-1:2022: https://webstore.iec.ch/en/publication/59762
- EPRI OpenDSS: https://opendss.epri.com/
- ngspice: https://ngspice.sourceforge.io/docs/ngspice-manual.pdf

---

**Controle de revisão v1.7:** acrescentado quinto aplicativo independente **SimuEletrica**, com 48 requisitos funcionais, 8 não funcionais, 12 cenários mínimos de aceitação, cinco entregas de implementação, integração versionada com Elétrica 3D e Maquete 3D, motor de cargas/proteções/RLC, aquecimento e mapa térmico de cabos. Não altera a independência dos demais aplicativos nem incorpora MultiCNC ou qualquer ferramenta externa ao pacote.

---

## 19. Aplicativo independente P — Planejador

> **Origem desta seção:** consolidada a partir das definições passadas durante a concepção (28/10/2026). Itens marcados como *proposta* foram sugeridos durante a conversa e ainda dependem de confirmação.

### 19.1. Descrição

O **Planejador** é a primeira etapa da linha de produção. Funciona como um gerenciador de projetos no estilo do Microsoft Project, voltado a empreendimentos de engenharia e arquitetura. Cada aplicativo da plataforma é uma etapa da linha; o Planejador cria as tarefas, define a ordem entre elas e acompanha sua execução. Ele **cria tarefas arquitetônicas que são executadas nos demais aplicativos**: por exemplo, a tarefa "Planta do térreo" abre no CAD 2D e a tarefa "Maquete da edificação" abre na Maquete 3D quando as plantas dos pavimentos estiverem concluídas.

### 19.2. Requisitos funcionais

| ID | Prioridade | Requisito / descrição |
|---|---|---|
| RFP-001 | Essencial | Criar, abrir, salvar e versionar projetos de planejamento do empreendimento. |
| RFP-002 | Essencial | Criar tarefas com nome, descrição, duração, datas, responsáveis e situação. |
| RFP-003 | Essencial | Encadear tarefas em grafo, em cadeia ou em paralelo, com dependências entre elas. |
| RFP-004 | Essencial | Criar **tarefas arquitetônicas** vinculadas ao aplicativo que as executa (CAD 2D, Maquete 3D, Criador de Cenas, Elétrica 3D, SimuEletrica). |
| RFP-005 | Essencial | Abrir a tarefa no aplicativo responsável, entregando arquivos de entrada e parâmetros. |
| RFP-006 | Essencial | Receber de volta o arquivo produzido, a situação da tarefa e eventuais pendências ou alertas. |
| RFP-007 | Essencial | Liberar uma tarefa somente quando as tarefas de que depende estiverem concluídas. |
| RFP-008 | Essencial | Ao criar ou importar um objeto 3D, criar tarefas para ele ou anexá-lo a tarefas existentes. |
| RFP-009 | Essencial | Vincular texturas aos objetos por meio das tarefas; o vínculo é aplicado na Maquete 3D ao objeto inteiro ou a uma face dele. |
| RFP-010 | Essencial | Oferecer visão de cronograma e os gráficos usados comumente no Microsoft Project (ver 19.3). |

### 19.3. Visões e gráficos (*proposta*)

- **Gráfico de Gantt:** barras no tempo, dependências, marcos e caminho crítico destacado.
- **Diagrama de rede (estilo PERT):** o grafo das tarefas, mostrando cadeia e paralelismo.
- **Calendário:** tarefas por dia, semana ou mês.
- **Uso de recursos:** alocação de pessoas e equipamentos, com aviso de sobrecarga.
- **Linha de base:** comparação entre o planejado e o realizado.
- **Curva S:** avanço físico ou financeiro acumulado, usual no acompanhamento de obras.

### 19.4. Regras

- O Planejador não produz geometria nem edita os arquivos dos demais aplicativos; ele referencia arquivos e recebe retornos.
- A textura vinculada continua sendo uma entidade independente da biblioteca (seção 4C); o objeto guarda a referência à textura e o destino da aplicação (objeto ou face).
- Cada tarefa registra o aplicativo responsável, a versão dos arquivos de entrada e de saída e o histórico de situações.

### 19.5. Contrato de tarefa (*proposta*)

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

### 19.6. Questões em aberto

1. Quando uma textura da biblioteca é alterada, os objetos vinculados acompanham a mudança automaticamente ou mantêm a versão vinculada até atualização explícita?
2. O Planejador também vincula texturas às superfícies arquitetônicas geradas pela Maquete (paredes, pisos, lajes), ou apenas aos objetos?
3. Os aplicativos da plataforma reaproveitarão componentes da suíte CHATGPT (Lazarus/FPC), como ocorre no MultiCNC?
