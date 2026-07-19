$ErrorActionPreference = 'Stop'
$commands = @('git', 'flutter', 'dart')
foreach ($command in $commands) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $command"
  }
}

# Locate vswhere (installed with Visual Studio).
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
  $vswhereCmd = Get-Command vswhere -ErrorAction SilentlyContinue
  if ($vswhereCmd) {
    $vswhere = $vswhereCmd.Source
  }
}
if (-not $vswhere) {
  throw 'vswhere not found. Install Visual Studio 2022 with the C++ Desktop workload.'
}

$vsPath = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
if (-not $vsPath) {
  throw 'Visual Studio 2022 C++ Desktop workload is not installed.'
}

$hasAtl = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.ATL `
  -property installationPath
if (-not $hasAtl) {
  throw 'Visual Studio C++ ATL is not installed.'
}

foreach ($tool in @('cmake', 'ninja', 'cl')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Missing Windows build tool: $tool"
  }
}

flutter config --enable-windows-desktop
$devices = flutter devices
if ($devices -notmatch 'Windows') {
  throw 'Flutter Windows desktop device is unavailable.'
}
flutter doctor -v
