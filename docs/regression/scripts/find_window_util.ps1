# Shared window-lookup helper for the regression scripts.
#
# FindWindow returns 0 in this environment (sandboxed shell), so windows are
# located by EnumWindows + GetWindowThreadProcessId + GetWindowText instead.
# Dot-source this file, then call FindWindowByTitle("fundlens_windows", $pid).

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RegWinUtil {
  public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")]
  public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

function FindWindowByTitle([string]$title, [int]$processId = 0) {
  # Return the LARGEST window matching the title: Flutter can own several
  # windows with the same title (e.g. a tiny tooltip window), and the first
  # one in Z-order is not necessarily the main window.
  $script:best = [IntPtr]::Zero
  $script:bestArea = -1
  $cb = {
    param($h, $l)
    $sb = New-Object System.Text.StringBuilder 256
    [void][RegWinUtil]::GetWindowText($h, $sb, 256)
    if ($sb.ToString() -eq $title) {
      if ($processId -gt 0) {
        $wp = 0
        [void][RegWinUtil]::GetWindowThreadProcessId($h, [ref]$wp)
        if ($wp -ne $processId) { return $true }
      }
      $r = New-Object RegWinUtil+RECT
      [void][RegWinUtil]::GetWindowRect($h, [ref]$r)
      $area = ($r.Right - $r.Left) * ($r.Bottom - $r.Top)
      if ($area -gt $script:bestArea) {
        $script:best = $h
        $script:bestArea = $area
      }
    }
    return $true
  }
  [RegWinUtil]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  return $script:best
}

function GetWindowRectByHandle([IntPtr]$hWnd) {
  $r = New-Object RegWinUtil+RECT
  [RegWinUtil]::GetWindowRect($hWnd, [ref]$r) | Out-Null
  return $r
}
