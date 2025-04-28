$oldLocation = Get-Location
try {
    Set-Location -Path 'C:\'

    if (Test-Path -Path 'artifacts.tar.zst') {
        if (-not (Test-Path -Path 'artifacts.tar')) {
            & zstd -d -T0 artifacts.tar.zst -o artifacts.tar
        }
        tar -xf artifacts.tar
    }

    Remove-Item -Path 'artifacts.tar' -ErrorAction SilentlyContinue
    Remove-Item -Path 'artifacts.tar.zst' -ErrorAction SilentlyContinue
    dir
}
finally {
    Set-Location -Path $oldLocation
}