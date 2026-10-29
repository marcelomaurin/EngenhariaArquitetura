# Núcleo Comum

| Campo | Valor |
|---|---|
| Tipo | Bibliotecas compartilhadas por todos os aplicativos |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Base técnica de todos os componentes: geometria, modelo de dados, persistência e visualização |
| Recebe | — |
| Produz | Unidades de código reutilizadas pelos sete aplicativos |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Finalidade

Evitar que cada aplicativo reimplemente geometria, unidades, modelo arquitetônico e leitura e gravação de pacotes. O núcleo é independente da interface (RNF-002) e não depende de nenhum aplicativo. Os nomes dos pacotes abaixo são **proposta**.

| Pacote (proposta) | Conteúdo | Usado por |
|---|---|---|
| `ea_geometria` | vetores 2D/3D, tolerância numérica, interseções, polígonos, offsets, transformações, testes de fechamento, índices espaciais e colisões. | Todos |
| `ea_modelo` | Modelo arquitetônico interno: projeto, pavimento, objeto, material, origem de importação | CAD 2D, Maquete 3D, Elétrica 3D, SimuTubulações, Criador de Cenas |
| `ea_pacote` | Pacotes de intercâmbio: manifesto JSON versionado, hash, identificadores estáveis e referências | Todos |
| `ea_ancoras` | Âncoras persistentes em pavimento, parede, superfície e ambiente | Maquete 3D, Editor de Objetos, Elétrica 3D, SimuTubulações |
| `ea_visual3d` | Visualização 3D interativa em OpenGL: câmera, navegação, seleção e materiais de prévia | Maquete 3D, Criador de Cenas, Elétrica 3D, SimuEletrica, SimuTubulações |
| `ea_interface` | Padrão visual comum: menus, barras, painéis de propriedades e rodapé de estado | Todos |

## 2. Modelo arquitetônico interno

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

## 3. Plataformas

Windows e Linux; núcleo independente da interface. Lazarus/Free Pascal pode hospedar a interface e invocar bibliotecas/serviços de conversão isolados. Compatibilidade real por SO, arquitetura e licença deverá ser homologada.

## 4. Requisitos não funcionais atendidos pelo núcleo

RNF-001 (precisão em dupla precisão e unidades explícitas), RNF-002 (portabilidade), RNF-003 (robustez), RNF-004 (rastreamento de origem), RNF-009 (integridade na reimportação) e RNF-012 (reprodutibilidade). Texto completo em [Visão geral da plataforma](Visao_Geral_Plataforma.md).

## 5. Etapas de desenvolvimento

| Etapa | Escopo | Critério de saída |
|---|---|---|
| N1 — Geometria 2D | Vetores, tolerâncias, interseções, polígonos, deslocamento paralelo, transformações e fechamento de contornos, com testes automatizados | Testes cobrindo interseções, deslocamento e área de polígonos com tolerância documentada |
| N2 — Modelo e persistência | `ea_modelo` e `ea_pacote` com serialização JSON versionada | Gravar e reler um projeto com paredes e pavimentos sem diferença |
| N3 — Interface comum | Padrão visual e estrutura de aplicativo Lazarus reutilizável | Aplicativo vazio abre, mostra menus padrão e salva configuração |
| N4 — Geometria 3D e malhas | Malhas, normais, caixas delimitadoras, índices espaciais e colisões | Testes de malha e colisão |
| N5 — Visualização 3D | `ea_visual3d` com navegação orbital, seleção e materiais de prévia | Malha de teste navegável e selecionável |
| N6 — Âncoras | `ea_ancoras` com reposicionamento após mudança de parede | Ponto ancorado acompanha parede deslocada |

**Decisão (29/10/2026):** o núcleo reaproveita a suíte CHATGPT, como o MultiCNC; o que puder ser genérico vira componente da CHATGPT primeiro. Grafo de tarefas, calendário, durações e caminho crítico já vêm de lá (AIProjectCore), copiados em `third_party/chatgpt` como reserva (ver [Decisões](Decisoes.md)).
