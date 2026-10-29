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
