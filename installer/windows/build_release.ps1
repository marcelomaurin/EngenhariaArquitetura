# Gera o instalador Windows x64 da plataforma EngenhariaArquitetura.
# Mesmos passos e saidas do build_release_wine.sh.
#
#   installer\windows\build_release.bat [-Version 0.01] [-SetupSeq 001] [-AllowDirty]
#
# Sem parametros, versao e sequencia vem de installer\VERSION.ini.
# Ferramentas: LAZBUILD, FPC, PYTHON e ISCC podem ser definidas por variavel de
# ambiente; senao sao procuradas nas pastas usuais. EA_CHATGPT_DIR aponta para o
# repositorio CHATGPT (padrao: ..\CHATGPT ao lado deste repositorio).
param(
  [string]$Version = "",
  [string]$SetupSeq = "",
  [switch]$AllowDirty
)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Root

function Ini([string]$Key) {
  $line = Get-Content "installer\VERSION.ini" | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
  return ($line -replace "^$Key=", "").Trim()
}
function Find-Tool([string]$Env, [string[]]$Candidates) {
  $v = [Environment]::GetEnvironmentVariable($Env)
  if ($v -and (Test-Path $v)) { return $v }
  foreach ($c in $Candidates) { $f = Get-Command $c -ErrorAction SilentlyContinue; if ($f) { return $f.Source }; if (Test-Path $c) { return $c } }
  throw "Ferramenta nao encontrada: defina $Env"
}
if (-not $Version) { $Version = Ini "AppVersion" }
if (-not $SetupSeq) { $SetupSeq = Ini "SetupSeq" }
if ($SetupSeq -notmatch '^\d{3}$') { throw "SetupSeq invalido: $SetupSeq" }
if (-not $AllowDirty -and (git status --porcelain -- . ':!bin' ':!setup' ':!dist')) { throw "A release exige uma arvore Git limpa. Para build local use -AllowDirty." }

$Lazbuild = Find-Tool "LAZBUILD" @("lazbuild.exe", "C:\lazarus\lazbuild.exe")
$FpcCandidates = @(Get-ChildItem "C:\lazarus\fpc\*\bin\x86_64-win64\fpc.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) + @("fpc.exe")
$Fpc = Find-Tool "FPC" $FpcCandidates
$Python = Find-Tool "PYTHON" @("python.exe", "py.exe")
$Iscc = Find-Tool "ISCC" @("ISCC.exe", "C:\Program Files (x86)\Inno Setup 6\ISCC.exe", "C:\Program Files\Inno Setup 6\ISCC.exe", "C:\Program Files (x86)\Inno Setup 7\ISCC.exe", "C:\Program Files\Inno Setup 7\ISCC.exe")
$Chatgpt = if ($env:EA_CHATGPT_DIR) { $env:EA_CHATGPT_DIR } else { Join-Path (Split-Path $Root -Parent) "CHATGPT" }
$Core = Join-Path $Root "third_party\chatgpt\AIProjectCore"
if (Test-Path (Join-Path $Chatgpt "pacote\AI Project Core")) { $Core = Join-Path $Chatgpt "pacote\AI Project Core" }

$Dist = Join-Path $Root "dist"; $App = Join-Path $Dist "app"; $Bin = Join-Path $Root "bin"
if (Test-Path $App) { Remove-Item -Recurse -Force $App }
New-Item -ItemType Directory -Force $App, $Bin, (Join-Path $Dist "build-logs"), (Join-Path $Dist "tests"), "setup" | Out-Null

$Targets = @(
  @{ Project = "planejador\src\app\planejador"; Name = "planejador" },
  @{ Project = "launcher\src\app\engenhariaarquitetura"; Name = "engenhariaarquitetura" },
  @{ Project = "cad2d\src\app\cad2d"; Name = "cad2d" }
)
foreach ($t in $Targets) {
  Write-Host "Compilando $($t.Name)..."
  $log = Join-Path $Dist "build-logs\$($t.Name).log"
  & $Lazbuild -B --cpu=x86_64 --os=win64 --ws=win32 --build-mode=Default "$($t.Project).lpi" *> $log
  if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 35; throw "Falha ao compilar $($t.Name)" }
  Copy-Item (Join-Path $Bin "$($t.Name).exe") (Join-Path $App "$($t.Name).exe") -Force
}

