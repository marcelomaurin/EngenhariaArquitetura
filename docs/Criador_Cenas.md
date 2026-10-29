# Criador de Cenas Realistas 3D

| Campo | Valor |
|---|---|
| Tipo | Aplicativo independente |
| Versão do documento | 1.0 — 29/10/2026 (derivado da especificação da plataforma 1.8) |
| Estado | Proposta de requisitos (ainda não implementada) |
| Papel na linha de produção | Quarta etapa: transforma a maquete pronta em imagens, vídeos e passeios ultrarrealistas |
| Recebe | Maquete 3D finalizada; opcionalmente luminárias e interruptores do Elétrica 3D |
| Produz | Imagens em alta resolução, vídeos, passeios virtuais e projeto de cena próprio |

> Integrações com os demais componentes: [Integrações](Integracoes.md). Ordem de desenvolvimento: [Plano de desenvolvimento](Plano_Desenvolvimento.md).

## 1. Descrição

Recebe uma **maquete finalizada ou sua revisão**, incluindo geometria, objetos 3D, skins e respectivos metadados. Adiciona câmeras, animações, personagens, água em movimento, vegetação ao vento, abertura de portas, efeitos climáticos e iluminação realista; gera imagens, vídeos e passeios virtuais. Não é o editor técnico de plantas nem o editor de circuitos.

O Criador de Cenas abre uma **maquete 3D preparada**, com todos os objetos, materiais e skins já associados, e permite adicionar efeitos visuais e dinâmicos. O resultado esperado são **imagens realistas, vídeos, visitas virtuais e experiências navegáveis**. A maquete original permanece vinculada e não é alterada diretamente. A cena utiliza um arquivo nativo próprio com referências à maquete-base e aos recursos externos.

### Principais recursos

| Grupo | Funcionalidades |
|---|---|
| Câmeras | Posicionamento, campo de visão, lentes, foco, profundidade de campo e trajetórias |
| Pessoas | Personagens 3D animados, caminhadas, percursos e interações |
| Portas e janelas | Abertura e fechamento, movimentos e acionamentos |
| Água | Ondulações, ondas, reflexos, transparência e movimentação |
| Vegetação | Árvores, grama, folhas e plantas movimentadas pelo vento |
| Iluminação | Sol, céu, iluminação artificial, sombras e cenas diurnas e noturnas |
| Atmosfera | Chuva, neblina, nuvens, vento e efeitos climáticos |
| Materiais | Interpretação realista das texturas criadas na Maquete 3D |
| Animação | Linha do tempo, quadros-chave, sequências e eventos |
| Renderização | Imagens de alta resolução e vídeos fotorrealistas |
| Navegação | Passeio virtual interno e externo, com câmera livre |

**Modos de trabalho:** visualização interativa, para posicionar objetos e conferir movimentos, e renderização final, priorizando fidelidade de iluminação, reflexos e materiais por traçado de caminhos de luz.

## 2. Requisitos funcionais

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

## 3. Regras

- A qualidade final depende dos modelos, iluminação, texturas, hardware e motor de renderização: **ultrarrealismo é meta de qualidade, não garantia automática**.
- A camada elétrica é uma **entrada opcional**, usada como referência de pontos de luz e estados; o Criador de Cenas **não valida segurança elétrica**.
- Materiais criados no Gerador de Skins poderão ser reinterpretados pelo renderizador, registrando incompatibilidades de efeitos avançados.
- O Criador de Cenas deve funcionar sem instalar MultiCNC/MultiCAD ou Elétrica 3D.

## 4. Critérios de aceitação

1. Importar uma maquete com objetos STL convertidos e skins PBR.
2. Inserir câmera, realizar percurso e renderizar sequência com frames e configuração repetíveis.
3. Demonstrar pessoa caminhando, vegetação movida por vento, água animada e porta abrindo.
4. Renderizar cena diurna e noturna, com luzes artificiais.
5. Reabrir cena e manter vínculos de objetos, materiais e animações.
6. Opcionalmente importar estados de luminárias publicados pelo Elétrica 3D, preservando sua separação funcional.

## 5. Pontos técnicos a definir

- **Motor de renderização final:** avaliar LuxCoreRender (Apache 2.0, interface em C, chamável pelo Free Pascal) e Cycles do Blender como processo separado (GPL, fora do executável).
- **Tradução de materiais:** do modelo metal/rugosidade do glTF para o motor escolhido, incluindo vidro, água e superfícies translúcidas.
- **Personagens:** esqueleto e animações transportados em glTF; a origem precisa permitir uso comercial.
- **Efeitos dinâmicos:** vento, água e chuva exigem uma implementação no modo interativo e outra na renderização final.
- **Luminárias:** arquivos fotométricos do fabricante (IES) vindos do Elétrica 3D reproduzem a distribuição real da luz.

## 6. Etapas de desenvolvimento

| Etapa | Escopo | Requisitos | Critério de saída |
|---|---|---|---|
| C1 — Cena interativa | Importar maquete, projeto de cena vinculado à versão da maquete, câmeras, sol por horário e orientação norte, céu e luzes | RFC-001 a RFC-004, RFC-006, RFC-007 | Critério 1 e cena salva e reaberta |
| C2 — Imagem final | Integração do motor de renderização escolhido; qualidade, resolução e amostras; prévia rápida e final | RFC-008, RFC-019 | Imagem diurna e noturna da mesma cena (critério 4) |
| C3 — Animação e vídeo | Linha do tempo, quadros-chave, trajetórias de câmera, sequência de quadros e vídeo | RFC-005, RFC-009, RFC-015 | Critério 2 |
| C4 — Cena viva | Pessoas, portas, água, vegetação ao vento, atmosfera e bibliotecas com licenças | RFC-010 a RFC-014, RFC-018 | Critério 3 |
| C5 — Integrações | Revisões da maquete sem perder cenas; estados de iluminação do Elétrica 3D | RFC-016, RFC-017 | Critérios 5 e 6 |
| C6 — Futuro | Panoramas 360°, estereoscopia e realidade virtual | RFC-020 | — |

**Decisão necessária:** motor de renderização antes de C2. **Dependências:** C1 exige a Maquete 3D na etapa M3 e a visualização 3D do [Núcleo Comum](Nucleo_Comum.md).
