Param(
    [string]$FlutterExe = "flutter",
    [ValidateSet('debug','profile','release')]
    [string]$BuildMode = 'release',
    [string]$InstallerScript = "windows_installer/windows_installer_script.iss"
)

$ErrorActionPreference = 'Stop'

Write-Host "📦 Building Windows runner in $BuildMode mode" -ForegroundColor Cyan
& $FlutterExe build windows --$BuildMode

$buildPath = Join-Path -Path (Get-Location) -ChildPath "build\\windows\\runner\\${BuildMode.ToUpper()}"
if (!(Test-Path $buildPath)) {
    Write-Warning "Windows runner output not found at $buildPath"
}

if (Test-Path $InstallerScript) {
    $isccPath = $env:ISCC_PATH
    if (-not $isccPath) {
        $defaultIscc = "C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe"
        if (Test-Path $defaultIscc) {
            $isccPath = $defaultIscc
        }
    }

    if ($isccPath -and (Test-Path $isccPath)) {
        Write-Host "🛠  Packaging installer via Inno Setup" -ForegroundColor Cyan
        & $isccPath $InstallerScript
    } else {
        Write-Warning "Inno Setup not found. Skipping installer packaging."
    }
} else {
    Write-Warning "Installer script not found at $InstallerScript."
}
