# Builds every package archive this repository publishes.
#
# The archive for a package is produced from its sources under `packages/<Name>/`, so what the index
# names and what a reader can review are the same thing. Run this after changing a package, then commit
# the updated `.tar.gz` and the change to `registry.nyx-registry` together.
#
# Usage:
#   powershell -File tools/build_archives.ps1
#
# The shape matters: `tar -czf <name>-<version>.tar.gz -C packages <name>` puts everything under one
# top-level directory named after the package, which is what the resolver recognises as the package
# root. A flat archive is also accepted, but the single-rooted form is what a reader of the index
# expects.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repositoryRoot
$packages = Join-Path $repositoryRoot 'packages'

foreach ($packageDirectory in Get-ChildItem -Path $packages -Directory | Sort-Object Name) {
    $name = $packageDirectory.Name
    $manifestPath = Join-Path $packageDirectory.FullName 'nyx.package'
    if (-not (Test-Path $manifestPath)) {
        Write-Host "  SKIP $name (no nyx.package)"
        continue
    }
    $version = ((Get-Content $manifestPath |
        Where-Object { $_ -match '^\s*version\s+(\S+)' } |
        Select-Object -First 1) -replace '^\s*version\s+', '').Trim()
    if (-not $version) {
        Write-Host "  SKIP $name (no version in its manifest)"
        continue
    }

    $archive = Join-Path $packages "$name-$version.tar.gz"
    if (Test-Path $archive) { Remove-Item $archive -Force }
    tar -czf $archive -C $packages $name
    if ($LASTEXITCODE -ne 0) { Write-Host "  FAIL $name"; exit 1 }

    # The digest goes in the index line's neighbourhood rather than in it, so a reader can verify a
    # download without the index having to carry a second kind of value.
    $digest = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
    Set-Content -Path "$archive.sha256" -Value "$digest  $name-$version.tar.gz" -Encoding ascii

    Write-Host ("  {0,-24} {1}" -f "$name $version", "$digest")
}

Write-Host ''
Write-Host 'archives:'
Get-ChildItem $packages -File -Filter '*.tar.gz' | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-36} {1,8} KB" -f $_.Name, [math]::Round($_.Length / 1024, 1))
}
