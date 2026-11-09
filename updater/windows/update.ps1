# Atualizador do instalador Windows distribuido pelo GitHub Releases.
# Executado pelo launcher sem bloquear a interface. Instala apenas releases
# com SHA256 correspondente e depois que os aplicativos estiverem fechados.
param([switch]$Manual)
$ErrorActionPreference = 'Stop'
$Repo = 'marcelomaurin/EngenhariaArquitetura'
$Api = "https://api.github.com/repos/$Repo/releases/latest"
$AppDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Data = Join-Path $env:LOCALAPPDATA 'EngenhariaArquitetura\updates'
$Status = Join-Path $Data 'status.json'
$Installers = @('engenhariaarquitetura','planejador','cad2d','maquete3d',
    'criadorcenas','eletrica3d','simueletrica','simutubulacoes')
New-Item -ItemType Directory -Force $Data | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Version-Parts([string]$value) {
    if ($value -notmatch '^v?(\d+(?:\.\d+){1,3})$') { throw "Versao invalida: $value" }
    $parts = @($Matches[1].Split('.') | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 4) { $parts += 0 }
    return $parts
}
function Newer([string]$remote, [string]$local) {
    $a = Version-Parts $remote; $b = Version-Parts $local
    for ($i = 0; $i -lt 4; $i++) {
        if ($a[$i] -gt $b[$i]) { return $true }
        if ($a[$i] -lt $b[$i]) { return $false }
    }
    return $false
}
function Save-Status([string]$message) {
    @{ last_check = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds();
       status = $message } | ConvertTo-Json | Set-Content -Encoding UTF8 $Status
}
function Release-Asset($release, [string]$name) {
    $a = @($release.assets | Where-Object { $_.name -eq $name }) | Select-Object -First 1
    if (-not $a) { return $null }
    $url = [string]$a.browser_download_url
    if (-not $url.StartsWith("https://github.com/$Repo/releases/download/")) {
        throw 'Origem do download nao autorizada'
    }
    return $url
}
$lock = $null
try {
    $lock = [System.IO.File]::Open((Join-Path $Data 'updater.lock'),
      [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None)
} catch { exit 0 }
try {
    if ((-not $Manual) -and (Test-Path $Status)) {
        try {
            $old = Get-Content $Status -Raw | ConvertFrom-Json
            if (([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$old.last_check) -lt 86400 -and
                ([string]$old.status -notmatch 'aguardando')) {
                exit 0
            }
        } catch { }
    }
    $installed = '0.0.0'
    $manifest = Join-Path $AppDir 'build-manifest.json'
    if (Test-Path $manifest) {
        $installed = [string](Get-Content $manifest -Raw | ConvertFrom-Json).version
    }
    $release = Invoke-RestMethod -Uri $Api -Headers @{
       'User-Agent'='EA-Updater/1'; 'Accept'='application/vnd.github+json'
    } -TimeoutSec 25
    if ($release.draft -or $release.prerelease) {
        Save-Status 'Sem nova release estavel'; exit 0
    }
    $tag = [string]$release.tag_name
    if (-not (Newer $tag $installed)) {
        Save-Status "Atualizado: $installed"; exit 0
    }
    # O executavel deve vir de uma release, nunca da branch de codigo-fonte.
    $packageAsset = @($release.assets | Where-Object {
      $_.name -match '^setup_engenhariaarquitetura_[0-9]{3}\.exe$'
    }) | Select-Object -First 1
    if (-not $packageAsset) {
        Save-Status "Release $tag ainda sem instalador Windows"; exit 0
    }
    $packageName = [string]$packageAsset.name
    $packageUrl = Release-Asset $release $packageName
    $sumsUrl = Release-Asset $release 'SHA256SUMS'
    if (-not $sumsUrl) {
        Save-Status "Release $tag sem SHA256SUMS"; exit 0
    }
    $sumsFile = Join-Path $Data 'SHA256SUMS.new'
    Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsFile -TimeoutSec 25 -UseBasicParsing
    $entries = @(Get-Content $sumsFile | Where-Object {
        $_ -match '^([a-fA-F0-9]{64})  (.+)$' -and $Matches[2] -eq $packageName
    })
    if ($entries.Count -ne 1 -or $entries[0] -notmatch '^([a-fA-F0-9]{64})  ') {
        throw 'Checksum da release nao encontrado ou ambiguo'
    }
    $sha = $Matches[1].ToLowerInvariant()
    $packageFile = Join-Path $Data $packageName
    $tempFile = "$packageFile.part"
    Invoke-WebRequest -Uri $packageUrl -OutFile $tempFile -TimeoutSec 600 -UseBasicParsing
    if ((Get-Item $tempFile).Length -gt 500MB) { throw 'Pacote grande demais' }
    $actual = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $sha) {
        Remove-Item $tempFile -Force
        throw 'SHA256 nao confere. Instalacao cancelada.'
    }
    Move-Item -Path $tempFile -Destination $packageFile -Force
    Save-Status "Pacote $tag pronto; aguardando fechamento dos aplicativos"
    # Nao encerra projetos ou fecha aplicativos com alteracoes nao salvas.
    $deadline = (Get-Date).AddMinutes(20)
    do {
        $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
           $Installers -contains $_.ProcessName
        })
        if ($running.Count -eq 0) { break }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    if ($running.Count -ne 0) {
        Save-Status "Pacote $tag aguardando aplicativos fechados"; exit 0
    }
    # O Inno Setup instalado em Program Files pode solicitar autorizacao UAC.
    $proc = Start-Process -FilePath $packageFile -ArgumentList @(
      '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOCLOSEAPPLICATIONS'
    ) -PassThru -Wait
    if ($proc.ExitCode -ne 0) { throw "Instalador retornou codigo $($proc.ExitCode)" }
    Save-Status "Versao $tag instalada"
} catch {
    Save-Status ("Falha: " + $_.Exception.Message)
    if ($Manual) { Write-Output $_.Exception.Message; exit 1 }
} finally {
    if ($lock) { $lock.Dispose() }
}
