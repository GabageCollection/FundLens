# List every window whose title contains 'fundlens', with size and visibility.
# Diagnostic for the window-finder used by the screenshot flow.
#
# NOTE: PowerShell output from inside a .NET delegate (EnumWindows callback)
# is swallowed, so results are collected into $script: and printed afterwards.

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class LwNative {
  public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")]
  public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool IsIconic(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$script:rows = @()
$cb = {
  param($h, $l)
  $sb = New-Object System.Text.StringBuilder 256
  [void][LwNative]::GetWindowText($h, $sb, 256)
  if ($sb.ToString().ToLower().Contains("fundlens")) {
    $wp = 0
    [void][LwNative]::GetWindowThreadProcessId($h, [ref]$wp)
    $r = New-Object LwNative+RECT
    [void][LwNative]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left
    $hgt = $r.Bottom - $r.Top
    $script:rows += ("HWND=" + $h + " PID=" + $wp + " VIS=" + [LwNative]::IsWindowVisible($h) +
      " ICONIC=" + [LwNative]::IsIconic($h) +
      " SIZE=" + $w + "x" + $hgt + " RECT=" + $r.Left + "," + $r.Top + "," + $r.Right + "," + $r.Bottom +
      " TITLE=" + $sb.ToString())
  }
  return $true
}
[LwNative]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
$script:rows | ForEach-Object { Write-Output $_ }
Write-Output ("TOTAL=" + $script:rows.Count)
