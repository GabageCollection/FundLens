# FundLens V1 clean-VM acceptance script.
#
# Runs the Phase 4 plan Task 5 Step 3 acceptance flow on a clean Windows VM:
# silent install, launch, a documented 8-item manual checklist with synthetic
# data, upgrade-over-previous-build with database retention, and uninstall
# with data retention. Records installer SHA-256, Windows version, dependency
# lock hashes, timings and operator confirmations into a JSON evidence file.
#
# Prerequisites (NOT this script's job):
# - A disposable Windows VM (or VM snapshot) with a throwaway local user.
# - The V1 release candidate installer built by Task 4
#   (dist/installer/FundLens-Setup.exe) and, for the upgrade phase, the
#   previous build's installer.
# - Synthetic import files only (CSV/Excel/screenshots with fake data).
#   NEVER use real account screenshots or real holdings on the VM.
#
# Usage (on the VM, repo checkout or a copied tests/release directory):
#   powershell -ExecutionPolicy Bypass -File tests/release/clean_vm_acceptance.ps1 `
#     -InstallerPath C:\acceptance\FundLens-Setup.exe `
#     -PreviousInstallerPath C:\acceptance\FundLens-Setup-prev.exe `
#     -RepoRoot C:\acceptance\FundLens
#
# Exit code 0 = every automated check passed and every checklist item was
# confirmed; 1 = at least one failure or rejected checklist item.

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$InstallerPath,

  # Previous build's installer for the upgrade-retention phase. When omitted
  # the upgrade phase is skipped and recorded as not-run.
  [string]$PreviousInstallerPath,

  # Repo root used to hash dependency lockfiles (pubspec.lock,
  # requirements.lock). When omitted, lock hashes are recorded as unavailable.
  [string]$RepoRoot,

  [string]$EvidencePath = (Join-Path $PSScriptRoot 'clean_vm_evidence.json')
)

$ErrorActionPreference = 'Stop'

$results = [ordered]@{
  startedAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
  installer      = $null
  environment    = $null
  dependencyLocks = @()
  phases         = [ordered]@{}
  checklist      = @()
  failures       = @()
}

function Save-Evidence {
  $results.finishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  ($results | ConvertTo-Json -Depth 6) | Set-Content -Encoding UTF8 $EvidencePath
}

function Add-Failure([string]$message) {
  $script:results.failures.Add($message)
  Write-Host "FAIL: $message" -ForegroundColor Red
}

function Read-Confirmation([string]$prompt) {
  while ($true) {
    $answer = Read-Host "$prompt [y/n]"
    switch ($answer.ToLowerInvariant()) {
      'y' { return $true }
      'n' { return $false }
    }
  }
}

function Invoke-ChecklistItem([int]$number, [string]$title, [string[]]$steps) {
  Write-Host ''
  Write-Host "=== Checklist $number/8: $title ===" -ForegroundColor Cyan
  foreach ($step in $steps) { Write-Host "  - $step" }
  $confirmed = Read-Confirmation 'Item completed as described?'
  $note = Read-Host 'Optional note (synthetic data only, Enter to skip)'
  $results.checklist.Add([ordered]@{
      number    = $number
      title     = $title
      confirmed = $confirmed
      note      = $note
    })
  if (-not $confirmed) { Add-Failure "Checklist item $number rejected: $title" }
}

