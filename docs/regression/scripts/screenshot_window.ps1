# Regression screenshot tool: capture the app window by title
# (PrintWindow + black-pixel check, fallback to foreground + CopyFromScreen).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File screenshot_window.ps1 `
#     -Title fundlens_windows -OutPath docs/regression/screenshots/after/overview.png
#
# Notes:
#   - Window lookup goes through find_window_util.ps1 (EnumWindows), because
#     FindWindow returns 0 in this shell environment.
#   - PrintWindow(PW_RENDERFULLCONTENT) first; if it fails or the content is
#     all black (hardware rendering), bring the window forward and use
#     CopyFromScreen on the window rectangle.
#   - No third-party dependencies (System.Drawing + user32).

param(
  [Parameter(Mandatory = $true)][string]$Title,
  [Parameter(Mandatory = $true)][string]$OutPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "find_window_util.ps1")
Add-Type -AssemblyName System.Drawing

$hwnd = FindWindowByTitle $Title
if ($hwnd -eq [IntPtr]::Zero) {
  Write-Error "Window not found: $Title"
  exit 1
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ShotWinNative {
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
# A minimized window reports a taskbar-icon rect and PrintWindow renders a
# stale surface; restore before measuring/screenshotting.
[ShotWinNative]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
Start-Sleep -Milliseconds 500

$rect = GetWindowRectByHandle $hwnd
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
  Write-Error "Invalid window rectangle: ${width}x${height}"
  exit 1
}

$outDir = Split-Path -Parent $OutPath
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ShotNative {
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
    int X, int Y, int cx, int cy, uint uFlags);
}
"@

$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()
$printed = [ShotNative]::PrintWindow($hwnd, $hdc, 2)  # PW_RENDERFULLCONTENT
$graphics.ReleaseHdc($hdc)
$graphics.Dispose()

# Black-pixel check: PrintWindow often reports success but black content for
# hardware-accelerated windows.
$black = $true
$step = [Math]::Max(1, [int]($width / 16))
for ($x = 0; $x -lt $width -and $black; $x += $step) {
  for ($y = 0; $y -lt $height -and $black; $y += $step) {
    $pixel = $bitmap.GetPixel($x, $y)
    if ($pixel.R -gt 24 -or $pixel.G -gt 24 -or $pixel.B -gt 24) { $black = $false }
  }
}

if (-not $printed -or $black) {
  Write-Warning "PrintWindow content invalid; using foreground + CopyFromScreen"
  [ShotNative]::SetForegroundWindow($hwnd) | Out-Null
  Start-Sleep -Milliseconds 400
  # Move the window to the primary screen top-left to avoid cross-screen scaling.
  [ShotNative]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x0002 -bor 0x0001) | Out-Null
  Start-Sleep -Milliseconds 400
  $rect = GetWindowRectByHandle $hwnd
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  $bitmap.Dispose()
  $bitmap = New-Object System.Drawing.Bitmap($width, $height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($width, $height)))
  $graphics.Dispose()
}

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
Write-Output "Saved $OutPath (${width}x${height})"
