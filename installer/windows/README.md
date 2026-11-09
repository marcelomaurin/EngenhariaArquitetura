# Instalador oficial para Windows

Este diretório contém os scripts e configurações para gerar o instalador oficial do
Engenharia e Arquitetura no Windows 64-bit utilizando o Inno Setup.

## Pré-requisitos para compilação

- Windows 10/11 64-bit
- Inno Setup 6.x ou superior (comando `iscc` disponível no PATH)
- Free Pascal / Lazarus (para compilar os executáveis)
- Python 3.8+ (para preparação de recursos e manifesto)
- Git (para metadados de versão)

## Como gerar o instalador

Execute o script PowerShell a partir da raiz do repositório:

```powershell
.\installer\windows\build_release.ps1 -Version 0.09 -SetupSeq 009 -AllowDirty
```

## Estrutura do pacote

O instalador distribui:
- `engenhariaarquitetura.exe` — Central de Aplicativos
- `planejador.exe` — Planejador de Obras
- `cad2d.exe` — CAD Arquitetônico 2D
- `samples/` — Modelos demonstrativos (DWG, DXF, IFC, EACAD)
- `bibliotecas/` — Catálogo 2D de itens arquitetônicos e de saúde
- `exemplos/` — Arquivos `.plan.json`, `.eacad`, `.html` e `.csv`
- `documentation/` — Manuais e notas de versão
- `updater/windows/update.ps1` — Atualizador automático integrado

## Histórico de versões do instalador

- **001 / 002:** Versões iniciais de validação do instalador.
- **003:** Inclusão do CAD 2D e modelos de hospital.
- **004:** Gestão de tarefas e usuários local integrada com 4 perfis de acesso.
- **005:** Melhorias de confiabilidade, formato EACAD4 e DXF.
- **006:** Catálogo 2D de saúde e SUS (UBS e ala hospitalar).
- **007:** Gestão de recursos, arquivos opcionais e custos compostos.
- **008:** Acompanhamento por Sprints, TO-DO e evolução semanal de custos.
- **009:** Relatórios por sprint, carga por usuário e apontamentos diários de horas.
- **010:** Interoperabilidade BIM/CAD (DXF, DWG, IFC), amostras de engenharia e release 0.10.
