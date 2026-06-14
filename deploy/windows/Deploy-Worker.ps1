param(
    [Parameter(Mandatory = $true)][string]$ReleaseId,
    [Parameter(Mandatory = $true)][string]$ArtifactPath
)

$ErrorActionPreference = "Stop"
$Root = "C:\app-stack\worker"
$ReleaseDir = Join-Path $Root "releases\$ReleaseId"
$Current = Join-Path $Root "current"
$Previous = Join-Path $Root "previous"

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
Expand-Archive -LiteralPath $ArtifactPath -DestinationPath $ReleaseDir -Force
Remove-Item -LiteralPath $ArtifactPath -Force

if (Test-Path -LiteralPath $Current) {
    $CurrentTarget = (Get-Item -LiteralPath $Current).Target
    if (Test-Path -LiteralPath $Previous) {
        Remove-Item -LiteralPath $Previous -Force
    }
    New-Item -ItemType Junction -Path $Previous -Target $CurrentTarget | Out-Null
    Remove-Item -LiteralPath $Current -Force
}
New-Item -ItemType Junction -Path $Current -Target $ReleaseDir | Out-Null

Restart-Service -Name "AppWorker"

for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:9090/health" -TimeoutSec 5 | Out-Null
        Write-Host "worker release $ReleaseId is healthy"
        exit 0
    } catch {
        Start-Sleep -Seconds 5
    }
}

throw "worker failed its health check"
