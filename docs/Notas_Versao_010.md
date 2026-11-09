# Versão 0.10 — instalador 010

Unificação da suíte integrada com interoperabilidade BIM/CAD, pipeline automatizada de releases e relatórios avançados de planejamento.

- **Interoperabilidade BIM e Desenho Técnico no CAD 2D:**
  - Suporte completo a importação de DXF nativo (LINE, LWPOLYLINE, CIRCLE, ARC).
  - Identificação de versões de cabeçalho AutoCAD DWG (AC1015 a AC1032) e suporte a conversão transparente.
  - Extração de modelos BIM IFC (ISO 16739 / STEP) em vistas 2D por pavimento.
  - Relatório de importação com rastreabilidade, contagem de elementos e hash SHA-1 do arquivo de origem.
- **Modelos Demonstrativos de Engenharia e Saúde:**
  - Inclusão dos modelos integrados em formato IFC, DWG, DXF e EACAD na pasta de amostras (`samples/files/hospital_terreo.*`).
  - Atualização do catálogo 2D com itens de saúde/SUS e componentes arquitetônicos.
- **Relatórios de Sprint e Apontamentos:**
  - Relatório de pendências, atrasos, esforço restante estimado e carga horária por usuário.
  - Apontamento diário de horas por pessoa/tarefa com validações de integridade e exportações HTML/CSV.
- **Atualização Automática e Deploy Contínuo:**
  - Integrador com verificações de integridade SHA-256 e suporte a atualizações pelo GitHub Releases.
  - Executáveis Windows x64 com versão 0.10.0.0.

Consulte [Atualização Automática](Atualizacao_Automatica.md) e [Relatórios de sprint e carga por usuário](Relatorios_Sprint_Carga_Usuarios.md).