# Gerar os exemplos de saude a partir dos fontes e do catalogo distribuido.
New-Item -ItemType Directory -Force (Join-Path $Dist "tools\units") | Out-Null
$genArgs = @("-Px86_64", "-Twin64", "-Mobjfpc", "-Sh", "-Fu$Root\shared", "-Fu$Root\cad2d\src\app", "-Fu$Root\planejador\src\core", "-Fu$Root\planejador\src\io", "-Fu$Core", "-FU$Dist\tools\units", "-o$Dist\tools\gerar_exemplos_saude.exe", "planejador\tools\gerar_exemplos_saude.lpr")
& $Fpc @genArgs *> (Join-Path $Dist "build-logs\gerar_exemplos_saude.log")
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\gerar_exemplos_saude.log") -Tail 20; throw "Falha ao compilar gerador de exemplos" }
& (Join-Path $Dist "tools\gerar_exemplos_saude.exe") $Root
if ($LASTEXITCODE -ne 0) { throw "Falha ao gerar exemplos de saude" }

Write-Host "Testes de console..."
$Tests = @(
  @{ Source = "planejador\tests\test_planejador_core"; Paths = @("planejador\src\core", "planejador\src\io") },
  @{ Source = "cad2d\tests\test_cad_document"; Paths = @("cad2d\src\app", "shared") },
  @{ Source = "cad2d\tests\test_cad_dxf"; Paths = @("cad2d\src\app", "shared") },
  @{ Source = "cad2d\tests\test_cad_catalog"; Paths = @("cad2d\src\app", "shared") },
  @{ Source = "shared\tests\test_config"; Paths = @("shared") },
  @{ Source = "planejador\tests\test_recursos"; Paths = @("planejador\src\core", "planejador\src\io", "shared") },
  @{ Source = "planejador\tests\test_sprints"; Paths = @("planejador\src\core", "planejador\src\io", "shared") },
  @{ Source = "planejador\tests\test_relatorios_sprint"; Paths = @("planejador\src\core", "planejador\src\io", "shared") }
)
$qa = @()
foreach ($t in $Tests) {
  $name = Split-Path $t.Source -Leaf
  $out = Join-Path $Dist "tests\$name"
  New-Item -ItemType Directory -Force $out | Out-Null
  $fpcArgs = @("-Px86_64", "-Twin64", "-Mobjfpc", "-Sh", "-FU$out") + ($t.Paths | ForEach-Object { "-Fu$Root\$_" }) + @("-Fu$Core", "-Fu$Root\shared", "-o$out.exe", "$($t.Source).lpr")
  & $Fpc @fpcArgs *> (Join-Path $Dist "build-logs\$name.log")
  if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\$name.log") -Tail 20; throw "Falha ao compilar $name" }
  $run = & "$out.exe" 2>&1
  $ok = $LASTEXITCODE -eq 0
  $summary = ($run | Select-Object -Last 1)
  Write-Host "  ${name}: $summary"
  $qa += [ordered]@{ test = $name; passed = $ok; summary = "$summary" }
  if (-not $ok) { $run; throw "Testes falharam: $name" }
}
# Regressao do CAD: controles LCL, camadas, zoom, atalhos e historico CHATGPT.
& $Lazbuild -B --cpu=x86_64 --os=win64 --ws=win32 "cad2d\tests\test_cad2d.lpi" *> (Join-Path $Dist "build-logs\test_cad2d.log")
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\test_cad2d.log") -Tail 20; throw "Falha ao compilar testes CAD 2D" }
$cadRun = & (Join-Path $Dist "tests\test_cad2d.exe") 2>&1
$cadOK = $LASTEXITCODE -eq 0
$cadSummary = "$($cadRun | Select-Object -Last 1)"
Write-Host "  test_cad2d: $cadSummary"
$qa += [ordered]@{ test = "test_cad2d"; passed = $cadOK; summary = $cadSummary }
if (-not $cadOK) { $cadRun; throw "Testes CAD 2D falharam" }

