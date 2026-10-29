# Maquete 3D

Gerador de maquetes tridimensionais. Interpreta uma ou várias plantas baixas, identifica os pavimentos e reconstrói automaticamente a edificação em 3D. Inclui dois módulos internos obrigatórios: o **Editor de Objetos 3D** e o **Gerador de Texturas**.

> **Estado:** em especificação. Especificação completa e etapas de desenvolvimento em [docs/Maquete_3D.md](../docs/Maquete_3D.md); integrações em [docs/Integracoes.md](../docs/Integracoes.md).

Módulos internos com documento próprio: [Editor de Objetos 3D](../docs/Editor_Objetos_3D.md) e [Gerador de Texturas](../docs/Gerador_Texturas.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Plantas do CAD 2D; DWG, DXF e IFC; sólidos STL/3MF (inclusive do MultiCAD); OBJ, GLB/glTF | Edificação 3D com pavimentos, objetos, texturas e âncoras | Criador de Cenas, Elétrica 3D |

**Fora do escopo:** renderização ultrarrealista e animações avançadas (Criador de Cenas) e o projeto elétrico (Elétrica 3D). A Maquete oferece apenas visualização de trabalho com iluminação básica.

## Funcionalidades

### Reconstrução da edificação
- Importação de uma planta ou de várias em uma única operação (térreo, pavimentos, subsolo e cobertura).
- Alinhamento dos pavimentos por origem, eixos ou pontos de controle.
- Definição de cotas de nível, pé-direito, espessura de lajes e alturas.
- Conversão de paredes 2D em volumes, com junções, encontros e recortes; geração de vãos, portas, janelas, pisos, lajes e escadas.
- Atualização a partir de nova versão das plantas, preservando ajustes manuais e sinalizando conflitos.

### Editor de Objetos 3D
- Criação por primitivas (caixa, plano, cilindro, esfera, cone) com medidas reais.
- Importação de STL (texto e binário), 3MF, GLB/glTF e OBJ; reparo de malhas, normais, pivô e orientação.
- Biblioteca de objetos com categorias, busca, miniaturas, autoria, licença e versões.
- Instâncias na maquete ancoradas ao pavimento e à superfície de apoio (piso, parede, teto); a instância não altera o objeto da biblioteca.

### Gerador de Texturas
- Texturas procedurais (madeira, pedra, mármore, concreto, tijolo, azulejo, pintura, metal, tecido) e a partir de fotos.
- Texturas contínuas, sem emendas visíveis.
- Materiais no modelo metal/rugosidade do glTF: cor, normal, rugosidade, metalicidade, oclusão, transparência e emissão.
- Escala física em milímetros (por exemplo, azulejo de 300 × 600 mm).
- Aplicação ao **objeto inteiro ou a uma face**, e também a paredes, pisos e tetos.
- Texturas são entidades independentes, salvas em biblioteca própria e vinculadas aos objetos.

## Arquivos do MultiCAD

O MultiCNC/MultiCAD é um **sistema externo**, fora do projeto. São aceitos somente os arquivos de sólidos:

| Formato | Tratamento |
|---|---|
| STL | Apenas malha: o editor gera o mapeamento e aplica a textura; unidade padrão em milímetros |
| 3MF | Malha, unidade e, quando houver, cores e materiais |
| `.mcad`, `.msuite` | Não suportados: recusa com orientação para exportar STL/3MF |

A convenção de eixos dos arquivos exportados pelo MultiCAD ainda precisa ser confirmada no exportador, para não girar a peça duas vezes.

## Requisitos

| Faixa | Assunto |
|---|---|
| RF3D-001 a RF3D-022 | Reconstrução, pavimentos, visualização, IFC, revisões e exportação |
| RF3D-023 a RF3D-044 | Editor e biblioteca de objetos 3D |
| RF3D-045 a RF3D-062 | Importação de sólidos e texturas (057 e 058 removidos) |
| RFTX-001 a RFTX-024 | Gerador de Texturas |
| RFI-001 a RFI-021 | Motor de importação comum |

## Formatos

| Importação | Exportação |
|---|---|
| Projeto do CAD 2D, DWG, DXF, IFC, STL, 3MF, OBJ, GLB/glTF, FBX, DAE; SKP e RVT por conversão | Pacote nativo, GLB/glTF, OBJ, imagens e, quando viável, IFC |

## Entregas

| Entrega | Conteúdo |
|---|---|
| C | Maquete automática a partir de DXF/DWG e do projeto nativo |
| D | Editor de Objetos 3D e biblioteca |
| D2 | Gerador próprio de Texturas |
| E | IFC, objetos semânticos e visualização de montagem |
| F | Adaptadores SKP/RVT, atualização incremental e recursos avançados |

## Critérios de aceite (resumo)

- Montar a maquete a partir de dois DXF (térreo e superior) com níveis parametrizados.
- Criar uma mesa de 1.200 × 700 × 750 mm, aplicar textura, salvar e reinserir.
- Importar STL do MultiCAD, confirmar medidas em mm, gerar mapeamento, aplicar textura e exportar GLB.
- Alterar uma parede na planta, regenerar e preservar os móveis não afetados.
- Criar azulejo de 300 × 600 mm e comprovar a escala na parede.
