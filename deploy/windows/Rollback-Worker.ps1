$ErrorActionPreference = "Stop"
$Root = "C:\app-stack\worker"
$Current = Join-Path $Root "current"
$Previous = Join-Path $Root "previous"

if (-not (Test-Path -LiteralPath $Previous)) {
    Write-Warning "No previous worker release exists; leaving current unchanged."
    exit 0
}

$CurrentTarget = (Get-Item -LiteralPath $Current).Target
$PreviousTarget = (Get-Item -LiteralPath $Previous).Target
Remove-Item -LiteralPath $Current -Force
Remove-Item -LiteralPath $Previous -Force
New-Item -ItemType Junction -Path $Current -Target $PreviousTarget | Out-Null
New-Item -ItemType Junction -Path $Previous -Target $CurrentTarget | Out-Null
Restart-Service -Name "AppWorker"

for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:9090/health" -TimeoutSec 5 | Out-Null
        Write-Host "worker rollback is healthy"
        exit 0
    } catch {
        Start-Sleep -Seconds 5
    }
}

throw "worker rollback failed its health check"
