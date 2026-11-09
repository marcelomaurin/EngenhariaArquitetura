# CAD Arquitetônico 2D

Módulo de desenho técnico arquitetônico bidimensional da plataforma Engenharia e Arquitetura.

## Visão geral

O CAD Arquitetônico 2D foi desenvolvido em Free Pascal com a biblioteca Lazarus Component Library (LCL) e destina-se à elaboração de plantas baixas, cortes esquemáticos, memoriais descritivos gráficos e estudos preliminares com foco em engenharia civil e arquitetura.

## Formato de arquivo

O formato nativo é o **EACAD** (JSON estruturado), com histórico evolutivo:
- `EACAD1`: formato inicial com entidades primitivas (linhas, círculos, cotas, paredes, portas e janelas).
- `EACAD2` e `EACAD3`: revisões com suporte ampliado a propriedades.
- `EACAD4`: preserva altura, peitoril, grupo, grade, visibilidade e bloqueio de camadas.
- `EACAD5`: inclui identificação de blocos e nomes de ambientes.

## Representação de aberturas (portas e janelas)

Os objetos lineares Porta e Janela desenham uma faixa branca sob o traço colorido, sugerindo uma abertura quando sobrepostos a uma parede previamente desenhada. **É apenas uma indicação gráfica**: ainda não corta o objeto parede, não calcula união/interseção arquitetônica e depende da ordem de renderização (paredes posteriores podem cobrir a faixa). O modelo precisa evoluir para paredes com faces e aberturas vinculadas antes de exportar informação confiável à Maquete 3D.

## Importação de Arquivos DWG, DXF e IFC (BIM)

O CAD 2D conta com integração ao subsistema de importação e interoperabilidade (`cad2d/src/io/cad2d_importador.pas`):

- **AutoCAD DXF (RFI-005, RFI-006, RF2D-011):**
  - Leitor nativo de seções `ENTITIES` (`LINE`, `LWPOLYLINE`, `CIRCLE`, `ARC`).
  - Reconhecimento automático de camadas para classificação arquitetônica: camadas contendo `WALL`, `PAREDE` ou `ALVENARIA` viram entidades do tipo Parede; camadas `DOOR`/`PORTA` viram Portas; camadas `WINDOW`/`JANELA` viram Janelas. Elementos estruturais e de instalações são mapeados para suas respectivas camadas.
  - Enquadramento automático (*Fit to bounds*) com ajuste de zoom e pan.

- **AutoCAD DWG (RFI-001, RFI-013, RF2D-011):**
  - Detecção exata de versão do arquivo pelos *magic bytes* no cabeçalho binário (AutoCAD 2000 até 2024: `AC1015`, `AC1018`, `AC1021`, `AC1024`, `AC1027`, `AC1032`).
  - Adaptador para conversores CLI (`dwg2dxf` do LibreDWG ou ODA File Converter), convertendo de forma transparente para DXF temporário quando o utilitário estiver presente.
  - Diagnóstico com relatório informativo (RFI-007) quando conversores externos não estiverem no PATH.

- **Modelos BIM IFC (ISO 16739 / STEP, RF2D-017, I7):**
  - Leitura estruturada STEP (ISO 10303-21) identificando pavimentos (`IFCBUILDINGSTOREY`).
  - Extração de projeções 2D no plano do pavimento selecionado para `IFCWALL`, `IFCDOOR` e `IFCWINDOW`.
  - Conversão de medidas e distribuição paramétrica na planta baixa.

- **Relatório de Importação e Rastreabilidade (RFI-007, RFI-009):**
  - Registro de origem com caminho do arquivo e cálculo do hash SHA-1.
  - Relatório consolidado com quantidade de paredes, portas, janelas e linhas gerais importadas, além de contagem de entidades ignoradas e avisos.

## Interface 2D, menus e atalhos

O CAD trabalha exclusivamente com desenho em X/Y, em vista superior ortográfica.
Paredes, portas, janelas e móveis são representações em planta; não há geração,
renderização ou exportação de imagens 3D neste aplicativo.

A paleta escura existente foi mantida nos menus suspensos e na faixa de ferramentas.
Menus Arquivo, Editar, Desenhar, Modificar, Arquitetura, Anotar, Exibir e Ajuda
executam os comandos disponíveis. As abas Desenhar, Arquitetura, Anotar e Vista 2D
reorganizam os grupos. O painel lateral permite escolher a camada, alternar sua
visibilidade e impedir a seleção/edição de camadas bloqueadas.

A roda aproxima/afasta ao redor do cursor; arrastar com o botão central desloca
a vista; Enquadrar calcula os limites das entidades visíveis. A grade acompanha
deslocamentos negativos. Móveis usam contornos técnicos em planta sem materiais.
O documento exibe o nome real do arquivo .eacad.

Atalhos implementados, baseados no guia oficial:
https://www.autodesk.com/shortcuts/autocad-lt

| Tecla | Função |
|---|---|
| Ctrl+N / Ctrl+O | Novo / abrir projeto |
| Ctrl+S / Ctrl+Shift+S | Salvar projeto / salvar como (diálogo de arquivo) |
| Ctrl+Z / Ctrl+Y | Desfazer / refazer geometria |
| F1 / F2 | Ajuda / expandir histórico de comandos |
| F3 | Captura de extremidades de objetos |
| F7 / F8 / F9 | Grade / ortogonal / captura na grade |
| Ctrl+L / Ctrl+B | Ortogonal / captura na grade |
| Ctrl+1 / Ctrl+9 | Painel de camadas / linha de comandos |
| Esc / Del | Cancelar / excluir seleção |
| L, REC, C, M, CO, RO, MI, O, TR, EX, F, CHA, DI, LA, Z | Aliases digitados e confirmados com Enter |

Somente os atalhos associados a funções existentes são implementados. Digite
AJUDA para consultar comandos. O histórico de geometria usa TAIUndoHistory,
da biblioteca AI Project Core do projeto CHATGPT, com limite de 60 passos.

A interface usa os azuis do MultiCNC/MultiSuite: #1E4091 e #0F172A, com
destaques #2563EB nos menus, ferramentas e controles ativos.

## Gestão de tarefas e usuários

O fluxo integrado com login, quatro perfis, atribuição, respostas e devolução de arquivos
está descrito em [Gestão de tarefas e usuários](../docs/Gestao_Tarefas_Usuarios.md).

## Melhorias da versão 0.05 e 0.06

Consulte [Notas da versão 005](../docs/Notas_Versao_005.md) e [Notas da versão 006](../docs/Notas_Versao_006.md).
A ferramenta permanece de uso geral, com foco em projetos de saúde e SUS. Os exemplos de UBS e ala assistencial são esquemáticos. Consulte [Direcionamento para saúde e SUS](../docs/Direcionamento_Saude_SUS.md).
