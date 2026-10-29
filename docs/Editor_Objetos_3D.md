# Editor de Objetos 3D

| Campo | Valor |
|---|---|
| Tipo | Módulo interno da Maquete 3D |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Prepara objetos tridimensionais reutilizáveis (móveis, equipamentos, componentes) para a maquete |
| Recebe | Sólidos STL e 3MF (inclusive do MultiCAD), OBJ, GLB/glTF; texturas do Gerador de Texturas |
| Produz | Objetos com geometria, texturas, miniatura e metadados na biblioteca; instâncias na maquete |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Descrição e finalidade

O **Editor de Objetos 3D** é um módulo nativo do **[Maquete 3D](Maquete_3D.md)**, com janela/área de edição própria, mas integrado à cena da maquete. Deve permitir **criar, importar, ajustar, catalogar e reutilizar objetos tridimensionais**, como móveis, bancadas, equipamentos hospitalares, luminárias, portas especiais, esquadrias, árvores, veículos e elementos decorativos. Não faz parte do editor CAD 2D. Este módulo **não substitui um modelador profissional completo** na primeira versão: começará com primitivas, transformações, edição básica de malhas e materiais, ampliando depois para ferramentas avançadas.

## 2. Requisitos funcionais — editor e biblioteca

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

## 3. Interface mínima

- **Biblioteca de Objetos:** categorias (móveis, cozinha, banheiro, portas/esquadrias, iluminação, equipamentos hospitalares, instalações, vegetação, decoração e personalizados), busca, filtros e miniaturas.
- **Viewport 3D de edição:** órbita, pan, zoom, vistas frontal/lateral/superior e perspectiva; grade, eixos e gizmos de manipulação.
- **Árvore de componentes:** partes/meshes, grupos e instâncias, com seleção, visibilidade e bloqueio.
- **Painel de propriedades:** dimensões reais, origem, transformação, material, textura, categoria, tags e vínculos de instalação.
- **Painel de materiais:** biblioteca de materiais, visualização e substituição por componente.
- **Comandos:** Novo objeto, Abrir, Importar, Salvar como objeto, Exportar, Adicionar à biblioteca, Inserir na maquete, Editar instância, Aplicar/Substituir modelo e Desfazer/Refazer.

## 4. Modelo de dados

- **Definição do objeto (asset):** `asset_id`, `version`, `category`, `name`, `units`, `pivot`, `meshes`, `materials`, `textures`, `bounds`, `thumbnail`, `source`, `license` e `metadata`.
- **Instância na maquete:** `instance_id`, `asset_id`, `asset_version`, `floor_id`, `position_xyz`, `rotation_xyz`, `scale_xyz`, `anchor`, `material_overrides` e `visibility`.
- **Arquivos:** armazenar em pacote nativo próprio com JSON de metadados, malhas, texturas e miniatura; usar GLB/glTF como formato prioritário de intercâmbio. As edições de instância não podem sobrescrever o asset sem comando explícito.
- **Sincronização:** IDs persistentes e âncoras em `floor_id`/`wall_id` para reposicionar instâncias após alterações da planta; vínculos quebrados ficam pendentes de revisão.

## 5. Regras de qualidade e segurança

- Preservar unidades e proporções; nunca converter automaticamente centímetros em metros sem aviso.
- Informar polígonos excessivos, geometria degenerada, texturas ausentes, materiais não suportados e origem/pivô inconsistentes.
- Importar arquivos sem executar scripts/macros e tratar referências externas de forma segura.
- Permitir otimização de malhas e instâncias para manter responsividade em cenas com muitos objetos.
- Objeto importado como malha não ganha automaticamente semântica BIM; propriedades arquitetônicas são associadas pelo usuário ou por reconhecimento validado.

## 6. Cenários de aceite — editor

1. Criar uma mesa com primitivas, definir largura de 1.200 mm, profundidade de 700 mm e altura de 750 mm, aplicar material, salvar na biblioteca e reinserir na maquete, incluindo uma variante de skin.
2. Importar um arquivo GLB com múltiplas partes, modificar escala/orientação, editar seu material, salvar uma versão e inserir duas instâncias em pavimentos diferentes.
3. Posicionar uma luminária no teto e uma bancada contra uma parede; manter as alturas e identificar colisões relevantes.
4. Alterar a localização de uma parede na planta 2D, regenerar a maquete e comprovar que móveis não afetados continuam intactos; para objeto ancorado em parede removida, exigir aviso de conflito.
5. Exportar objeto para GLB, reimportá-lo e comparar limites geométricos, orientação, materiais e unidades com tolerância documentada.

