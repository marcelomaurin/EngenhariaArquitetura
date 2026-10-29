# Motor de Importação e Interoperabilidade

| Campo | Valor |
|---|---|
| Tipo | Biblioteca comum, usada pelo CAD 2D, pela Maquete 3D e pelo Editor de Objetos 3D |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Porta de entrada de arquivos de outros softwares na plataforma |
| Recebe | DWG, DXF, IFC, PDF, SVG, imagens, STL, 3MF, OBJ, GLB/glTF, FBX, DAE e outros |
| Produz | Entidades no modelo interno canônico, com vínculo de origem e relatório de perdas |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Finalidade

Converter arquivos de mercado para o modelo interno da plataforma sem depender do software de origem, preservando o máximo de geometria, medidas, pavimentos e objetos, e informando o que foi perdido ou aproximado. Cada formato é um adaptador testável, com versão e capacidades declaradas (RNF-006).

## 2. Matriz de formatos

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

## 3. Requisitos funcionais

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

## 4. Adaptadores previstos

- DXF: motor próprio limitado ao subconjunto especificado ou biblioteca consolidada (p. ex., ezdxf via serviço Python).
- DWG/DGN: avaliar SDK ODA Drawings ou conversor externo compatível e suas licenças; não prometer cobertura integral sem SDK testado.
- IFC: avaliar IfcOpenShell e validar versões/categorias efetivamente suportadas.
- RVT/SKP: plugins licenciados, SDKs ou conversão para IFC/DXF/glTF; tratar dependências de aplicação instalada.
- PDF/SVG/imagens: bibliotecas de leitura vetorial/raster, mais módulo de calibração e revisão.
- Malhas 3D: importadores STL (ASCII/binário), 3MF, OBJ, glTF/GLB, FBX e DAE, preservando somente atributos efetivamente presentes; OBJ/GLB para materiais; STL exige materialização posterior.
- MultiCNC/MultiCAD: **não são componentes do produto Maquete 3D**. O usuário pode exportar STL/3MF no aplicativo de origem e importar via diálogo comum; arquivos `.mcad` e `.msuite` não são lidos. Não distribuir dependências dessas aplicações no pacote.

## 5. Critérios de aceitação

1. Importar um DXF com layers, blocos, polilinhas, cotas e textos; comparar coordenadas e dimensões com o original.
2. Importar um DWG real de origem AutoCAD usando o adaptador escolhido; abrir com escala correta, emitir relatório sobre entidades incompatíveis e não alterar o original.
3. Importar PDF vetorial e calibrar escala por uma medida conhecida; distinguir PDF digitalizado, sem prometer que ele vira CAD automaticamente.
4. Importar IFC com dois pavimentos e reconhecer pavimentos, paredes, portas, janelas e lajes onde essas entidades existem.
5. Testar arquivos com unidade desconhecida, referência ausente, geometria aberta e arquivo inválido; exigir mensagens úteis e proteção de dados.
6. Verificar os relatórios de perdas (objetos ignorados, atributos descartados, aproximações geométricas) e a possibilidade de corrigir manualmente.

## 6. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| I1 — Estrutura | Detecção de formato e versão pelo conteúdo, interface comum de adaptador, relatório de perdas, cópia preservada da origem com hash | RFI-001, RFI-006, RFI-007, RFI-009, RFI-012 | Arquivo inválido recusado com relatório, sem alterar o projeto |
| I2 — DXF | Linhas, polilinhas, arcos, círculos, textos, cotas, hachuras, camadas e blocos; unidades e escala; seleção de camadas | RFI-002 a RFI-005, RFI-008, RFI-010 | Critério 1 |
| I3 — Vetores e imagens | SVG, PDF vetorial, imagens de referência com calibração de escala | RFI-004, RFI-010 | Critério 3 |
| I4 — Malhas | STL (texto e binário), 3MF, OBJ, GLB/glTF; recusa de `.mcad` e `.msuite` | RFI-019, RFI-021 | Critério complementar 1 do [Editor de Objetos 3D](Editor_Objetos_3D.md) |
| I5 — Revisões | Reimportação comparando por identificador e geometria; correção manual antes de confirmar | RFI-011, RFI-015, RFI-016 | Inclusões, alterações e exclusões apresentadas antes de confirmar |
| I6 — DWG | Adaptador escolhido (biblioteca licenciada, LibreDWG ou conversor externo) | RF2D-011 | Critério 2 |
| I7 — IFC | Leitor do subconjunto (paredes, portas, janelas, lajes, pavimentos) ou IfcOpenShell isolado | RF3D-014 | Critério 4 |
| I8 — Lote e perfis | Linha de comando, cortes e fachadas de apoio, perfis por fornecedor, DGN, SKP e RVT por conversão | RFI-013, RFI-014, RFI-017, RFI-018 | Definido ao iniciar a etapa |

**Decisões necessárias:** biblioteca de DWG antes de I6 e estratégia de IFC antes de I7 (ver [Decisões](Decisoes.md)).
