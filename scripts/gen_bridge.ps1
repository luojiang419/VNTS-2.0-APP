$ErrorActionPreference = 'Stop'

$projectDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$codegen = Join-Path $env:USERPROFILE '.cargo\bin\flutter_rust_bridge_codegen.exe'

if (-not (Test-Path -LiteralPath $codegen)) {
    throw "flutter_rust_bridge_codegen not found: $codegen"
}

$env:RUST_LOG = 'info'
$env:PATH = "D:\APPdata\flutter\bin;$env:PATH"

Push-Location $projectDir
try {
    $outputLines = @()
    $cmdLine = "`"$codegen`" generate -r crate::api -d `"$projectDir\lib\src\rust`" --rust-root `"$projectDir\rust`""
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & cmd /c $cmdLine 2>&1 | ForEach-Object {
            $outputLines += $_.ToString()
            $_
        }
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($LASTEXITCODE -ne 0) {
        $joined = $outputLines -join [Environment]::NewLine
        $generatedRust = Join-Path $projectDir 'rust\src\frb_generated.rs'
        $generatedDart = Join-Path $projectDir 'lib\src\rust\frb_generated.dart'
        if (($joined -match 'os error 1224') -and (Test-Path -LiteralPath $generatedRust) -and (Test-Path -LiteralPath $generatedDart)) {
            Write-Warning 'flutter_rust_bridge codegen encountered a transient file lock during formatting; existing generated files will be reused.'
            $global:LASTEXITCODE = 0
        } else {
            throw "flutter_rust_bridge codegen failed with exit code $LASTEXITCODE"
        }
    }
    Write-Host "[OK] flutter_rust_bridge code generated."
} finally {
    Pop-Location
}
