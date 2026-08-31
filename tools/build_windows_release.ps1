# Full FundLens Windows release pipeline:
#   verify toolchain -> build engine bundle -> Dart/Flutter tests -> analyze
#   -> flutter build windows --release -> stage engine into the bundle
#   -> verify_bundle.ps1 -> Inno Setup compile (skipped when ISCC is absent).
#
# Run from anywhere: powershell -File tools/build_windows_release.ps1
#
# -UpdateManifestUrl: HTTPS address of the published version.json update
# manifest (e.g. a GitHub Releases asset). Baked into the app as the
# FUNDLENS_UPDATE_MANIFEST_URL dart-define; when omitted the in-app update
# check stays disabled.
#
# -InstallerDownloadUrl: public HTTPS download address of the built
# installer, written into version.json. Required together with
# -UpdateManifestUrl to also emit dist/installer/version.json.
#
# -FlutterRoot: Flutter SDK 根目录。默认取环境变量 FUNDLENS_FLUTTER_ROOT,
# 再回退 D:\flutter。换机器时无需改脚本,设环境变量或传参即可。

# -SkipEngine: 跳过引擎打包,直接复用 dist/engine/fundlens_engine 现有产物
#   (只改了 Flutter/Dart 代码时用;产物不存在时会在 Stage 步骤报错)。
# -FastCompress: Inno Setup 用 lzma2/fast 代替 lzma2(max),迭代验证时显著
#   缩短安装包压缩时间;正式发版不要加。

param(
  [string]$UpdateManifestUrl = '',
  [string]$InstallerDownloadUrl = '',
  [string]$FlutterRoot = '',
  [switch]$SkipEngine,
  [switch]$FastCompress
)

$ErrorActionPreference = 'Stop'

if (-not $FlutterRoot) { $FlutterRoot = $env:FUNDLENS_FLUTTER_ROOT }
if (-not $FlutterRoot) { $FlutterRoot = 'D:\flutter' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$appDir = Join-Path $repoRoot 'apps\fundlens_windows'
$releaseDir = Join-Path $appDir 'build\windows\x64\runner\Release'
$engineDist = Join-Path $repoRoot 'dist\engine\fundlens_engine'

# Flutter SDK locations (mirrors tools/verify_windows_toolchain.ps1).
$flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
$dart = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$env:PATH = "$FlutterRoot\bin;$env:PATH"
# Pub 镜像:默认使用 flutter-io.cn,可用环境变量覆盖(如 CI 直连 pub.dev
# 时设为 https://pub.dev;注意须与已提交 pubspec.lock 的 hosted URL 一致)。
if (-not $env:PUB_HOSTED_URL) { $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn' }
if (-not $env:FLUTTER_STORAGE_BASE_URL) { $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn' }

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
  powershell -NoProfile -File (Join-Path $repoRoot 'tools\verify_windows_toolchain.ps1') -FlutterRoot $FlutterRoot
}
if ($SkipEngine) {
  Write-Host '==> Skipping engine build (-SkipEngine); reusing dist/engine/fundlens_engine'
} else {
  Invoke-Step 'Build data engine bundle' {
    powershell -NoProfile -File (Join-Path $repoRoot 'tools\build_engine.ps1')
  }
}
Invoke-Step 'dart test packages/fundlens_core' {
  # dart test resolves the package from the working directory, so run it
  # from inside the package root.
  Push-Location (Join-Path $repoRoot 'packages\fundlens_core')
  try {
    & $dart test
  } finally {
    Pop-Location
  }
}
Invoke-Step 'flutter test apps/fundlens_windows' {
  # Port 8765 matches the sqlite3 url_pattern in the app's pubspec.yaml.
  Push-Location $appDir
  try {
    & python (Join-Path $repoRoot 'tools\with_sqlite3mc_server.py') 8765 'flutter test'
  } finally {
    Pop-Location
  }
}
Invoke-Step 'flutter analyze apps/fundlens_windows' {
  Push-Location $appDir
  try {
    & python (Join-Path $repoRoot 'tools\with_sqlite3mc_server.py') 8765 'flutter analyze'
  } finally {
    Pop-Location
  }
}
Invoke-Step 'flutter build windows --release' {
  $buildCmd = 'flutter build windows --release'
  if ($UpdateManifestUrl) {
    $buildCmd += " --dart-define=FUNDLENS_UPDATE_MANIFEST_URL=$UpdateManifestUrl"
  }
  # The sqlite3mc hook downloads its DLL on a cold cache; serve it locally.
  Push-Location $appDir
  try {
    & python (Join-Path $repoRoot 'tools\with_sqlite3mc_server.py') 8765 $buildCmd
  } finally {
    Pop-Location
  }
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

# Inno Setup 6 may be installed per-machine (Program Files (x86)) or
# per-user (%LOCALAPPDATA%\Programs, e.g. winget silent install).
$isccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$installerPath = Join-Path $repoRoot 'dist\installer\FundLens-Setup.exe'
if ($iscc) {
  Invoke-Step 'Compile installer (Inno Setup)' {
    $isccArgs = @()
    if ($FastCompress) { $isccArgs += '/DFastCompress' }
    $isccArgs += Join-Path $repoRoot 'installer\FundLens.iss'
    & $iscc @isccArgs
  }
  Write-Host '==> Release complete: dist\installer\FundLens-Setup.exe'
} else {
  Write-Host '==> ISCC.exe not found; skipping installer compile.'
  Write-Host "    Install Inno Setup 6 and run: ISCC.exe installer\FundLens.iss"
}

# Update manifest: generated only when the installer exists and both public
# URLs are known. The manifest's sha256 is computed from the installer that
# was just compiled, so a manifest always matches its asset.
if ((Test-Path $installerPath) -and $UpdateManifestUrl -and $InstallerDownloadUrl) {
  # dist/ 不入库,CI 上不存在;release notes 的规范来源是
  # docs/releases/release-notes-v<版本>.md(随版本提交),dist/ 仅作本地回退。
  $notesFile = Get-ChildItem (Join-Path $repoRoot 'docs\releases') -Filter 'release-notes-*.md' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
  if (-not $notesFile) {
    $notesFile = Get-ChildItem (Join-Path $repoRoot 'dist') -Filter 'release-notes-*.md' -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }
  $manifestArgs = @{
    InstallerPath = $installerPath
    DownloadUrl   = $InstallerDownloadUrl
  }
  if ($notesFile) { $manifestArgs.NotesFile = $notesFile.FullName }
  Invoke-Step 'Generate update manifest (version.json)' {
    # In-process call: a nested powershell.exe inherits this script's modified
    # PATH and can lose core cmdlets (Get-FileHash) on some machines.
    & (Join-Path $repoRoot 'tools\generate_update_manifest.ps1') @manifestArgs
    # In-process scripts do not set LASTEXITCODE; normalize it so Invoke-Step's
    # exit-code gate does not read a stale value from the previous step.
    $global:LASTEXITCODE = 0
  }
} elseif ($UpdateManifestUrl -or $InstallerDownloadUrl) {
  Write-Host '==> Skipping version.json: -UpdateManifestUrl and -InstallerDownloadUrl must be passed together, and the installer must exist.'
}
