$ErrorActionPreference = 'Stop'

$projectDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$repoRoot = Resolve-Path (Join-Path $projectDir '..')
$flutterBin = 'D:\APPdata\flutter\bin\flutter.bat'
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

if (-not (Test-Path -LiteralPath $flutterBin)) {
    throw "Flutter not found: $flutterBin"
}

$env:PATH = "D:\APPdata\flutter\bin;$env:PATH"

Push-Location $vntsSrc
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed: $LASTEXITCODE" }
} finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path $bundledDir | Out-Null
Copy-Item -Force -LiteralPath (Join-Path $vntsSrc 'target\release\vnts2.exe') -Destination (Join-Path $bundledDir 'vnts2.exe')
Copy-Item -Force -LiteralPath $defaultConfig -Destination (Join-Path $bundledDir 'config.toml')

& (Join-Path $PSScriptRoot 'gen_bridge.ps1')
if ($LASTEXITCODE -ne 0) { throw "FRB codegen failed: $LASTEXITCODE" }

Push-Location $projectDir
try {
    & $flutterBin pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed: $LASTEXITCODE" }

    & $flutterBin run -d windows
    if ($LASTEXITCODE -ne 0) { throw "flutter run failed: $LASTEXITCODE" }
} finally {
    Pop-Location
}
