# Versão 0.06 — instalador 006

Data: 31/10/2026. Windows 64 bits.

Esta entrega mantém o CAD e o Planejador de uso geral e direciona as bibliotecas
e os exemplos prioritariamente à saúde, incluindo hospitais, UBS e SUS.

## Conteúdo

- As correções de confiabilidade, resolução de 1 mm, DXF de linhas e CSV da
  [versão 005](Notas_Versao_005.md).
- Catálogo inicial de 48 itens vetoriais, incluindo itens médicos/laboratoriais
  e mobiliário de uso geral, com categorias e prévia 2D.
- Dimensões iniciais editáveis e identidade de bloco preservada no EACAD5.
- Operações de mover/copiar/girar/espelhar/redimensionar/excluir o bloco completo;
  desagrupamento disponível para editar os segmentos individuais.
- Exemplos CAD de UBS e ala hospitalar, com anotações de ambientes.
- Exemplos de planejamento de UBS e ala hospitalar, com 14 tarefas cada.
- Exemplo residencial e ferramentas gerais mantidos.
- Biblioteca instalada como componente obrigatório; exemplos como componente opcional.

## Validação prevista na geração

| Suíte | Verificações |
|---|---:|
| Planejador e exemplos | 73 |
| Persistência CAD | 33 |
| Importação DXF | 15 |
| Biblioteca e exemplos de saúde | 59 |
| CAD: interface, blocos e perfis | 67 |
| Gestão, usuários e CSV | 41 |
| Total | 288 |

O resultado efetivo está em qa-tests-006.json. Manifesto, hashes e instalador
ficam em setup e bin. Os três executáveis têm versão 0.6.0.0.

## Limites

Os exemplos são estudos esquemáticos originais, não projetos referenciais oficiais
ou projetos aprovados. As dimensões da biblioteca são envelopes iniciais,
não mínimos normativos. Consulte [Direcionamento para saúde e SUS](Direcionamento_Saude_SUS.md).

EACAD5 lê as versões anteriores e preserva IDs e anotações; versões anteriores
do executável não abrem EACAD5. O CAD continua exclusivamente 2D. A gestão continua
local. Os módulos 3D, sincronização entre computadores, validação normativa
automática, PDF em escala e intercâmbio arquitetônico completo permanecem pendentes.
A inspeção visual manual e a instalação/desinstalação em ambiente limpo não
são declaradas concluídas pelos testes automatizados.
