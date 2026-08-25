# Generates the FundLens update manifest (version.json) consumed by the
# in-app update check (lib/updates/update_checker.dart).
#
# Usage:
#   powershell -File tools/generate_update_manifest.ps1 `
#     -InstallerPath dist/installer/FundLens-Setup.exe `
#     -DownloadUrl https://github.com/GabageCollection/FundLens/releases/latest/download/FundLens-Setup.exe `
#     -NotesFile dist/release-notes-v1.1.0.md
#
# -Version defaults to the #define AppVersion in installer/FundLens.iss.
# Output is compact UTF-8 JSON without BOM:
#   {"version":"1.1.0","url":"https://...","sha256":"<hex>","notes":"..."}
# The DownloadUrl must be HTTPS; the sha256 is computed from the installer
# bytes so a tampered download always fails the in-app integrity check.

param(
  [Parameter(Mandatory = $true)][string]$InstallerPath,
  [string]$Version = '',
  [Parameter(Mandatory = $true)][string]$DownloadUrl,
  [string]$Notes = '',
  [string]$NotesFile = '',
  [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not $Version) {
  $iss = Get-Content (Join-Path $repoRoot 'installer\FundLens.iss') -Raw
  if ($iss -notmatch '(?m)^#define AppVersion "([^"]+)"') {
    throw 'AppVersion not found in installer/FundLens.iss; pass -Version explicitly.'
  }
  $Version = $Matches[1]
}

if ($DownloadUrl -notmatch '^https://') {
  throw "DownloadUrl must be HTTPS: $DownloadUrl"
}
if (-not (Test-Path $InstallerPath -PathType Leaf)) {
  throw "Installer not found: $InstallerPath"
}
if ($Notes -and $NotesFile) {
  throw 'Pass either -Notes or -NotesFile, not both.'
}
if ($NotesFile) {
  if (-not (Test-Path $NotesFile -PathType Leaf)) {
    throw "NotesFile not found: $NotesFile"
  }
  $Notes = (Get-Content $NotesFile -Raw -Encoding UTF8).Trim()
}
if (-not $OutPath) {
  $OutPath = Join-Path $repoRoot 'dist\installer\version.json'
}

# Compute SHA-256 via .NET instead of Get-FileHash: the cmdlet lives in
# Microsoft.PowerShell.Utility and can be unavailable when this script runs
# inside a build pipeline with a modified PSModulePath.
$sha256 = [System.BitConverter]::ToString(
  [System.Security.Cryptography.SHA256]::Create().ComputeHash(
    [System.IO.File]::ReadAllBytes($InstallerPath)
  )
).Replace('-', '').ToLower()

$manifest = [ordered]@{
  version = $Version
  url     = $DownloadUrl
  sha256  = $sha256
  notes   = $Notes
}

# Compact JSON, UTF-8 without BOM (the app decodes with utf8.decoder).
$json = $manifest | ConvertTo-Json -Compress
$outDir = Split-Path $OutPath -Parent
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText($OutPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "==> Update manifest written: $OutPath"
Write-Host "    version=$Version sha256=$($sha256.Substring(0, 16))... url=$DownloadUrl"
