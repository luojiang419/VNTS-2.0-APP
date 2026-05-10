$ErrorActionPreference = 'Stop'

$projectDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$releaseDir = Join-Path $projectDir 'build\windows\x64\runner\Release'
$releaseDataDir = Join-Path $releaseDir 'data'
$runtimeSourceDir = Join-Path $releaseDataDir 'vnts2_runtime'
$bundledSourceDir = Join-Path $releaseDataDir 'flutter_assets\assets\bundled'
$distRoot = Join-Path $projectDir 'dist\portable'
$packageDir = Join-Path $distRoot 'VNTS2_Windows_Portable'
$zipPath = Join-Path $distRoot 'VNTS2_Windows_Portable.zip'
$runtimeDestDir = Join-Path $packageDir 'data\vnts2_runtime'

function Require-Path {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label missing: $Path"
    }
}

function Reset-Path {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Copy-WithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
            return
        } catch {
            $lastError = $_
            Start-Sleep -Milliseconds 400
        }
    }

    throw $lastError
}

function Get-RuntimeSourceFile {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $runtimeCandidate = Join-Path $runtimeSourceDir $FileName
    if (Test-Path -LiteralPath $runtimeCandidate) {
        return $runtimeCandidate
    }
    $bundledCandidate = Join-Path $bundledSourceDir $FileName
    if (Test-Path -LiteralPath $bundledCandidate) {
        return $bundledCandidate
    }
    throw "Runtime file not found: $FileName"
}

Require-Path -Path $releaseDir -Label 'Release directory'
Require-Path -Path (Join-Path $releaseDir 'vnts2_windows.exe') -Label 'Main executable'
Require-Path -Path $releaseDataDir -Label 'Release data directory'
Require-Path -Path (Join-Path $releaseDataDir 'flutter_assets') -Label 'Flutter assets directory'
Require-Path -Path (Join-Path $releaseDataDir 'app.so') -Label 'Flutter AOT file'
Require-Path -Path (Join-Path $releaseDataDir 'icudtl.dat') -Label 'ICU data file'
Require-Path -Path (Get-RuntimeSourceFile -FileName 'vnts2.exe') -Label 'Bundled vnts2.exe'
Require-Path -Path (Get-RuntimeSourceFile -FileName 'config.toml') -Label 'Bundled config.toml'

if (-not (Test-Path -LiteralPath $distRoot)) {
    New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
}
if (Test-Path -LiteralPath $packageDir) {
    Remove-Item -LiteralPath $packageDir -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

Get-ChildItem -LiteralPath $releaseDir -File | ForEach-Object {
    Copy-WithRetry -Source $_.FullName -Destination (Join-Path $packageDir $_.Name)
}

if (Test-Path -LiteralPath (Join-Path $releaseDir 'dlls')) {
    Copy-WithRetry -Source (Join-Path $releaseDir 'dlls') -Destination $packageDir
}

New-Item -ItemType Directory -Force -Path (Join-Path $packageDir 'data') | Out-Null
Get-ChildItem -LiteralPath $releaseDataDir -File | ForEach-Object {
    Copy-WithRetry -Source $_.FullName -Destination (Join-Path $packageDir 'data')
}
Copy-WithRetry -Source (Join-Path $releaseDataDir 'flutter_assets') -Destination (Join-Path $packageDir 'data')

Reset-Path -Path $runtimeDestDir
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDestDir 'logs') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDestDir '.backups') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDestDir 'panel') | Out-Null
Copy-WithRetry -Source (Get-RuntimeSourceFile -FileName 'vnts2.exe') -Destination $runtimeDestDir
Copy-WithRetry -Source (Get-RuntimeSourceFile -FileName 'config.toml') -Destination $runtimeDestDir

$requiredPaths = @(
    (Join-Path $packageDir 'vnts2_windows.exe'),
    (Join-Path $packageDir 'data\app.so'),
    (Join-Path $packageDir 'data\icudtl.dat'),
    (Join-Path $packageDir 'data\flutter_assets'),
    (Join-Path $runtimeDestDir 'vnts2.exe'),
    (Join-Path $runtimeDestDir 'config.toml'),
    (Join-Path $runtimeDestDir 'logs'),
    (Join-Path $runtimeDestDir '.backups'),
    (Join-Path $runtimeDestDir 'panel')
)
foreach ($path in $requiredPaths) {
    Require-Path -Path $path -Label 'Required package path'
}

$forbiddenPaths = @(
    (Join-Path $packageDir 'vnts_bundle'),
    (Join-Path $runtimeDestDir 'cert.pem'),
    (Join-Path $runtimeDestDir 'key.pem'),
    (Join-Path $runtimeDestDir 'network_control.db'),
    (Join-Path $runtimeDestDir 'panel\vnts-auth.json')
)
foreach ($path in $forbiddenPaths) {
    if (Test-Path -LiteralPath $path) {
        throw "Forbidden file found in portable package: $path"
    }
}

$logsDir = Join-Path $runtimeDestDir 'logs'
$backupsDir = Join-Path $runtimeDestDir '.backups'
$panelDir = Join-Path $runtimeDestDir 'panel'

$logEntries = @(Get-ChildItem -Force -LiteralPath $logsDir)
if ($logEntries.Count -ne 0) {
    throw 'Portable package logs directory must be empty.'
}
$backupEntries = @(Get-ChildItem -Force -LiteralPath $backupsDir)
if ($backupEntries.Count -ne 0) {
    throw 'Portable package .backups directory must be empty.'
}
$panelEntries = @(Get-ChildItem -Force -LiteralPath $panelDir)
if ($panelEntries.Count -ne 0) {
    throw 'Portable package panel directory must be empty.'
}

Compress-Archive -LiteralPath $packageDir -DestinationPath $zipPath -CompressionLevel Optimal -Force

$sha256 = [System.Security.Cryptography.SHA256]::Create()
$zipStream = [System.IO.File]::OpenRead($zipPath)
try {
    $zipHash = [System.BitConverter]::ToString($sha256.ComputeHash($zipStream)).Replace('-', '')
} finally {
    $zipStream.Dispose()
    $sha256.Dispose()
}
Write-Host "[OK] Portable directory: $packageDir"
Write-Host "[OK] Portable zip: $zipPath"
Write-Host "[OK] ZIP SHA256: $zipHash"
