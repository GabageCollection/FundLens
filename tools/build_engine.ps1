# Builds the FundLens data engine into dist/engine/fundlens_engine/ as a
# one-directory PyInstaller bundle with bundled Chinese OCR models.
#
# Steps: recreate an isolated build venv from requirements.lock, run the
# engine test suite, stage the PaddleOCR models the engine actually uses
# (downloading them on first run), invoke PyInstaller, lay out the models
# and license files, health-check the exe over the JSON-RPC stdio protocol
# (schema_version 1) and smoke-test real OCR on a synthetic fixture.
#
# Run from anywhere: powershell -File tools/build_engine.ps1
# Optional: -SkipTests to reuse an existing venv without rerunning pytest.

param(
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$engineDir = Join-Path $repoRoot 'engine'
$venvDir = Join-Path $engineDir '.venv-build'
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
$modelsStaging = Join-Path $engineDir 'models'
$distDir = Join-Path $repoRoot 'dist\engine'
$workDir = Join-Path $repoRoot 'build\engine'
$bundleDir = Join-Path $distDir 'fundlens_engine'
$exePath = Join-Path $bundleDir 'fundlens_engine.exe'

# Native commands (python, pip, pytest, PyInstaller) routinely write
# progress/warnings to stderr; under $ErrorActionPreference='Stop'
# Windows PowerShell 5.1 turns any stderr line into a terminating
# NativeCommandError. Run them with Continue and check $LASTEXITCODE.
function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @()
  )
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $FilePath @Arguments
  } finally {
    $ErrorActionPreference = $previous
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed (exit $LASTEXITCODE): $FilePath $($Arguments -join ' ')"
  }
}

function Find-Python311 {
  foreach ($candidate in @('python', 'py -3.11')) {
    $parts = $candidate -split ' '
    if (-not (Get-Command $parts[0] -ErrorAction SilentlyContinue)) { continue }
    # Quote-free probe: PowerShell 5.1 mangles embedded quotes in native
    # arguments. Prints 311 / 312 for the supported interpreters.
    $versionArgs = @('-c', 'import sys;print(sys.version_info[0]*100+sys.version_info[1])')
    if ($parts.Count -gt 1) { $versionArgs = @($parts[1]) + $versionArgs }
    $version = $null
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $version = & $parts[0] @versionArgs 2>$null } catch { }
    $ErrorActionPreference = $previous
    if ($version -match '^(311|312)$') { return $candidate }
  }
  throw 'Python 3.11 or 3.12 not found (requires-python >=3.11,<3.13).'
}

if ($SkipTests -and (Test-Path $venvPython)) {
  Write-Host '==> Reusing existing build venv (-SkipTests)'
} else {
  Write-Host '==> Recreating isolated build venv from requirements.lock'
  if (Test-Path $venvDir) { Remove-Item $venvDir -Recurse -Force }
  $pythonCmd = (Find-Python311) -split ' '
  $venvArgs = @('-m', 'venv', $venvDir)
  if ($pythonCmd.Count -gt 1) { $venvArgs = @($pythonCmd[1]) + $venvArgs }
  Invoke-Native $pythonCmd[0] $venvArgs
  Invoke-Native $venvPython @('-m', 'pip', 'install', '--no-input', '-r', (Join-Path $engineDir 'requirements.lock'))
  Invoke-Native $venvPython @('-m', 'pip', 'install', '--no-input', '-e', $engineDir, '--no-deps')
}

if (-not $SkipTests) {
  Write-Host '==> Running engine test suite'
  $basetemp = Join-Path $engineDir '.pytest-basetemp'
  try {
    Invoke-Native $venvPython @('-m', 'pytest', (Join-Path $engineDir 'tests'), '-q', "--basetemp=$basetemp")
  } finally {
    if (Test-Path $basetemp) { Remove-Item $basetemp -Recurse -Force }
  }
}

# Stage the OCR models the engine uses. PaddleOCR with the mobile
# detection/recognition set downloads its models into
# $PADDLE_PDX_CACHE_HOME/official_models on first use; pointing the cache
# home at engine/models makes the staging layout exactly what the bundle
# ships. Locked dependency versions keep the downloaded model set
# deterministic; delete engine/models to re-download.
if (-not (Test-Path (Join-Path $modelsStaging 'official_models\PP-OCRv5_mobile_rec'))) {
  Write-Host '==> Downloading PaddleOCR models into engine/models (first run only)'
  $env:PADDLE_PDX_CACHE_HOME = $modelsStaging
  try {
    Invoke-Native $venvPython @('-c', "from paddleocr import PaddleOCR; PaddleOCR(text_detection_model_name='PP-OCRv5_mobile_det', text_recognition_model_name='PP-OCRv5_mobile_rec', use_textline_orientation=True, lang='ch', enable_mkldnn=False)")
  } finally {
    Remove-Item Env:PADDLE_PDX_CACHE_HOME -ErrorAction SilentlyContinue
  }
} else {
  Write-Host '==> Using staged OCR models from engine/models'
}

