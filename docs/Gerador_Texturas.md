# Gerador de Texturas (Skins)

| Campo | Valor |
|---|---|
| Tipo | Módulo interno da Maquete 3D, ligado ao Editor de Objetos 3D |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Cria as texturas e materiais aplicados aos objetos (inteiros ou por face) e às superfícies da maquete |
| Recebe | Fotos e imagens PNG/JPG/WEBP/TIFF; parâmetros procedurais; materiais de GLB/OBJ |
| Produz | Texturas independentes na biblioteca, mapas PNG, pacotes de textura e materiais glTF |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Definição e localização

O **Gerador de Texturas** é uma funcionalidade **nativa da Maquete 3D**, acessível pelo menu **Ferramentas > Gerador de Texturas** e pelos painéis **Materiais** do Editor de Objetos 3D e do Editor de Maquete. Não é necessário criar um terceiro aplicativo, conectar à internet nem instalar o MultiCNC. O módulo poderá funcionar em janela independente dentro do aplicativo.

Uma **textura** é uma imagem ou padrão aplicado a uma superfície; um **material/skin** reúne um ou mais mapas, parâmetros PBR, regras de escala e opções de aplicação. Um STL importado normalmente contém apenas triângulos, portanto precisará de projeção/UV para usar texturas 2D. Skins devem ser entidades **independentes das geometrias**, reaproveitáveis em diversos objetos.

## 2. Requisitos funcionais

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

## 3. Interface sugerida

- **Painel esquerdo:** Biblioteca de materiais, categorias e presets (madeira, concreto, pedra, pintura, metal, tecido etc.).
- **Centro:** Visualização 2D dos mapas e prévia 3D alternável (esfera, cubo, parede, piso ou modelo carregado).
- **Painel direito:** Parâmetros procedurais, paleta, dimensões físicas, UV/projeção, canais PBR e opções de exportação.
- **Barra superior:** Novo, Abrir Imagem, Gerar, Tornar Contínua, Salvar Skin, Exportar Mapas, Aplicar ao Objeto.
- **Rodapé:** resolução, consumo estimado de memória, espaço de cor, estado de salvamento e avisos de compatibilidade.

## 4. Formatos e parâmetros técnicos

- **Entrada:** PNG/JPG/WEBP/TIFF e pacotes de skin próprios; GLB/glTF e OBJ podem fornecer materiais existentes para adaptação. STL e 3MF entram via Editor de Objetos, não são formatos de textura.
- **Saída:** arquivos PNG por mapa; pacote próprio de skin com manifesto JSON e imagens; aplicação em materiais glTF 2.0 compatíveis.
- **Mapas PBR:** base color (sRGB), normal (linear), roughness/metallic (linear), AO (linear); altura/parallax e outros canais são internos ou dependentes de extensão, pois não fazem parte do material PBR básico do glTF.
- **Prévia:** iluminação e exposição configuráveis; exibir aviso quando a aparência no renderizador diferir do exportado.
- **Persistência:** identidade e versão de skin distintas das de objeto. Alterar a skin pode atualizar instâncias vinculadas ou criar uma variante, conforme escolha explícita.
- **Robustez:** validar imagens, limites de memória, licenças e caminhos; nunca executar código ou scripts a partir de arquivos importados.

## 5. Fluxo de utilização

1. **Criar:** escolher preset procedural (por exemplo, mármore) ou carregar foto de revestimento.
2. **Gerar:** ajustar padrão, cor, medidas físicas, repetição e tornar contínuo.
3. **Compor PBR:** configurar mapa de cor, normais, rugosidade e demais propriedades visuais.
4. **Visualizar:** conferir repetição sobre parede/piso e objetos com diferentes iluminações.
5. **Publicar na biblioteca:** salvar a skin independente de qualquer objeto.
6. **Aplicar:** selecionar uma superfície da maquete ou objeto importado STL/3MF e atribuir a skin.
7. **Exportar/compartilhar:** empacotar a skin com recursos e metadados ou exportar objeto GLB com material compatível.

## 6. Testes de aceitação

1. Em um computador **sem MultiCNC/MultiCAD instalado**, criar uma skin procedural de madeira, salvá-la e aplicá-la a uma parede da maquete.
2. Gerar material de azulejo com dimensões físicas de 300 × 600 mm e comprovar que a repetição na parede preserva essas medidas.
3. Importar uma imagem de mármore, torná-la contínua, gerar mapas auxiliares, salvar pacote de skin, fechar o programa e reimportar sem perder configurações.
4. Importar um STL de origem genérica sem UV, atribuir projeção triplanar ou gerar UV, aplicar a skin e exportar um GLB com aparência verificável em leitor compatível.
5. Aplicar a mesma skin a cinco objetos, trocar somente uma instância para uma variante e verificar que as outras quatro permanecem inalteradas.
6. Exportar PNG dos canais, conferir resoluções, nomes, espaços de cor e registrar perdas de materiais sem corromper o projeto.
7. Simular falta de textura ou de GPU compatível e verificar mensagens úteis, fallback disponível e preservação de arquivos já salvos.

### Critérios complementares

1. Criar/importar duas skins para uma única malha, salvar variantes independentes, exportar GLB e inserir na maquete sem perda de material suportado.
2. Criar texturas procedurais contínuas, salvar presets e reproduzir mapa por semente; aplicar em paredes/pisos e exportar materiais.

## 7. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| T1 — Materiais básicos | Material metal/rugosidade com cor, rugosidade, metalicidade, transparência; prévia em esfera, cubo, parede e piso; aplicação por objeto ou face | RFTX-001, RFTX-008, RFTX-010, RFTX-013 | Aplicar um material à face de um objeto e a uma parede |
| T2 — Procedurais | Madeira, pedra, mármore, concreto, tijolo, azulejo, pintura, metal e tecido; semente reproduzível; textura contínua; escala física em mm | RFTX-002 a RFTX-005, RFTX-011 | Teste 2 (azulejo de 300 × 600 mm na parede) |
| T3 — A partir de fotos | Importação, recorte, correção, textura contínua e estimativa de mapas normal, altura e rugosidade | RFTX-006, RFTX-007, RFTX-009 | Teste 3 (mármore de foto salvo e reaberto) |
| T4 — Biblioteca e pacotes | Biblioteca versionada, variantes, pacote de textura, exportação PNG e GLB | RFTX-012, RFTX-014, RFTX-015, RFTX-020, RF3D-054, RF3D-060 | Testes 5 e 6 |
| T5 — Recursos de produção | Resoluções até 4096, camadas de mistura, desgaste, lotes de variantes, predefinições | RFTX-016 a RFTX-019, RFTX-023 | Definido ao iniciar a etapa |
| T6 — Futuro | IA local ou remota opcional | RFTX-021, RFTX-022 | — |

**Dependências:** T1 exige a visualização 3D do [Núcleo Comum](Nucleo_Comum.md). A resposta à questão sobre versionamento de texturas vinculadas (ver [Decisões](Decisoes.md)) é necessária antes de T4.
