# Capture pages while a HUMAN clicks the sidebar navigation items: snapshot
# the window every ~2s, detect the selected-nav highlight, and save one
# screenshot per distinct nav item (highlight Y clustered). The human drives
# the clicks (synthetic clicks cannot reach the app reliably on this box);
# this script just watches and saves one image per visited page.
#
# Usage (run in background, then ask the user to click each page):
#   powershell -ExecutionPolicy Bypass -File monitor_pages.ps1 `
#     -Prefix before -OutDir docs/regression/screenshots -Duration 120

param(
  [Parameter(Mandatory = $true)][string]$Prefix,
  [string]$OutDir = "docs/regression/screenshots",
  [string]$Title = "fundlens_windows",
  [int]$Duration = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "find_window_util.ps1")
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$outAbs = Join-Path $root $OutDir
New-Item -ItemType Directory -Force -Path $outAbs | Out-Null
$py = Join-Path $root "engine/.venv/Scripts/python.exe"
$detectPy = Join-Path $PSScriptRoot "detect_highlight.py"

$hwnd = FindWindowByTitle $Title
if ($hwnd -eq [IntPtr]::Zero) {
  Write-Error "Window not found: $Title"
  exit 1
}

# Cluster a raw highlight y: two observations closer than 12px are the same
# nav item; the saved filename carries the cluster y.
function Get-ClusterKey([int]$y) {
  return [int]([Math]::Round($y / 12.0) * 12)
}

$probe = Join-Path $env:TEMP "mon-probe.png"
$seen = @{}
$deadline = (Get-Date).AddSeconds($Duration)
while ((Get-Date) -lt $deadline) {
  & (Join-Path $PSScriptRoot "screenshot_window.ps1") -Title $Title -OutPath $probe | Out-Null
  if ($?) {
    $line = & $py $detectPy $probe 2>$null | Select-Object -Last 1
    if ($line -match "HIGHLIGHT_Y=(\d+)") {
      $key = Get-ClusterKey ([int]$Matches[1])
      if (-not $seen.ContainsKey($key)) {
        $dst = Join-Path $outAbs "$Prefix-nav-$key.png"
        Copy-Item $probe $dst -Force
        $seen[$key] = $dst
        Write-Output ("CAPTURED nav=$key -> $dst")
      }
    }
  }
  Start-Sleep -Seconds 2
}
Write-Output ("== captured $($seen.Count) distinct nav items with prefix '$Prefix' ==")