# Prune HuggingFace download caches from the staged models: the .cache
# trees hold only download metadata (not needed at runtime) and bloat the
# installer. Model inference files (inference.*) are kept.
$cacheDirs = Get-ChildItem $modelsStaging -Recurse -Directory -Filter '.cache' -ErrorAction SilentlyContinue
foreach ($dir in $cacheDirs) { Remove-Item $dir.FullName -Recurse -Force }
if ($cacheDirs) { Write-Host "==> Pruned $($cacheDirs.Count) HuggingFace .cache dirs from staged models" }

Write-Host '==> Running PyInstaller (--clean --noconfirm)'
Push-Location $repoRoot
try {
  Invoke-Native $venvPython @(
    '-m', 'PyInstaller', '--clean', '--noconfirm',
    '--distpath', $distDir, '--workpath', $workDir,
    (Join-Path $engineDir 'fundlens_engine.spec')
  )
} finally {
  Pop-Location
}

# PyInstaller 6 one-dir collects datas under _internal; move the models up
# to <exe-dir>/models where the runtime hook and release verifier expect
# them.
$internalModels = Join-Path $bundleDir '_internal\models'
$bundleModels = Join-Path $bundleDir 'models'
if (Test-Path $bundleModels) { Remove-Item $bundleModels -Recurse -Force }
if (Test-Path $internalModels) {
  Move-Item $internalModels $bundleModels
} elseif (Test-Path $modelsStaging) {
  Copy-Item $modelsStaging $bundleModels -Recurse
} else {
  throw 'OCR models were not bundled: engine/models staging is empty.'
}

Write-Host '==> Copying third-party license files'
$licensesDir = Join-Path $bundleDir 'licenses'
New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null
$sitePackages = Join-Path $venvDir 'Lib\site-packages'
foreach ($pkg in @('paddleocr', 'paddlex', 'paddle')) {
  Get-ChildItem $sitePackages -Directory -Filter "$pkg*" -ErrorAction SilentlyContinue |
    ForEach-Object { Get-ChildItem $_.FullName -Filter 'LICENSE*' -ErrorAction SilentlyContinue } |
    Select-Object -First 1 |
    ForEach-Object { Copy-Item $_.FullName (Join-Path $licensesDir "$($pkg)_$($_.Name)") }
}

# The engine speaks UTF-8 on stdio (server._configure_stdio_utf8); PowerShell
# decodes native stdout with the console codepage (GBK on Chinese Windows),
# which would corrupt the Chinese text in OCR responses and break
# ConvertFrom-Json below.
$previousOutputEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# $OutputEncoding controls how piped strings are encoded into the engine's
# stdin. Some hosts emit a UTF-8 BOM; the engine strips it, but force
# BOM-less UTF-8 here for determinism.
$previousOutputEncodingVar = $OutputEncoding
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

Write-Host '==> Health-checking bundled engine (JSON-RPC schema_version 1)'
$healthRequest = '{"jsonrpc":"2.0","id":"health-1","method":"health.check","params":{},"schema_version":1}'
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  $responseLine = $healthRequest | & $exePath 2>$null | Select-Object -First 1
} finally {
  $ErrorActionPreference = $previous
}
if (-not $responseLine) { throw 'Engine health check produced no response.' }
$response = $responseLine | ConvertFrom-Json
if ($response.schema_version -ne 1 -or $response.result.status -ne 'ok') {
  throw "Engine health check failed: $responseLine"
}
Write-Host "==> Engine build OK: $exePath (schema_version $($response.schema_version), engine_version $($response.result.engine_version))"

# Exercise the real OCR path inside the bundle. The plain health check does
# not import paddle, so a missing runtime dependency (e.g. setuptools) would
# otherwise only surface for users importing screenshots.
Write-Host '==> Smoke-testing bundled OCR (alipay synthetic fixture)'
$ocrFixture = Join-Path $engineDir 'tests\fixtures\ocr\alipay_synthetic.png'
$ocrParams = @{ paths = @($ocrFixture); template = 'alipay' } | ConvertTo-Json -Compress
$ocrRequest = '{"jsonrpc":"2.0","id":"ocr-smoke-1","method":"ocr.parse_screenshots","params":' + $ocrParams + ',"schema_version":1}'
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  $ocrLine = $ocrRequest | & $exePath 2>$null | Select-Object -First 1
} finally {
  $ErrorActionPreference = $previous
}
if (-not $ocrLine) { throw 'Engine OCR smoke test produced no response.' }
$ocrResponse = $ocrLine | ConvertFrom-Json
if ($ocrResponse.error -or $null -eq $ocrResponse.result.rows) {
  throw "Engine OCR smoke test failed: $ocrLine"
}
[Console]::OutputEncoding = $previousOutputEncoding
$OutputEncoding = $previousOutputEncodingVar
Write-Host "==> Engine OCR smoke OK ($($ocrResponse.result.rows.Count) rows recognized)"
