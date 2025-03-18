# https://github.com/moby/buildkit/blob/248ff7c29ed979ef0c142b8166dd6d192cf0b215/docs/windows.md#cni--networking-setup
$workspaceDir = Resolve-Path "$PSScriptRoot\.."
$networkName = 'nat'
$natInfo = Get-HnsNetwork -ErrorAction Ignore | Where-Object { $_.Name -eq $networkName }
if ($null -eq $natInfo) {
    throw "NAT network not found, check if you enabled containers, Hyper-V features and restarted the machine"
}
$gateway = $natInfo.Subnets[0].GatewayAddress
$subnet = $natInfo.Subnets[0].AddressPrefix

$cniVersion = "1.0.0"
$cniPluginVersion = "0.3.1"
$cniBinDir = "$workspaceDir\buildkit\cni"
$cniConfPath = "$cniBinDir\0-containerd-nat.conf"

if (-Not (Test-Path "$cniConfPath")) {
    Write-Host "📂 'cni' directory not found. Downloading and extracting cni binaries..."

    mkdir $cniBinDir -Force
    curl.exe -LO https://github.com/microsoft/windows-container-networking/releases/download/v$cniPluginVersion/windows-container-networking-cni-amd64-v$cniPluginVersion.zip
    Expand-Archive -Path windows-container-networking-cni-amd64-v$cniPluginVersion.zip -DestinationPath $cniBinDir -Force
} else {
    Write-Host "✅ 'cni' directory already exists. Skipping download."
}

$natConfig = @"
{
    "cniVersion": "$cniVersion",
    "name": "$networkName",
    "type": "nat",
    "master": "Ethernet",
    "ipam": {
        "subnet": "$subnet",
        "routes": [
            {
                "gateway": "$gateway"
            }
        ]
    },
    "capabilities": {
        "portMappings": true,
        "dns": true
    }
}
"@
Set-Content -Path $cniConfPath -Value $natConfig
cat $cniConfPath
