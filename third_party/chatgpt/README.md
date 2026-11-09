# Componentes da suíte CHATGPT usados pela plataforma

Cópia de reserva dos componentes da suíte CHATGPT (Lazarus/Free Pascal) usados pelos aplicativos da plataforma.

| Item | Valor |
|---|---|
| Repositório de origem | https://github.com/marcelomaurin/CHATGPT |
| Versão copiada | commit `b31c7df` (26/10/2026) |
| Licença | a do repositório CHATGPT, incluída em [LICENSE](LICENSE) |

## Como os projetos usam

Os projetos Lazarus procuram primeiro o repositório CHATGPT ao lado deste, em `..\CHATGPT\pacote\` (por exemplo `D:\projetos\maurinsoft\CHATGPT`). Esta cópia só é usada quando ele não existe, como na compilação automatizada. É o mesmo arranjo adotado no MultiCNC.

Ao alterar um destes componentes, a alteração deve ser feita primeiro na CHATGPT e depois copiada para cá, mantendo as duas versões iguais.

## Arquivos

| Pasta | Arquivo | Uso |
|---|---|---|
| `AIProjectCore` | `aiprojectduration.pas` | Durações (min, h, d, sem) |
| `AIProjectCore` | `aitaskgraph.pas` | Grafo de tarefas, vínculos TI/II/TT/IT, recusa de ciclo |
| `AIProjectCore` | `aiworkcalendar.pas` | Calendário de trabalho e feriados brasileiros |
| `AIProjectCore` | `aicpmscheduler.pas` | Cronograma pelo caminho crítico |
| `AIProject` | `aiganttview.pas` | Gráfico de Gantt com tabela editável |
| `AIProject` | `ainetworkview.pas` | Diagrama de rede (reservado para a etapa P3 do Planejador) |

## Histórico reutilizado no CAD 2D

`AIProjectCore/aiundohistory.pas` foi copiado sem alterações do repositório local CHATGPT
em 30/10/2026 (HEAD `b31c7dfe528137c59684b15bf5c5a1d9d4340929`). O CAD usa esta cópia para manter a compilação
independente da pasta vizinha. Licença: a mesma GPL incluída neste diretório.
SHA-256 do arquivo copiado: `274bac8b90abfc0fb6da2c3c1d3f2390d8e338d256239368a884d18f9ccd9dc6`.

## Recursos — entrega 007

Cópias sem alterações, obtidas do repositório local CHATGPT em 31/10/2026:

- `AIProjectCore/airesourceload.pas`: cálculo de carga e sobrecarga.
  SHA-256 `7bc0e82cc49c601357b3d794784e1855145e1f0626a02642bf11c31c0b259df5`.
- `AIProject/airesourceview.pas` e `airesourceview_icon.lrs`: visualização de alocações.
  SHA-256 da unidade `4e31aa9451539c688e2cc323194f689de7ce4a2533003eb43a8c84b59d33550c`.

Licença: a mesma incluída neste diretório. O cálculo monetário em centavos é
implementado pela plataforma, conforme as regras de contabilização das tarefas.
