# Versão 0.05 — instalador 005

Data: 31/10/2026. Windows 64 bits. Esta entrega corrige a base de dados do CAD
e do Planejador; não conclui todos os módulos previstos para a plataforma.

## Corrigido e implementado

1. O CAD grava EACAD4 com altura, peitoril, largura, tipo, camada, grupo,
   grade em mm, visibilidade e bloqueio das oito camadas. Antes, altura e
   peitoril voltavam aos valores padrão ao reabrir.
2. EACAD1, EACAD2 e EACAD3 continuam legíveis. As coordenadas antigas são
   convertidas para milímetros preservando suas medidas físicas. Valores que
   nunca foram gravados no arquivo antigo recebem padrões por tipo de objeto;
   dimensões antigas já perdidas não podem ser recuperadas automaticamente.
3. O modelo usa resolução de 1 mm, independente do zoom. Comprimentos numéricos
   ortogonais como 3073 mm não são mais arredondados a múltiplos de 50 mm.
   Diagonais seguem a direção do cursor quando o ortogonal está desligado.
4. O CAD e o Planejador gravam em arquivo temporário, confirmam a escrita e
   substituem o destino. Erros de validação e falhas de substituição preservam
   o arquivo anterior. O documento continua marcado como alterado se não for salvo.
5. A leitura do CAD valida integralmente um documento temporário antes da troca.
   O Planejador também recusa duração negativa, progresso inválido, estado
   desconhecido, ciclos, autovínculos e dependências duplicadas.
6. O enquadramento inicial aguarda o tamanho final da janela. A grade visual
   adapta sua densidade ao zoom sem alterar o passo de captura configurado.
7. Arquivo → Importar DXF (linhas) lê DXF ASCII com entidades LINE em X/Y.
   Converte milímetros, centímetros, metros, polegadas e pés; arredonda a 1 mm
   e informa arredondamentos. Sem unidade declarada, informa a hipótese de mm.
   Outras entidades e linhas fora do plano XY são ignoradas e contabilizadas.
   Camadas conhecidas são preservadas; outras são mapeadas para ARQ_PAREDES com aviso.
   A importação exige confirmação e protege alterações existentes.
8. Gestão → Exportar CSV exporta as tarefas permitidas ao usuário. O perfil
   restrito não exporta tarefas alheias. O CSV usa UTF-8 e neutraliza valores
   que poderiam ser interpretados como fórmulas por planilhas.

EACAD4 não pode ser aberto por executáveis anteriores. Preserve uma cópia dos
arquivos antigos se precisar continuar usando versões anteriores.

## Verificação automatizada

| Suíte | Verificações |
|---|---:|
| Núcleo do Planejador e integridade de arquivos | 67 |
| CAD: interface, geometria, dimensões e perfis | 54 |
| Gestão, usuários, permissões e CSV | 41 |
| Persistência CAD e gravação segura | 33 |
| Importação DXF 2D | 15 |
| Total | 210 |

O resultado efetivo da geração está em `setup/qa-tests-005.json`; hashes e
proveniência estão em `setup/build-manifest-005.json` e `setup/SHA256SUMS`.
Os três executáveis são recompilados com versão 0.5.0.0. A inspeção visual do
fluxo completo e os testes de instalação/desinstalação permanecem separados
dos testes automatizados e não são declarados concluídos por esta tabela.

## Ainda pendente

- Geometria em dupla precisão, cotas associativas, ambientes/áreas, vínculo
  paramétrico completo de aberturas e paredes e intercâmbio arquitetônico completo.
- DXF com arcos, círculos, polilinhas e blocos; DWG nativo e PDF em escala.
- Serviço central de contas/tarefas, sincronização entre computadores e
  resolução de conflitos entre cópias. A gestão continua local, com os limites
  descritos no [guia de gestão](Gestao_Tarefas_Usuarios.md).
- Recursos/custos, linha de base, Curva S e relatórios gráficos completos.
- Implementação dos módulos 3D, elétrica e tubulações em seus próprios aplicativos.
- Publicação GitHub: depende da confirmação do destino já solicitada.

O CAD continua exclusivamente 2D. O histórico de geometria continua usando
AI Project Core/aiundohistory do projeto CHATGPT.

Referências do leitor DXF:
[LINE](https://help.autodesk.com/cloudhelp/2020/ENU/AutoCAD-DXF/files/GUID-FCEF5726-53AE-4C43-B4EA-C84EB8686A66.htm) e
[INSUNITS](https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-Core/files/GUID-A58A87BB-482B-4042-A00A-EEF55A2B4FD8.htm), Autodesk.
