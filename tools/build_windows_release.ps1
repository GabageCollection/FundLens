# Full FundLens Windows release pipeline:
#   verify toolchain -> build engine bundle -> Dart/Flutter tests -> analyze
#   -> flutter build windows --release -> stage engine into the bundle
#   -> verify_bundle.ps1 -> Inno Setup compile (skipped when ISCC is absent).
#
# Run from anywhere: powershell -File tools/build_windows_release.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$appDir = Join-Path $repoRoot 'apps\fundlens_windows'
$releaseDir = Join-Path $appDir 'build\windows\x64\runner\Release'
$engineDist = Join-Path $repoRoot 'dist\engine\fundlens_engine'

# Flutter SDK locations (mirrors tools/verify_windows_toolchain.ps1).
$flutter = 'D:\flutter\bin\flutter.bat'
$dart = 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe'
$env:PATH = "D:\flutter\bin;$env:PATH"
# Pub mirror used by this project's CI/dev environment.
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

# Windows PowerShell 5.1 turns any native stderr output into a terminating
# NativeCommandError under $ErrorActionPreference='Stop'; run each step with
# Continue and gate on $LASTEXITCODE instead.
function Invoke-Step([string]$Name, [scriptblock]$Body) {
  Write-Host "==> $Name"
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Body
  } finally {
    $ErrorActionPreference = $previous
  }
  if ($LASTEXITCODE -ne 0) { throw "Step failed ($LASTEXITCODE): $Name" }
}

Invoke-Step 'Verify Windows toolchain' {
  powershell -NoProfile -File (Join-Path $repoRoot 'tools\verify_windows_toolchain.ps1')
}
Invoke-Step 'Build data engine bundle' {
  powershell -NoProfile -File (Join-Path $repoRoot 'tools\build_engine.ps1')
}
Invoke-Step 'dart test packages/fundlens_core' {
  & $dart test (Join-Path $repoRoot 'packages\fundlens_core')
}
Invoke-Step 'flutter test apps/fundlens_windows' {
  # Flutter tests need the sqlite3mc native library; the wrapper script
  # serves it during the test run and executes the command in the app dir.
  Push-Location $appDir
  try {
    & python (Join-Path $repoRoot 'tools\with_sqlite3mc_server.py') 45531 'flutter test'
  } finally {
    Pop-Location
  }
}
Invoke-Step 'flutter analyze apps/fundlens_windows' {
  & $flutter analyze $appDir
}
Invoke-Step 'flutter build windows --release' {
  & $flutter build windows --release --project-dir $appDir
}

Invoke-Step 'Stage engine bundle into release directory' {
  if (-not (Test-Path (Join-Path $engineDist 'fundlens_engine.exe'))) {
    throw "Engine bundle missing: $engineDist"
  }
  $target = Join-Path $releaseDir 'fundlens_engine'
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
  Copy-Item $engineDist $target -Recurse
}

Invoke-Step 'Verify release bundle' {
  powershell -NoProfile -File (Join-Path $repoRoot 'tests\release\verify_bundle.ps1') $releaseDir
}

$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (Test-Path $iscc) {
  Invoke-Step 'Compile installer (Inno Setup)' {
    & $iscc (Join-Path $repoRoot 'installer\FundLens.iss')
  }
  Write-Host '==> Release complete: dist\installer\FundLens-Setup.exe'
} else {
  Write-Host '==> ISCC.exe not found; skipping installer compile.'
  Write-Host "    Install Inno Setup 6 and run: `"$iscc`" installer\FundLens.iss"
}
