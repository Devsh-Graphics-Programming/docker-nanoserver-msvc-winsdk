$oldLocation = Get-Location
try {
    Set-Location -Path 'C:\'
    $files = Get-ChildItem -Path 'C:\pack' -Filter '*-artifacts.tar.zst'
    if ($files.Count -gt 0) {
        $start = Get-Date
        Write-Host "Unpack started at $start"
        foreach ($z in $files) {
            $zst = $z.FullName
            $tar = [IO.Path]::ChangeExtension($zst, '.tar')
            if (-not (Test-Path $tar)) {
                & zstd -d -T0 $zst -o $tar
            }
            tar -xf $tar
            Remove-Item $tar, $zst -ErrorAction SilentlyContinue
        }
        dir
        $end = Get-Date
        Write-Host "Unpack finished at $end"
        $duration = $end - $start
        Write-Host "Total duration: $($duration.ToString())"

        git config --global --add safe.directory '*'
        Write-Host "All directories marked safe for Git."
    }
    else {
        Write-Host "No artifacts to unpack."
    }
}
finally {
    Set-Location -Path $oldLocation
}