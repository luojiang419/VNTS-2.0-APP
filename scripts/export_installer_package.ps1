$ErrorActionPreference = 'Stop'

$projectDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$portableScript = Join-Path $PSScriptRoot 'export_portable_package.ps1'
$portableRoot = Join-Path $projectDir 'dist\portable'
$portableZipPath = Join-Path $portableRoot 'VNTS2_Windows_Portable.zip'
$installerRoot = Join-Path $projectDir 'dist\installer'
$stageDir = Join-Path $installerRoot 'stage'
$setupPath = Join-Path $installerRoot 'VNTS2_Windows_Setup.exe'
$sedPath = Join-Path $stageDir 'installer.sed'
$installScriptPath = Join-Path $stageDir 'install.ps1'
$iconSource = Join-Path $projectDir 'assets\app_icon.ico'
$iconDest = Join-Path $stageDir 'app_icon.ico'
$iExpress = Join-Path $env:SystemRoot 'System32\iexpress.exe'

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

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return [System.BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '')
    } finally {
        $stream.Dispose()
        $sha256.Dispose()
    }
}

function Get-LatestPortableZip {
    param([Parameter(Mandatory = $true)][string]$PortableRoot)

    $preferred = Join-Path $PortableRoot 'VNTS2_Windows_Portable.zip'
    if (Test-Path -LiteralPath $preferred) {
        return $preferred
    }

    $latest = Get-ChildItem -LiteralPath $PortableRoot -Filter 'VNTS2_Windows_Portable*.zip' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        throw "Portable zip not found under: $PortableRoot"
    }
    return $latest.FullName
}

Require-Path -Path $portableScript -Label 'Portable export script'
Require-Path -Path $iconSource -Label 'Application icon'
Require-Path -Path $iExpress -Label 'IExpress executable'

& $portableScript
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Portable export failed: $LASTEXITCODE"
}

$portableZipPath = Get-LatestPortableZip -PortableRoot $portableRoot
Require-Path -Path $portableZipPath -Label 'Portable zip'

if (-not (Test-Path -LiteralPath $installerRoot)) {
    New-Item -ItemType Directory -Force -Path $installerRoot | Out-Null
}
Reset-Path -Path $stageDir
if (Test-Path -LiteralPath $setupPath) {
    Remove-Item -LiteralPath $setupPath -Force
}

Copy-Item -LiteralPath $portableZipPath -Destination (Join-Path $stageDir 'VNTS2_Windows_Portable.zip') -Force
Copy-Item -LiteralPath $iconSource -Destination $iconDest -Force

$installScript = @'
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Show-Info {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'VNTS 2.0 Windows 安装程序',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-ErrorDialog {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'VNTS 2.0 Windows 安装程序',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

try {
    $zipPath = Join-Path $PSScriptRoot 'VNTS2_Windows_Portable.zip'
    $iconPath = Join-Path $PSScriptRoot 'app_icon.ico'
    if (-not (Test-Path -LiteralPath $zipPath)) {
        throw "安装载荷不存在：$zipPath"
    }

    $defaultPath = Join-Path $env:LOCALAPPDATA 'Programs\VNTS2 Windows'
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = '请选择 VNTS 2.0 Windows 的安装目录'
    $dialog.SelectedPath = $defaultPath
    $dialog.ShowNewFolderButton = $true
    $result = $dialog.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 1
    }

    $installDir = $dialog.SelectedPath
    if ([string]::IsNullOrWhiteSpace($installDir)) {
        throw '未选择安装目录。'
    }

    if (Test-Path -LiteralPath $installDir) {
        Remove-Item -LiteralPath $installDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force

    $exePath = Join-Path $installDir 'vnts2_windows.exe'
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "安装后的主程序不存在：$exePath"
    }

    $desktopDir = [Environment]::GetFolderPath('Desktop')
    $startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $shortcutName = 'VNTS 2.0 控制台.lnk'
    $desktopShortcut = Join-Path $desktopDir $shortcutName
    $startMenuShortcut = Join-Path $startMenuDir $shortcutName
    $shell = New-Object -ComObject WScript.Shell
    foreach ($shortcutPath in @($desktopShortcut, $startMenuShortcut)) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $installDir
        $shortcut.IconLocation = if (Test-Path -LiteralPath $iconPath) { $iconPath } else { $exePath }
        $shortcut.Save()
    }

    Show-Info "安装完成。程序已安装到：`n$installDir"
    Start-Process -FilePath $exePath -WorkingDirectory $installDir
} catch {
    Show-ErrorDialog $_.Exception.Message
    exit 1
}
'@

Set-Content -LiteralPath $installScriptPath -Value $installScript -Encoding UTF8

$sedContent = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=0
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$setupPath
FriendlyName=VNTS 2.0 Windows Setup
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
PostInstallCmd=<None>
AdminQuietInstCmd=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
UserQuietInstCmd=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$stageDir
[SourceFiles0]
%FILE0%= 
%FILE1%= 
%FILE2%= 
[Strings]
FILE0=VNTS2_Windows_Portable.zip
FILE1=install.ps1
FILE2=app_icon.ico
"@

Set-Content -LiteralPath $sedPath -Value $sedContent -Encoding ASCII

& $iExpress /N $sedPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "IExpress build failed: $LASTEXITCODE"
}

Require-Path -Path $setupPath -Label 'Installer exe'
$setupHash = Get-FileSha256 -Path $setupPath

Write-Host "[OK] Installer exe: $setupPath"
Write-Host "[OK] EXE SHA256: $setupHash"