function Get-Sha256([string]$path) {
  (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
}

# --- Pre-flight ------------------------------------------------------------

if (-not (Test-Path $InstallerPath -PathType Leaf)) {
  throw "Installer not found: $InstallerPath"
}
$InstallerPath = (Resolve-Path $InstallerPath).Path

$os = Get-CimInstance Win32_OperatingSystem
$results.installer = [ordered]@{
  path   = $InstallerPath
  sha256 = Get-Sha256 $InstallerPath
  bytes  = (Get-Item $InstallerPath).Length
}
$results.environment = [ordered]@{
  windowsCaption = $os.Caption
  windowsVersion = $os.Version
  windowsBuild   = $os.BuildNumber
  computerName   = $env:COMPUTERNAME
  userName       = $env:USERNAME
}
Write-Host "Installer SHA-256: $($results.installer.sha256)"
Write-Host "Windows: $($os.Caption) ($($os.Version), build $($os.BuildNumber))"

$lockFiles = @(
  'apps/fundlens_windows/pubspec.lock',
  'packages/fundlens_core/pubspec.lock',
  'engine/requirements.lock'
)
foreach ($relative in $lockFiles) {
  $entry = [ordered]@{ path = $relative; sha256 = $null }
  if ($RepoRoot) {
    $full = Join-Path $RepoRoot $relative
    if (Test-Path $full -PathType Leaf) { $entry.sha256 = Get-Sha256 $full }
  }
  $results.dependencyLocks.Add($entry)
}

$installDir = Join-Path $env:LOCALAPPDATA 'Programs\FundLens'
$dataDir = Join-Path $env:APPDATA 'FundLens'
$exePath = Join-Path $installDir 'FundLens.exe'
$appProcess = $null

function Install-FundLens([string]$installer, [string]$phaseKey) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $proc = Start-Process -FilePath $installer -PassThru -Wait -ArgumentList `
    '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES'
  $sw.Stop()
  $results.phases[$phaseKey] = [ordered]@{
    exitCode = $proc.ExitCode
    elapsedMs = $sw.ElapsedMilliseconds
  }
  Write-Host "$phaseKey exit=$($proc.ExitCode) in $($sw.ElapsedMilliseconds)ms"
  if ($proc.ExitCode -ne 0) { throw "$phaseKey failed with exit $($proc.ExitCode)" }
  if (-not (Test-Path $exePath -PathType Leaf)) {
    throw "$phaseKey did not produce $exePath"
  }
}

function Wait-FundLensWindow([int]$timeoutSeconds = 120) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
    $proc = Get-Process -Name 'FundLens' -ErrorAction SilentlyContinue |
      Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($proc) { $sw.Stop(); return @{ process = $proc; elapsedMs = $sw.ElapsedMilliseconds } }
    Start-Sleep -Milliseconds 500
  }
  throw "FundLens main window did not appear within $timeoutSeconds s"
}

# --- Phase 1: clean install + launch ----------------------------------------

try {
  Install-FundLens $InstallerPath 'cleanInstall'

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $appProcess = Start-Process -FilePath $exePath -PassThru
  $launch = Wait-FundLensWindow
  $results.phases['firstLaunch'] = [ordered]@{
    windowElapsedMs = $launch.elapsedMs
  }
  Write-Host "FundLens window appeared in $($launch.elapsedMs)ms"
  $appProcess = $launch.process

  # Automated part of checklist item 8: no logs/backups/user images may sit
  # in the installation directory.
  $suspicious = Get-ChildItem $installDir -Recurse -File | Where-Object {
    $_.Name -match '\.(log|fundlens-backup)$' -or
      ($_.Extension -match '^\.(png|jpg|jpeg)$' -and
        $_.FullName -notmatch 'flutter_assets')
  }
  $results.phases['installDirScan'] = [ordered]@{
    suspiciousFiles = @($suspicious | ForEach-Object { $_.FullName })
  }
  if ($suspicious) {
    Add-Failure "Install directory contains log/backup/image files: $($suspicious.Name -join ', ')"
  }

  # --- Phase 2: manual checklist (synthetic data only) ---------------------

  Invoke-ChecklistItem 1 '手动添加现金、存款和实物黄金' @(
    '在“全部持仓”页手动添加一笔现金类、一笔存款和一笔实物黄金持仓。',
    '确认三类资产都显示正确金额，颜色遵循红盈利/绿亏损。'
  )
  Invoke-ChecklistItem 2 '支付宝截图部分导入并处理低置信度字段' @(
    '在“导入与识别”页导入合成支付宝截图，确认默认模式为“部分持仓”。',
    '对一处低置信度字段进行人工修正后再确认写入。'
  )
  Invoke-ChecklistItem 3 '同花顺截图导入字段核对' @(
    '导入合成同花顺截图，核对名称、金额、份额、成本和正负号。'
  )
  Invoke-ChecklistItem 4 '行情刷新与无份额平台金额保持' @(
    '使用假/预生产行情源刷新行情。',
    '确认支付宝等只有金额来源的持仓金额保持不变，失败时保留上次有效值。'
  )
  Invoke-ChecklistItem 5 '快照保存与资产金额变化对比' @(
    '保存两个快照并对比，差额只标注为“资产金额变化”。',
    '确认界面不出现任何“快照收益”或投资建议字样。'
  )
  Invoke-ChecklistItem 6 '加密备份、错误密码拒绝与恢复' @(
    '创建加密备份；用错误密码恢复必须被拒绝且不改变当前数据。',
    '用正确密码恢复成功，数据与备份时一致。'
  )
  Invoke-ChecklistItem 7 '引擎崩溃后的降级模式' @(
    '在任务管理器中结束 fundlens_engine 进程。',
    '确认应用进入降级模式：手动数据和缓存数据仍可用，界面有明确提示。'
  )
  Invoke-ChecklistItem 8 '措辞与安装目录检查' @(
    '浏览六个页面，确认没有任何投资建议或买卖推荐措辞。',
    '确认安装目录中没有日志、备份、真实截图或用户文件（脚本已自动扫描）。'
  )

  Write-Host ''
  Write-Host 'Reminder: any screenshots taken must contain synthetic data only.'
  $shots = Read-Host 'Screenshot directory for evidence (Enter to skip)'
  if ($shots) { $results.phases['screenshots'] = @{ directory = $shots } }

  # --- Phase 3: upgrade over previous build, database retention ------------

  if ($PreviousInstallerPath) {
    if (-not (Test-Path $PreviousInstallerPath -PathType Leaf)) {
      throw "Previous installer not found: $PreviousInstallerPath"
    }
    $dbBefore = Get-ChildItem $dataDir -Recurse -File -ErrorAction SilentlyContinue |
      Sort-Object FullName | ForEach-Object { "$($_.FullName):$($_.Length)" }
    Stop-Process -Name 'FundLens' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Install-FundLens $PreviousInstallerPath 'upgradeInstall'

    $dbAfter = Get-ChildItem $dataDir -Recurse -File -ErrorAction SilentlyContinue |
      Sort-Object FullName | ForEach-Object { "$($_.FullName):$($_.Length)" }
    $retained = ($null -ne $dbBefore) -and
      (@(Compare-Object $dbBefore $dbAfter).Count -eq 0)
    $results.phases['upgradeRetention'] = [ordered]@{
      previousSha256 = Get-Sha256 (Resolve-Path $PreviousInstallerPath).Path
      databaseRetained = $retained
    }
    if (-not $retained) { Add-Failure 'Database files changed after upgrade install' }

    $launch2 = Wait-FundLensWindow
    Write-Host "Relaunched after upgrade in $($launch2.elapsedMs)ms"
    $kept = Read-Confirmation 'Upgrade kept the pre-upgrade holdings and snapshots?'
    if (-not $kept) { Add-Failure 'Data not retained across upgrade (operator report)' }
  }
  else {
    $results.phases['upgradeRetention'] = @{ skipped = 'no previous installer provided' }
    Write-Host 'Upgrade phase skipped (no -PreviousInstallerPath).'
  }

  # --- Phase 4: uninstall, data retention -----------------------------------

  Stop-Process -Name 'FundLens' -Force -ErrorAction SilentlyContinue
  Stop-Process -Name 'fundlens_engine' -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2

  $uninstaller = Get-ChildItem $installDir -Filter 'unins*.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $uninstaller) { throw "Uninstaller not found under $installDir" }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $uninstallProc = Start-Process -FilePath $uninstaller.FullName -PassThru -Wait `
    -ArgumentList '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES'
  $sw.Stop()
  $dataRetained = Test-Path $dataDir -PathType Container
  $results.phases['uninstall'] = [ordered]@{
    exitCode        = $uninstallProc.ExitCode
    elapsedMs       = $sw.ElapsedMilliseconds
    dataDirRetained = $dataRetained
  }
  Write-Host "Uninstall exit=$($uninstallProc.ExitCode) in $($sw.ElapsedMilliseconds)ms; data retained: $dataRetained"
  if ($uninstallProc.ExitCode -ne 0) { Add-Failure "Uninstall exit code $($uninstallProc.ExitCode)" }
  # Silent uninstall can never tick the deletion checkbox, so the data
  # directory must survive.
  if (-not $dataRetained) {
    Add-Failure 'User data directory was removed by silent uninstall (deletion checkbox was NOT selectable)'
  }
  if (Test-Path $exePath) { Add-Failure 'FundLens.exe still present after uninstall' }
}
finally {
  Save-Evidence
  Write-Host ''
  Write-Host "Evidence written to $EvidencePath"
}

if ($results.failures.Count -gt 0) {
  Write-Host "$($results.failures.Count) acceptance failure(s); see evidence file." -ForegroundColor Red
  exit 1
}
Write-Host 'clean_vm_acceptance: PASS' -ForegroundColor Green
exit 0
