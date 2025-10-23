Param(
    [string]$FlutterExecutable = "flutter",
    [string]$BuildMode = "release",
    [string]$OutputDirectory = "build/windows_release"
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectRoot {
    param([string]$ScriptPath)
    return (Resolve-Path (Join-Path $ScriptPath ".."))
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Resolve-ProjectRoot -ScriptPath $scriptDirectory
Push-Location $projectRoot

try {
    Write-Host "Running Flutter pub get" -ForegroundColor Cyan
    & $FlutterExecutable pub get

    Write-Host "Building Windows $BuildMode binary" -ForegroundColor Cyan
    & $FlutterExecutable build windows --$BuildMode --no-pub

    $runnerOutput = Join-Path $projectRoot "build/windows/x64/runner/$($BuildMode.Substring(0,1).ToUpper() + $BuildMode.Substring(1).ToLower())"
    if (-not (Test-Path $runnerOutput)) {
        throw "Runner output directory '$runnerOutput' was not generated."
    }

    $destination = Join-Path $projectRoot $OutputDirectory
    if (Test-Path $destination) {
        Remove-Item $destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $destination | Out-Null

    Write-Host "Copying build output to $destination" -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $runnerOutput '*') -Destination $destination -Recurse -Force

    $archivePath = "$destination.zip"
    if (Test-Path $archivePath) {
        Remove-Item $archivePath -Force
    }
    Write-Host "Creating portable zip archive" -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $destination '*') -DestinationPath $archivePath

    Write-Host "Windows release artifacts are available at $destination and $archivePath" -ForegroundColor Green
}
finally {
    Pop-Location
}
