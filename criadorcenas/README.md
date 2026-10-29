# Criador de Cenas Realistas 3D

Aplicativo independente que recebe a maquete 3D completa (paredes, pisos, móveis, objetos e texturas) e produz **imagens, vídeos e passeios virtuais ultrarrealistas** de como o ambiente poderá ficar depois de construído.

> **Estado:** em especificação. Especificação completa e etapas de desenvolvimento em [docs/Criador_Cenas.md](../docs/Criador_Cenas.md); integrações em [docs/Integracoes.md](../docs/Integracoes.md).

## Posição na plataforma

| Recebe | Produz | Destino |
|---|---|---|
| Maquete 3D finalizada; opcionalmente, luminárias e interruptores do Elétrica 3D | Imagens em alta resolução, vídeos, passeios virtuais | Cliente e apresentação do projeto |

A maquete original permanece vinculada e **não é alterada**. A cena tem arquivo próprio, com referência à versão da maquete. O Criador de Cenas **não valida** o projeto elétrico; usa os dados elétricos apenas para simular a iluminação.

## Funcionalidades

| Grupo | Funcionalidades |
|---|---|
| Câmeras | Posicionamento, campo de visão, lentes, foco, profundidade de campo e trajetórias |
| Pessoas | Personagens 3D animados, caminhadas, percursos e interações |
| Portas e janelas | Abertura e fechamento por pivôs e limites |
| Água | Ondulações, ondas, reflexos, transparência e movimento |
| Vegetação | Árvores, grama e plantas movidas pelo vento |
| Iluminação | Sol por horário e orientação norte, céu, luzes artificiais, cenas diurnas e noturnas |
| Atmosfera | Chuva, neblina, nuvens e vento |
| Materiais | Interpretação realista das texturas da Maquete 3D |
| Animação | Linha do tempo, quadros-chave, sequências e eventos |
| Renderização | Imagens em alta resolução e vídeos fotorrealistas |
| Navegação | Passeio em primeira pessoa e vista aérea |

## Modos de trabalho

- **Visualização interativa:** posicionar objetos e conferir movimentos, com materiais simplificados.
- **Renderização final:** fidelidade de iluminação, reflexos e materiais, por traçado de caminhos de luz.

## Requisitos

| Faixa | Assunto |
|---|---|
| RFC-001 a RFC-009 | Importação, câmeras, animação, iluminação, materiais, imagens e vídeo |
| RFC-010 a RFC-019 | Pessoas, portas, água, vegetação, atmosfera, passeio, dados elétricos e bibliotecas |
| RFC-020 | Panoramas 360°, estereoscopia e realidade virtual |

## Pontos técnicos a definir

- **Motor de renderização final:** avaliar LuxCoreRender (Apache 2.0, interface em C, chamável pelo Free Pascal) e Cycles do Blender como processo separado (GPL, fora do executável).
- **Tradução de materiais:** do modelo metal/rugosidade do glTF para o motor escolhido, incluindo vidro, água e superfícies translúcidas.
- **Personagens:** esqueleto e animações transportados em glTF; a origem precisa permitir uso comercial.
- **Efeitos dinâmicos:** vento, água e chuva precisam de duas implementações, uma para o modo interativo e outra para a renderização final.
- **Luminárias:** arquivos fotométricos do fabricante (IES) vindos do Elétrica 3D reproduzem a distribuição real da luz.

## Entregas

| Entrega | Conteúdo |
|---|---|
| G | Câmeras, iluminação e imagem estática |
| H | Pessoas, vento, água, portas e vídeo |
| L | Estados das luminárias vindos do Elétrica 3D |

## Critérios de aceite

1. Importar maquete com objetos STL convertidos e texturas.
2. Criar câmera, fazer percurso e renderizar sequência repetível.
3. Demonstrar pessoa caminhando, vegetação ao vento, água animada e porta abrindo.
4. Renderizar cena diurna e noturna com luzes artificiais.
5. Reabrir a cena mantendo vínculos de objetos, materiais e animações.
6. Importar estados de luminárias do Elétrica 3D, mantendo a separação funcional.
