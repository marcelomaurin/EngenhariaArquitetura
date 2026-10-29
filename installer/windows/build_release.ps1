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
if (-not $AllowDirty -and (git status --porcelain)) { throw "A release exige uma arvore Git limpa. Para build local use -AllowDirty." }

$Lazbuild = Find-Tool "LAZBUILD" @("lazbuild.exe", "C:\lazarus\lazbuild.exe")
$FpcCandidates = @("fpc.exe") + @(Get-ChildItem "C:\lazarus\fpc\*\bin\x86_64-win64\fpc.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$Fpc = Find-Tool "FPC" $FpcCandidates
$Python = Find-Tool "PYTHON" @("python.exe", "py.exe")
$Iscc = Find-Tool "ISCC" @("ISCC.exe", "C:\Program Files (x86)\Inno Setup 6\ISCC.exe", "C:\Program Files\Inno Setup 6\ISCC.exe", "C:\Program Files (x86)\Inno Setup 7\ISCC.exe")
$Chatgpt = if ($env:EA_CHATGPT_DIR) { $env:EA_CHATGPT_DIR } else { Join-Path (Split-Path $Root -Parent) "CHATGPT" }
$Core = Join-Path $Root "third_party\chatgpt\AIProjectCore"
if (Test-Path (Join-Path $Chatgpt "pacote\AI Project Core")) { $Core = Join-Path $Chatgpt "pacote\AI Project Core" }

$Dist = Join-Path $Root "dist"; $App = Join-Path $Dist "app"; $Bin = Join-Path $Root "bin"
if (Test-Path $App) { Remove-Item -Recurse -Force $App }
New-Item -ItemType Directory -Force $App, $Bin, (Join-Path $Dist "build-logs"), (Join-Path $Dist "tests"), "setup" | Out-Null

$Targets = @(@{ Project = "planejador\src\app\planejador"; Name = "planejador" })
foreach ($t in $Targets) {
  Write-Host "Compilando $($t.Name)..."
  $log = Join-Path $Dist "build-logs\$($t.Name).log"
  & $Lazbuild -B --cpu=x86_64 --os=win64 --ws=win32 --build-mode=Default "$($t.Project).lpi" *> $log
  if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 35; throw "Falha ao compilar $($t.Name)" }
  Copy-Item (Join-Path $Bin "$($t.Name).exe") (Join-Path $App "$($t.Name).exe") -Force
}

Write-Host "Testes de console..."
$Tests = @(@{ Source = "planejador\tests\test_planejador_core"; Paths = @("planejador\src\core", "planejador\src\io") })
$qa = @()
foreach ($t in $Tests) {
  $name = Split-Path $t.Source -Leaf
  $out = Join-Path $Dist "tests\$name"
  New-Item -ItemType Directory -Force $out | Out-Null
  $fpcArgs = @("-Px86_64", "-Twin64", "-Mobjfpc", "-Sh", "-FU$out") + ($t.Paths | ForEach-Object { "-Fu$Root\$_" }) + @("-Fu$Core", "-o$out.exe", "$($t.Source).lpr")
  & $Fpc @fpcArgs *> (Join-Path $Dist "build-logs\$name.log")
  if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $Dist "build-logs\$name.log") -Tail 20; throw "Falha ao compilar $name" }
  $run = & "$out.exe" 2>&1
  $ok = $LASTEXITCODE -eq 0
  $summary = ($run | Select-Object -Last 1)
  Write-Host "  ${name}: $summary"
  $qa += [ordered]@{ test = $name; passed = $ok; summary = "$summary" }
  if (-not $ok) { $run; throw "Testes falharam: $name" }
}
ConvertTo-Json -InputObject @($qa) | Set-Content -Encoding UTF8 (Join-Path $App "qa-tests.json")

New-Item -ItemType Directory -Force (Join-Path $App "documentation\docs"), (Join-Path $App "exemplos"), (Join-Path $App "licencas") | Out-Null
Copy-Item README.md (Join-Path $App "documentation")
Copy-Item docs\*.md (Join-Path $App "documentation\docs")
Copy-Item planejador\README.md (Join-Path $App "documentation\Planejador_README.md")
Copy-Item planejador\examples\*.plan.json (Join-Path $App "exemplos")
Copy-Item third_party\chatgpt\LICENSE (Join-Path $App "licencas\CHATGPT_LICENSE.txt")

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
$sums = @(); if (Test-Path "setup\SHA256SUMS") { $sums = Get-Content "setup\SHA256SUMS" | Where-Object { $_ -and ($_ -notlike "*  $Name.exe") } }
$sums += "$hash  $Name.exe"
$sums | Set-Content -Encoding ASCII "setup\SHA256SUMS"
Copy-Item (Join-Path $App "build-manifest.json") "setup\build-manifest-$SetupSeq.json" -Force
Copy-Item (Join-Path $App "qa-tests.json") "setup\qa-tests-$SetupSeq.json" -Force
Write-Host "Setup gerado: bin\$Name.exe"