## 7. Importação de sólidos e aplicação de texturas

### Finalidade
O Editor de Objetos 3D da **Maquete 3D** deverá consumir modelos STL, 3MF e outros formatos de mercado, inclusive arquivos de sólidos (STL e 3MF) exportados por **MultiCAD/MultiCNC**, que permanecem **programas externos**; arquivos de projeto desses programas (`.mcad`, `.msuite`) não são lidos. Não há incorporação de seus executáveis, bibliotecas, instaladores, serviços ou código no pacote Maquete 3D. A saída do Editor de Objetos 3D será um objeto visual reutilizável, com geometria, dimensões reais, materiais, skin, miniatura e metadados, pronto para inserção na maquete. **Não é obrigação do editor reproduzir as operações paramétricas do MultiCAD ou gerar G-code**.

**Definição de skin neste projeto:** conjunto reutilizável de propriedades visuais e mapas de textura aplicado a um objeto, a uma parte da malha ou a uma superfície arquitetônica. Uma mesma geometria pode ter várias skins, como `madeira_carvalho`, `metal_escovado`, `pintura_branca` e `vidro_fume`. O editor deverá também permitir variantes visuais com partes substituíveis, quando a geometria oferecer essa divisão.

### Requisitos funcionais de integração e skins

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

### Compatibilidade com arquivos produzidos por ferramentas externas

A documentação consultada da branch `fila` do repositório `marcelomaurin/multicnc` descreve o **MultiCAD** como editor paramétrico de peças, usando `.mcad` para projetos e exportação de **STL**, além de **3MF** nas operações de malha. Somente os arquivos de sólidos STL e 3MF serão aceitos; a Maquete 3D não depende do MultiCAD nem do MultiCNC.

- **STL:** transportar malha; **não** esperar que contenha textura, UV, material PBR ou peças com nomes. Exigir confirmação de unidade quando ausente.
- **3MF:** usar atributos de unidade e possíveis informações de aparência quando presentes; não pressupor mapas PBR equivalentes a GLB.
- **`.mcad` / `.msuite`:** não suportados. Ao recebê-los, recusar com mensagem clara orientando exportar STL/3MF no software de origem.
- **G-code (`.gcode`, `.nc`):** código de máquina **não é modelo sólido autoritativo**. Não utilizá-lo como entrada geométrica principal. Qualquer reconstrução futura de trajetórias deve ser separada e explicitamente aproximada.
- **Eixos e unidades:** o README do MultiCAD cita `Y` para cima nas vistas da tela, mas informa que o STL é exportado "em pé para o MultiSlicer" (fatiadores usam `Z` vertical). A convenção real dos arquivos exportados deve ser **confirmada no exportador** antes de definir a conversão padrão, para não girar a peça duas vezes. O importador deverá exibir eixo de origem/destino e comparação dimensional antes da confirmação. A unidade padrão para arquivos do MultiCAD é o milímetro (sistema métrico documentado).

### Processo de geração e aplicação das skins

1. **Importação:** carregar STL/3MF, detectar dimensões da malha, conferir unidade e orientação.
2. **Preparação:** reparar malha, dividir em partes quando possível, preparar UV/projeção de textura e calcular caixa delimitadora.
3. **Criação da skin:** escolher um material da biblioteca, gerar padrão procedural ou carregar imagens/mapas PBR; associar canal e espaço de cor corretos.
4. **Ajustes:** definir escala física do revestimento (por exemplo, paginação de cerâmica em mm), repetição e orientação; permitir acabamento diferente para partes do objeto.
5. **Biblioteca:** salvar objeto e skins como entidades versionadas independentes, com miniaturas e metadados.
6. **Publicação:** exportar GLB ou pacote nativo autocontido e disponibilizar a opção **Inserir na Maquete 3D**.
7. **Atualização:** permitir trocar a skin sem substituir a geometria e atualizar a malha sem descartar skins quando o mapeamento continuar válido.

### Contrato de dados proposto

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

### Interface mínima complementar
- Aba **Importar Objeto 3D**: selecionar STL/3MF/GLB/OBJ, independentemente da ferramenta que gerou o arquivo; visualizar unidade, orientação, escala e submalhas.
- Aba **Geometria**: corrigir normais, pivô, dimensões, orientação, componentes e UV.
- Aba **Skins e Materiais**: importar imagens, gerar material procedural, criar variante, editar mapas PBR, aplicar por parte, visualizar antes/depois.
- Aba **Biblioteca**: objetos, skins, variantes e categorias com filtro por origem/projeto.
- Comandos **Salvar Objeto**, **Salvar Skin**, **Exportar GLB**, **Inserir na Maquete 3D** e **Atualizar a partir de novo STL/3MF**.

