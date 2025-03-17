param (
    [string]$WorkspaceDir,
    [string]$WslMsiUrl = "https://github.com/microsoft/WSL/releases/download/2.4.12/wsl.2.4.12.0.x64.msi",
    [string]$AlpineZipUrl = "https://github.com/yuk7/AlpineWSL/releases/download/3.21.3-0/Alpine.zip",
    [string]$LinuxKernelbzImageUrl = "https://github.com/Devsh-Graphics-Programming/WSL2-Linux-Kernel/releases/download/wsl2-kernel-13885376672/bzImage",
    [string]$RegistryTag = "2.8.3"
)

$LinuxDir = "$WorkspaceDir\linux"
if (!(Test-Path $LinuxDir)) { New-Item -ItemType Directory -Path $LinuxDir | Out-Null }

$bzImagePath = "$LinuxDir\bzImage"
$ext4Path = "$LinuxDir\ext4.vhdx"
$wslInstaller = "$LinuxDir\wsl.msi"

$bzImageCached = Test-Path $bzImagePath
$ext4Cached = Test-Path $ext4Path
$wslCached = Test-Path $wslInstaller

if (-not $wslCached) {
    Write-Host "$wslInstaller not found in cache, downloading..."
    Invoke-WebRequest -Uri $WslMsiUrl -OutFile $wslInstaller
} else {
    Write-Host "$wslInstaller found in cache, skipping download."
}

Write-Host "Updating WSL..."
Start-Process -Wait "msiexec.exe" -ArgumentList "/i `"$wslInstaller`" /qn /norestart" -NoNewWindow -PassThru

wsl --set-default-version 2

Write-Host "Updating .wslconfig..."
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$kernelPath = $bzImagePath.Replace("\", "\\")
$wslConfigContent = @"
[wsl2]
kernel=$kernelPath
"@
$wslConfigContent | Set-Content -Path $wslConfigPath -Encoding UTF8 -Force

Write-Host "==== .wslconfig CONTENT ====" -ForegroundColor Green
Write-Host $wslConfigContent -ForegroundColor Green

if (-not $bzImageCached) {
    Write-Host "$bzImagePath not found in cache, downloading..."
    Invoke-WebRequest -Uri $LinuxKernelbzImageUrl -OutFile $bzImagePath
} else {
    Write-Host "$bzImagePath found in cache, skipping download."
}

if (-not $ext4Cached) {
    Write-Host "$ext4Path not found in cache, creating Alpine instance with Docker registry..."
    Invoke-WebRequest -Uri $AlpineZipUrl -OutFile "$WorkspaceDir\Alpine.zip"
    Expand-Archive -Path "$WorkspaceDir\Alpine.zip" -DestinationPath $LinuxDir -Force
    Write-Output "`n" | & "$LinuxDir\Alpine.exe"
    wsl -s Alpine
    wsl apk add docker
    wsl nohup dockerd > /dockerd-log 2>&1 &
    & "$WorkspaceDir\wsl\wait-for-daemon.ps1"
    wsl docker pull registry:$RegistryTag
} else {
    Write-Host "$ext4Path found in cache, skipping download & importing!"
    wsl --import-in-place Alpine "$ext4Path"
    wsl -s Alpine
}

Write-Host "==== LINUX WSL DIRECTORY STRUCTURE ====" -ForegroundColor Cyan
Get-ChildItem -Path $LinuxDir -Recurse | ForEach-Object { $_.FullName.Replace($PWD.Path, "").Replace("\", "/") }
