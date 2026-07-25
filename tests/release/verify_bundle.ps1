# Verifies a FundLens release bundle (Flutter Release directory with the
# bundled Python engine staged into it) before installer packaging.
#
# Usage: powershell -File tests/release/verify_bundle.ps1 <bundle-dir>
#
# Fails (exit 1) when a required item is missing or a forbidden file is
# present; succeeds silently apart from a PASS line.

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$BundlePath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $BundlePath -PathType Container)) {
  throw "Bundle directory not found: $BundlePath"
}

$required = @(
  'FundLens.exe',
  'fundlens_engine/fundlens_engine.exe',
  'fundlens_engine/models',
  'data/flutter_assets/AssetManifest.bin'
)
foreach ($path in $required) {
  if (-not (Test-Path (Join-Path $BundlePath $path))) {
    throw "Missing bundle item: $path"
  }
}

# No logs, backup files, or OCR test fixture content may ship in a release.
$forbidden = Get-ChildItem $BundlePath -Recurse -File | Where-Object {
  $_.Name -match '\.(log|fundlens-backup)$' -or
    ($_.FullName -replace '/', '\' -match 'tests\\fixtures\\ocr')
}
if ($forbidden) {
  throw "Forbidden release files: $($forbidden.FullName -join ', ')"
}

Write-Host "verify_bundle: PASS ($BundlePath)"
