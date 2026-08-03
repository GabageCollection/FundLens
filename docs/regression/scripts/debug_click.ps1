# Map click Y in the sidebar to the nav item actually selected. The editor is
# minimized first (clicks otherwise land on it), the app window is restored,
# moved to (0,0) and made topmost. After each click the highlight is detected
# and printed as "y -> highlight".
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File debug_click.ps1

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "find_window_util.ps1")
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$py = Join-Path $root "engine/.venv/Scripts/python.exe"
$detectPy = Join-Path $PSScriptRoot "detect_highlight.py"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Db2Native {
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
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint uf);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")]
  public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
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

$cover = [Db2Native]::FindByTitle("Visual Studio Code")
if ($cover -ne [IntPtr]::Zero) { [Db2Native]::ShowWindow($cover, 6) | Out-Null }
$hwnd = FindWindowByTitle "fundlens_windows"
[Db2Native]::ShowWindow($hwnd, 9) | Out-Null
Start-Sleep -Milliseconds 500
[Db2Native]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x0004 -bor 0x0001) | Out-Null
Start-Sleep -Milliseconds 400
[Db2Native]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 0x0002 -bor 0x0001) | Out-Null
Start-Sleep -Milliseconds 300

$rect = GetWindowRectByHandle $hwnd
Write-Output ("WINDOW=" + $rect.Left + "," + $rect.Top)

$probe = Join-Path $env:TEMP "dbg2-probe.png"
$candidates = @(210, 230, 250, 270, 290, 310, 330, 350, 370, 400, 420, 450, 470, 510, 550, 590)
foreach ($y in $candidates) {
  [Db2Native]::SetCursorPos($rect.Left + 110, $rect.Top + $y) | Out-Null
  Start-Sleep -Milliseconds 200
  [Db2Native]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
  Start-Sleep -Milliseconds 100
  [Db2Native]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
  Start-Sleep -Milliseconds 1800
  & (Join-Path $PSScriptRoot "screenshot_window.ps1") -Title "fundlens_windows" -OutPath $probe | Out-Null
  $line = & $py $detectPy $probe 2>$null | Select-Object -Last 1
  Write-Output ("click y=" + $y + " -> " + $line)
}
Write-Output "DONE"
