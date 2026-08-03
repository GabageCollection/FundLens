# Capture the six app pages by clicking the sidebar navigation items, then
# screenshot the window externally. Self-calibrating: after each click the
# selected-item highlight position is detected (detect_highlight.py) and the
# click Y is corrected until the intended nav item is selected.
#
# The app must already be running with data imported. The window is restored
# (SW_RESTORE), moved to (0,0) and made topmost for the duration of the run.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File capture_pages.ps1 `
#     -Prefix before -OutDir docs/regression/screenshots

param(
  [Parameter(Mandatory = $true)][string]$Prefix,
  [string]$OutDir = "docs/regression/screenshots",
  [string]$Title = "fundlens_windows"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "find_window_util.ps1")
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$outAbs = Join-Path $root $OutDir
New-Item -ItemType Directory -Force -Path $outAbs | Out-Null
$py = Join-Path $root "engine/.venv/Scripts/python.exe"
$detectPy = Join-Path $PSScriptRoot "detect_highlight.py"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class CapNative {
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")]
  public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
    int X, int Y, int cx, int cy, uint uFlags);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$hwnd = FindWindowByTitle $Title
if ($hwnd -eq [IntPtr]::Zero) {
  Write-Error "Window not found: $Title"
  exit 1
}

# The editor usually covers the whole screen and steals the foreground, so
# real mouse clicks never reach the app. Minimize covering windows, then
# restore them at the end.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class CapCover {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")]
  public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool ShowWindow(IntPtr h, int n);
  public static IntPtr FindByTitle(string t) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      StringBuilder sb = new StringBuilder(256);
      GetWindowText(h, sb, 256);
      if (sb.ToString().Contains(t) && IsWindowVisible(h)) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
"@
$cover = [CapCover]::FindByTitle("Visual Studio Code")
if ($cover -ne [IntPtr]::Zero) {
  [CapCover]::ShowWindow($cover, 6) | Out-Null   # SW_MINIMIZE
  Start-Sleep -Milliseconds 500
}

# Restore (the app is often left minimized), move to primary-screen origin,
# and make topmost so real clicks land on the app instead of whatever window
# is covering it.
[CapNative]::ShowWindow($hwnd, 9) | Out-Null
Start-Sleep -Milliseconds 500
[CapNative]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x0004 -bor 0x0001) | Out-Null
Start-Sleep -Milliseconds 400
[CapNative]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 0x0002 -bor 0x0001) | Out-Null  # HWND_TOPMOST
Start-Sleep -Milliseconds 400

$rect = GetWindowRectByHandle $hwnd
if (($rect.Right - $rect.Left) -le 0) {
  Write-Error "Invalid window rectangle"
  exit 1
}

# Sidebar nav item centers (window pixels, from OCR of a 1280x720 window).
$pages = @(
  @{ name = "overview";  y = 222 },
  @{ name = "analysis";  y = 306 },
  @{ name = "holdings";  y = 390 },
  @{ name = "snapshots"; y = 474 },
  @{ name = "import";    y = 558 },
  @{ name = "settings";  y = 642 }
)
$navX = 110
$tolerance = 14
$probe = Join-Path $env:TEMP "cap-probe.png"

function Click-Nav([int]$y) {
  [CapNative]::SetCursorPos($rect.Left + $navX, $rect.Top + $y) | Out-Null
  Start-Sleep -Milliseconds 200
  [CapNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
  Start-Sleep -Milliseconds 100
  [CapNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
  Start-Sleep -Milliseconds 1600
}

function Get-HighlightY {
  & (Join-Path $PSScriptRoot "screenshot_window.ps1") -Title $Title -OutPath $probe | Out-Null
  $line = & $py $detectPy $probe 2>$null | Select-Object -Last 1
  if ($line -match "HIGHLIGHT_Y=(\d+)") { return [int]$Matches[1] }
  return -1
}

foreach ($page in $pages) {
  $target = $page.y
  $clickY = $target
  $ok = $false
  for ($attempt = 1; $attempt -le 6; $attempt++) {
    Click-Nav $clickY
    $highlight = Get-HighlightY
    if ($highlight -lt 0) {
      Write-Warning "($($page.name)) highlight not detected, retry $attempt"
      Start-Sleep -Seconds 1
      continue
    }
    $err = [Math]::Abs($highlight - $target)
    if ($err -le $tolerance) {
      Write-Output "($($page.name)) selected at highlight=$highlight (target $target, attempt $attempt)"
      $ok = $true
      break
    }
    $clickY = $clickY + ($target - $highlight)
    if ($clickY -lt 40) { $clickY = 40 }
    if ($clickY -gt 700) { $clickY = 700 }
    Write-Warning "($($page.name)) highlight=$highlight vs target=$target; next clickY=$clickY"
  }
  if (-not $ok) {
    Write-Error "Could not select page $($page.name)"
    exit 1
  }

  $outPath = Join-Path $outAbs "$Prefix-$($page.name).png"
  & (Join-Path $PSScriptRoot "screenshot_window.ps1") -Title $Title -OutPath $outPath
  if (-not $? -or -not (Test-Path $outPath)) {
    Write-Error "Screenshot failed for page $($page.name)"
    exit 1
  }
}

# Restore normal Z-order.
[CapNative]::SetWindowPos($hwnd, [IntPtr](-2), 0, 0, 0, 0, 0x0002 -bor 0x0001) | Out-Null  # HWND_NOTOPMOST
if ($cover -ne [IntPtr]::Zero) {
  [CapCover]::ShowWindow($cover, 9) | Out-Null   # SW_RESTORE
}
Write-Output "== Captured $($pages.Count) pages with prefix '$Prefix' into $outAbs =="