& $Lazbuild -B --cpu=x86_64 --os=win64 --ws=win32 "planejador\tests\test_recursos_ui.lpi" *> (Join-Path $Dist "build-logs\test_recursos_ui.log")
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\test_recursos_ui.log") -Tail 25; throw "Falha ao compilar interface de recursos" }
$resourceRun = & (Join-Path $Dist "tests\test_recursos_ui.exe") 2>&1
$resourceOK = $LASTEXITCODE -eq 0
$resourceSummary = "$($resourceRun | Select-Object -Last 1)"
Write-Host "  test_recursos_ui: $resourceSummary"
$qa += [ordered]@{ test = "test_recursos_ui"; passed = $resourceOK; summary = $resourceSummary }
if (-not $resourceOK) { $resourceRun; throw "Testes da interface de recursos falharam" }

& $Lazbuild -B --cpu=x86_64 --os=win64 --ws=win32 "planejador\tests\test_acompanhamento_ui.lpi" *> (Join-Path $Dist "build-logs\test_acompanhamento_ui.log")
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\test_acompanhamento_ui.log") -Tail 25; throw "Falha ao compilar interface de acompanhamento" }
$followRun = & (Join-Path $Dist "tests\test_acompanhamento_ui.exe") 2>&1
$followOK = $LASTEXITCODE -eq 0
$followSummary = "$($followRun | Select-Object -Last 1)"
Write-Host "  test_acompanhamento_ui: $followSummary"
$qa += [ordered]@{ test = "test_acompanhamento_ui"; passed = $followOK; summary = $followSummary }
if (-not $followOK) { $followRun; throw "Testes de acompanhamento falharam" }

& $Lazbuild -B --cpu=x86_64 --os=win64 --ws=win32 "planejador\tests\test_relatorios_sprint_ui.lpi" *> (Join-Path $Dist "build-logs\test_relatorios_sprint_ui.log")
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\test_relatorios_sprint_ui.log") -Tail 25; throw "Falha ao compilar interface de relatórios de sprint" }
$sprintReportRun = & (Join-Path $Dist "tests\test_relatorios_sprint_ui.exe") 2>&1
$sprintReportOK = $LASTEXITCODE -eq 0
$sprintReportSummary = "$($sprintReportRun | Select-Object -Last 1)"
Write-Host "  test_relatorios_sprint_ui: $sprintReportSummary"
$qa += [ordered]@{ test = "test_relatorios_sprint_ui"; passed = $sprintReportOK; summary = $sprintReportSummary }
if (-not $sprintReportOK) { $sprintReportRun; throw "Testes de relatórios de sprint falharam" }

$wfOut = Join-Path $Dist "tests\workflow-units"
New-Item -ItemType Directory -Force $wfOut | Out-Null
$wfArgs = @("-Px86_64", "-Twin64", "-Mobjfpc", "-Sh", "-Fu$Root\shared", "-FU$wfOut", "-o$Dist\tests\test_workflow.exe", "shared\tests\test_workflow.lpr")
& $Fpc @wfArgs *> (Join-Path $Dist "build-logs\test_workflow.log")
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\test_workflow.log") -Tail 20; throw "Falha ao compilar testes de gestao" }
$wfRun = & (Join-Path $Dist "tests\test_workflow.exe") 2>&1
$wfOK = $LASTEXITCODE -eq 0
$wfSummary = "$($wfRun | Select-Object -Last 1)"
Write-Host "  test_workflow: $wfSummary"
$qa += [ordered]@{ test = "test_workflow"; passed = $wfOK; summary = $wfSummary }
if (-not $wfOK) { $wfRun; throw "Testes de gestao falharam" }

