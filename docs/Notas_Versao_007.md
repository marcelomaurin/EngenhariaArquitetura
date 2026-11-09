# Versão 0.07 — instalador 007

Entrega da etapa Recursos do Planejador, com arquivos opcionais e custos compostos.

- Cadastro de pessoas, equipes, equipamentos, consumíveis e arquivos/links.
- Usuários vinculados, importação de usuários e executor como recurso.
- Capacidade, calendário, disponibilidade e ausências; carga visual e alertas.
- Alocações múltiplas por tarefa, dedicação/quantidade e preços preservados.
- Arquivos opcionais de entrada/saída, incluindo entregas futuras.
- Custos diretos compostos, consumíveis sempre de entrada, contabilização e totais
  de saída da tarefa e do projeto, sem duplicação de subtotais.
- Arquivos e totais acompanham a tarefa até o CAD; retorno atualiza os vínculos.
- Setup compartilhado e todas as melhorias anteriores preservados.
- Exemplos de UBS e ala hospitalar com recursos e valores fictícios demonstrativos.

O Planejador continua de uso geral, direcionado também à saúde/SUS. O CAD é 2D.
Consulte [Recursos, arquivos e custos](Recursos_Arquivos_Custos.md) para operação,
fórmulas e limites. O esquema de projeto 1.1 lê os arquivos anteriores; use a versão
atual para preservar os novos campos ao salvar.

## Validação

| Suíte | Verificações |
|---|---:|
| Planejador e exemplos | 95 |
| Persistência CAD | 33 |
| DXF 2D | 15 |
| Biblioteca e exemplos de saúde | 59 |
| Configuração compartilhada | 26 |
| Recursos, arquivos e custos | 57 |
| Interface CAD | 68 |
| Interface de recursos e custos | 15 |
| Gestão, usuários, arquivos e permissões | 49 |
| Total | 417 |

O resultado efetivo é `setup/qa-tests-007.json`. Os três executáveis são Windows x64,
versão 0.7.0.0. Manifesto e hashes acompanham o instalador. A ferramenta de inspeção
de janelas não disponibilizou a prévia gráfica para captura; a revisão visual
manual completa e instalação/desinstalação em ambiente limpo não são declaradas
concluídas pelos testes automatizados.
