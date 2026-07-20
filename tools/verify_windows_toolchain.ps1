$ErrorActionPreference = 'Stop'

# Verify git is on PATH.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'Missing required command: git'
}

# Use the locally installed Flutter SDK. If this path is not on PATH, the
# PowerShell command resolution can find the extensionless shell wrapper first
# and mis-run it, so we invoke the .bat entry directly.
$flutter = 'D:\flutter\bin\flutter.bat'
$dart = 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe'

if (-not (Test-Path $flutter)) {
  throw "Flutter not found at $flutter"
}
if (-not (Test-Path $dart)) {
  throw "Dart not found at $dart"
}

# Locate vswhere (installed with Visual Studio).
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$vswhereCmd = Get-Command vswhere -ErrorAction SilentlyContinue
if ($vswhereCmd) {
  $vswhere = $vswhereCmd.Source
}
if (-not (Test-Path $vswhere)) {
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

function Find-Tool {
  param([string]$Path, [string]$Filter)
  return Get-ChildItem -Path $Path -Filter $Filter -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}

$cl = Find-Tool -Path (Join-Path $vsPath 'VC\Tools\MSVC') -Filter 'cl.exe'
if (-not $cl) {
  throw 'Windows build tool cl.exe not found in Visual Studio installation.'
}

$cmake = Find-Tool -Path (Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake') -Filter 'cmake.exe'
if (-not $cmake) {
  throw 'Windows build tool cmake.exe not found in Visual Studio installation.'
}

$ninja = Find-Tool -Path (Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake') -Filter 'ninja.exe'
if (-not $ninja) {
  throw 'Windows build tool ninja.exe not found in Visual Studio installation.'
}

& $flutter config --enable-windows-desktop
$devices = & $flutter devices
if (-not ($devices -match 'Windows')) {
  throw 'Flutter Windows desktop device is unavailable.'
}
& $flutter doctor -v