[System.IO.File]::WriteAllText((Join-Path $App "qa-tests.json"), (ConvertTo-Json -InputObject @($qa)), [System.Text.UTF8Encoding]::new($false))

New-Item -ItemType Directory -Force (Join-Path $App "documentation\docs"), (Join-Path $App "exemplos"), (Join-Path $App "licencas") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $App "documentation\libraries") | Out-Null
Copy-Item libraries\README.md (Join-Path $App "documentation\libraries")
Copy-Item README.md (Join-Path $App "documentation")
Copy-Item docs\*.md (Join-Path $App "documentation\docs")
Copy-Item planejador\README.md (Join-Path $App "documentation\Planejador_README.md")
Copy-Item cad2d\README.md (Join-Path $App "documentation\CAD2D_README.md")
Copy-Item planejador\examples\*.plan.json (Join-Path $App "exemplos")
Copy-Item planejador\examples\*.html (Join-Path $App "exemplos")
Copy-Item planejador\examples\*.csv (Join-Path $App "exemplos")
Copy-Item cad2d\examples\*.eacad (Join-Path $App "exemplos")
New-Item -ItemType Directory -Force (Join-Path $App "bibliotecas") | Out-Null
Copy-Item libraries\catalogo_2d.json (Join-Path $App "bibliotecas")
Copy-Item third_party\chatgpt\LICENSE (Join-Path $App "licencas\CHATGPT_LICENSE.txt")
if (Test-Path "samples") {
  Copy-Item -Recurse -Force "samples" (Join-Path $App "samples")
}
if (Test-Path "updater\windows\update.ps1") {
  New-Item -ItemType Directory -Force (Join-Path $App "updater\windows") | Out-Null
  Copy-Item "updater\windows\update.ps1" (Join-Path $App "updater\windows\update.ps1")
}

$clean = @("--require-clean"); if ($AllowDirty) { $clean = @() }
& $Python tools\release_manifest.py --app-dir $App --version $Version --seq $SetupSeq --version-include (Join-Path $Dist "version.iss") @clean
if ($LASTEXITCODE -ne 0) { throw "Falha no manifesto" }
& $Python installer\windows\prepare_images.py --version $Version --out (Join-Path $Dist "installer-images")
if ($LASTEXITCODE -ne 0) { throw "Falha nas imagens do instalador" }

$Name = "setup_engenhariaarquitetura_$SetupSeq"
& $Iscc /Q "/dSetupSeq=$SetupSeq" "/dOutputExeName=$Name" "installer\windows\engenhariaarquitetura.iss"
if ($LASTEXITCODE -ne 0) { throw "Falha no Inno Setup" }
Copy-Item (Join-Path $Dist "$Name.exe") $Bin -Force
Copy-Item (Join-Path $Dist "$Name.exe") "setup" -Force
$hash = (Get-FileHash (Join-Path $Dist "$Name.exe") -Algorithm SHA256).Hash.ToLower()
$sums = @(); if (Test-Path "setup\SHA256SUMS") { $sums = @(Get-Content "setup\SHA256SUMS" | Where-Object { $_ -and ($_ -notlike "*  $Name.exe") }) }
$sums += "$hash  $Name.exe"
$sums | Set-Content -Encoding ASCII "setup\SHA256SUMS"
Copy-Item (Join-Path $App "build-manifest.json") "setup\build-manifest-$SetupSeq.json" -Force
Copy-Item (Join-Path $App "qa-tests.json") "setup\qa-tests-$SetupSeq.json" -Force
Write-Host "Setup gerado: bin\$Name.exe"