### Requisitos de qualidade
- Validar tamanho do arquivo, quantidade de triângulos, normais, coordenadas não finitas, objetos não-manifold, excesso de textura e referências inseguras em pacotes ZIP.
- Nunca executar macros/scripts importados nem aceitar caminhos relativos que escapem do diretório seguro de extração.
- Registrar hash da origem, adaptador, unidades, eixos, perdas, correções, skin usada e versão.
- Preservar licença/autoria das imagens e texturas; impedir alegações automáticas de propriedade intelectual.
- Limitar texturas e usar cache/instâncias para não duplicar a mesma geometria em várias posições.
- Evitar perda silenciosa de qualidade: informar quando o material de origem não for representável no formato de destino.

### Critérios de aceite específicos
1. Exportar uma peça real do MultiCAD como STL; importar no editor, confirmar dimensões em mm e orientar o eixo corretamente.
2. Importar a mesma peça em 3MF, comparar volume e dimensões com o STL, registrando diferenças de tolerância.
3. Criar uma skin de madeira procedural e outra a partir de textura PNG, aplicar ambas a instâncias da mesma peça e salvar na biblioteca.
4. Importar STL sem UV, gerar projeção adequada, aplicar normal map e rugosidade, exportar GLB e reabrir com acabamento preservado.
5. Inserir três instâncias do mesmo objeto na maquete em pavimentos distintos, usando skins diferentes e sem duplicar a geometria de origem.
6. Alterar a peça no MultiCAD, exportar novo STL e atualizar a maquete preservando posições/skins compatíveis; emitir aviso quando não puder mapear partes.
7. Importar pacote de objeto com textura ausente ou caminho inválido e obter relatório claro sem corromper a biblioteca.
8. Tentar importar um `.mcad` ou `.msuite` e obter recusa clara, com orientação para exportar STL/3MF.

### Critérios de aceitação complementares

1. Importar um glTF/GLB, OBJ ou STL como geometria de referência, sem classificar automaticamente suas faces como objetos BIM.
2. Criar, importar, editar, salvar e inserir objetos 3D reutilizáveis na maquete, preservando dimensões e materiais.
3. Importar STL/3MF exportado pelo MultiCAD; conferir medidas, corrigir orientação/eixos e garantir geração de UV quando necessário.
4. Atualizar uma malha de origem MultiCAD preservando skins e instâncias quando o remapeamento for possível, informando conflitos.

## 8. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| O1 — Primitivas e biblioteca | Primitivas com medidas reais, transformações, pivô, desfazer, salvar objeto, biblioteca com categorias e miniaturas | RF3D-023 a RF3D-026, RF3D-028, RF3D-032, RF3D-033 | Mesa de 1.200 × 700 × 750 mm criada, salva e reaberta da biblioteca |
| O2 — Importação de sólidos | STL (texto e binário), 3MF, OBJ e GLB; assistente com unidade, eixos e reparo de malha | RF3D-027, RF3D-045 a RF3D-048 | Peça do MultiCAD importada em STL e 3MF com medidas conferidas em mm |
| O3 — Instâncias na maquete | Inserção por arrastar, âncoras em piso, parede e teto, propriedades por instância | RF3D-029, RF3D-030, RF3D-034, RF3D-035 | Luminária no teto e bancada contra parede, preservadas após regenerar a maquete |
| O4 — Texturas no objeto | Mapeamento (plano, cúbico, cilíndrico, triplanar), aplicação por objeto ou face, variantes, exportação GLB | RF3D-031, RF3D-049 a RF3D-055 | Duas texturas na mesma malha, exportadas em GLB e reabertas sem perda |
| O5 — Atualização da geometria | Reimportar STL/3MF alterado mantendo texturas, posições e instâncias | RF3D-056 | Critério complementar 4 |
| O6 — Edição avançada | Edição de malhas, operações booleanas, objetos paramétricos, conjuntos, FBX e DAE | RF3D-036 a RF3D-042 | Definido ao iniciar a etapa |
| O7 — Futuro | IA assistiva, modificadores, animações e níveis de detalhe | RF3D-043, RF3D-044, RF3D-061 | — |

**Dependências:** O2 exige os leitores de malha do [Motor de Importação](Motor_Importacao.md) e a confirmação dos eixos do MultiCAD; O4 exige a etapa T1 do [Gerador de Texturas](Gerador_Texturas.md).
