$workspaceDir = Resolve-Path "$PSScriptRoot\.."
$networkName = 'nat'
# Get-HnsNetwork is available once you have enabled the 'Hyper-V Host Compute Service' feature
# which must have been done at the Quick setup above
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V, Containers -All
# the default one named `nat` should be available, except for WS2019, see notes below.
$natInfo = Get-HnsNetwork -ErrorAction Ignore | Where-Object { $_.Name -eq $networkName }
if ($null -eq $natInfo) {
    throw "NAT network not found, check if you enabled containers, Hyper-V features and restarted the machine"
}
$gateway = $natInfo.Subnets[0].GatewayAddress
$subnet = $natInfo.Subnets[0].AddressPrefix

$cniConfPath = "$workspaceDir\buildkit\containerd\cni\conf\0-containerd-nat.conf"
$cniBinDir = "$workspaceDir\buildkit\cni\bin"
$cniVersion = "1.0.0"
$cniPluginVersion = "0.3.1"

# get the CNI plugins (binaries)
mkdir $cniBinDir -Force
curl.exe -LO https://github.com/microsoft/windows-container-networking/releases/download/v$cniPluginVersion/windows-container-networking-cni-amd64-v$cniPluginVersion.zip
tar xvf windows-container-networking-cni-amd64-v$cniPluginVersion.zip -C $cniBinDir

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
# take a look
cat $cniConfPath
