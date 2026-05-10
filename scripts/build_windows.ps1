$ErrorActionPreference = 'Stop'

$projectDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$repoRoot = Resolve-Path (Join-Path $projectDir '..')
$flutterBin = 'D:\APPdata\flutter\bin\flutter.bat'
$rustCargoDir = Join-Path $env:USERPROFILE '.cargo\bin'
$serverPackageDir = Get-ChildItem -LiteralPath $repoRoot -Directory | Where-Object {
    (Test-Path (Join-Path $_.FullName 'official-vnts-source-2.0.0')) -and
    (Test-Path (Join-Path $_.FullName 'windows-deploy\config.toml'))
} | Select-Object -First 1
if ($null -eq $serverPackageDir) {
    throw "未找到包含 official-vnts-source-2.0.0 和 windows-deploy 的 VNTS 服务端开发包目录。"
}
$vntsSrc = Resolve-Path (Join-Path $serverPackageDir.FullName 'official-vnts-source-2.0.0')
$defaultConfig = Resolve-Path (Join-Path $serverPackageDir.FullName 'windows-deploy\config.toml')
$bundledDir = Join-Path $projectDir 'assets\bundled'
$vntsOutput = Join-Path $vntsSrc 'target\release\vnts2.exe'
$releaseDir = Join-Path $projectDir 'build\windows\x64\runner\Release'
$portableRuntimeDir = Join-Path $releaseDir 'data\vnts2_runtime'

function Copy-WithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            Copy-Item -Force -LiteralPath $Source -Destination $Destination
            return
        } catch {
            $lastError = $_
            Start-Sleep -Milliseconds 400
        }
    }

    throw $lastError
}

if (-not (Test-Path -LiteralPath $flutterBin)) {
    throw "Flutter not found: $flutterBin"
}

if (Test-Path -LiteralPath (Join-Path $rustCargoDir 'cargo.exe')) {
    $env:PATH = "$rustCargoDir;$env:PATH"
}

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'cargo not found in PATH. Please install Rust stable toolchain first.'
}

$env:CARGO_NET_GIT_FETCH_WITH_CLI = 'true'

Push-Location $projectDir
try {
    & $flutterBin config --enable-windows-desktop
    if ($LASTEXITCODE -ne 0) { throw "flutter config failed: $LASTEXITCODE" }

    Push-Location $vntsSrc
    try {
        cargo build --release
        if ($LASTEXITCODE -ne 0) { throw "cargo build failed: $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

    New-Item -ItemType Directory -Force -Path $bundledDir | Out-Null
    Copy-WithRetry -Source $vntsOutput -Destination (Join-Path $bundledDir 'vnts2.exe')
    Copy-WithRetry -Source $defaultConfig -Destination (Join-Path $bundledDir 'config.toml')

    & (Join-Path $PSScriptRoot 'gen_bridge.ps1')
    if ($LASTEXITCODE -ne 0) { throw "FRB codegen failed: $LASTEXITCODE" }

    & $flutterBin pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed: $LASTEXITCODE" }

    & $flutterBin build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed: $LASTEXITCODE" }

    New-Item -ItemType Directory -Force -Path $portableRuntimeDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $portableRuntimeDir 'logs') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $portableRuntimeDir '.backups') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $portableRuntimeDir 'panel') | Out-Null
    Copy-WithRetry -Source (Join-Path $bundledDir 'vnts2.exe') -Destination (Join-Path $portableRuntimeDir 'vnts2.exe')
    Copy-WithRetry -Source (Join-Path $bundledDir 'config.toml') -Destination (Join-Path $portableRuntimeDir 'config.toml')

    Write-Host "[OK] Build finished: $releaseDir"
} finally {
    Pop-Location
}
