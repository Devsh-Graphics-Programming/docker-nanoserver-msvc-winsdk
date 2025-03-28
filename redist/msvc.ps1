param(
    [Parameter(Mandatory=$true)]
    [string]$RedistPath,

    [Parameter(Mandatory=$true)]
    [string]$Arch
)

function Find-DllDirs {
    param([string]$BaseDir)
    $dllDirs = @()
    if (-Not (Test-Path $BaseDir)) {
        Write-Warning "Directory does not exist: $BaseDir"
        return $dllDirs
    }
    Get-ChildItem -Path $BaseDir -Recurse -Directory | ForEach-Object {
        if (Get-ChildItem -Path $_.FullName -Filter *.dll -File -ErrorAction SilentlyContinue) {
            $dllDirs += $_.FullName
        }
    }
    return $dllDirs
}

$RedistPath = Resolve-Path -Path $RedistPath | Select-Object -ExpandProperty Path

$ReleaseBase = Join-Path $RedistPath $Arch
$DebugBase   = Join-Path $RedistPath "debug_nonredist\$Arch"

Write-Host "`n[*] Scanning release DLLs in: $ReleaseBase"
$ReleaseDirs = Find-DllDirs -BaseDir $ReleaseBase

Write-Host "`n[*] Scanning debug DLLs in: $DebugBase"
$DebugDirs = Find-DllDirs -BaseDir $DebugBase

if (-Not $ReleaseDirs.Count) {
    Write-Error "No release DLL directories found."
    exit 2
}
if (-Not $DebugDirs.Count) {
    Write-Error "No debug DLL directories found."
    exit 3
}

$AllDirs = $ReleaseDirs + $DebugDirs
$EnvVarName = "MSVC_$($Arch.ToUpper())_REDIST_DIRS"
$EnvVarValue = ($AllDirs -join ";")

Write-Host "`n[+] Setting system environment variable $EnvVarName ..."

try {
    $regResult = & reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v $EnvVarName /t REG_EXPAND_SZ /d "$EnvVarValue" /f 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "reg add failure:`n$regResult"
    }

    Write-Host "    Done."
    Write-Host "    Value:"
    $AllDirs | ForEach-Object { Write-Host "      $_" }
} catch {
    Write-Error "Failed due to:`n $_"
    exit 4
}