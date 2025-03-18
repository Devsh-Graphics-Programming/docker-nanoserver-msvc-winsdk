param (
    [int]$maxRetries = 15,
    [int]$delaySeconds = 1
)

$linuxDockerReady = $false
$i = 0

while ($i -lt $maxRetries) {
    Write-Host "[$i/$maxRetries]: Waiting for Linux Docker daemon..."
    Start-Sleep -Seconds $delaySeconds
    wsl docker info > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Linux Docker daemon running!" -ForegroundColor Green
        $linuxDockerReady = $true
        break
    }
    $i++
}

if (-not $linuxDockerReady) {
    Write-Host "Failed to connect to Linux Docker daemon!" -ForegroundColor Red
    exit 1
}
