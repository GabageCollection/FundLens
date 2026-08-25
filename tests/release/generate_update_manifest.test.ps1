# Self-contained test for tools/generate_update_manifest.ps1.
# Run: powershell -File tests/release/generate_update_manifest.test.ps1
# Exits 0 when all assertions pass, 1 otherwise.

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$generator = Join-Path $repoRoot 'tools\generate_update_manifest.ps1'

$script:passed = 0
$script:failed = 0
function Assert-True([bool]$Condition, [string]$Name) {
  if ($Condition) {
    $script:passed++
    Write-Host "PASS: $Name"
  } else {
    $script:failed++
    Write-Host "FAIL: $Name" -ForegroundColor Red
  }
}

# Runs the generator expecting failure; stderr is swallowed so the child's
# error output does not become a terminating NativeCommandError under
# $ErrorActionPreference='Stop'. Returns the child exit code.
function Invoke-GeneratorExpectFailure {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & powershell -NoProfile -File $generator @Arguments 2>&1 | Out-Null
    return $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
}

# Fixture: a fake installer whose SHA-256 we control.
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('fundlens-manifest-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
try {
  $fakeInstaller = Join-Path $tempDir 'FundLens-Setup.exe'
  [System.IO.File]::WriteAllText($fakeInstaller, 'fake installer bytes')
  $expectedHash = (Get-FileHash $fakeInstaller -Algorithm SHA256).Hash.ToLower()
  $outPath = Join-Path $tempDir 'version.json'

  # 1. Happy path: explicit version, notes, compact JSON, correct sha256.
  & powershell -NoProfile -File $generator `
    -InstallerPath $fakeInstaller `
    -Version '9.9.9' `
    -DownloadUrl 'https://example.com/FundLens-Setup.exe' `
    -Notes '测试更新说明' `
    -OutPath $outPath | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) 'generator exits 0 on happy path'
  Assert-True (Test-Path $outPath) 'version.json was written'

  $json = Get-Content $outPath -Raw -Encoding UTF8
  $manifest = $json | ConvertFrom-Json
  Assert-True ($manifest.version -eq '9.9.9') 'version field matches -Version'
  Assert-True ($manifest.url -eq 'https://example.com/FundLens-Setup.exe') 'url field matches -DownloadUrl'
  Assert-True ($manifest.sha256 -eq $expectedHash) 'sha256 matches the installer bytes'
  Assert-True ($manifest.notes -eq '测试更新说明') 'notes field matches -Notes'
  Assert-True ($json -notmatch "`n") 'JSON is compact (single line)'

  # UTF-8 without BOM: first bytes must not be EF BB BF.
  $bytes = [System.IO.File]::ReadAllBytes($outPath)
  Assert-True (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) 'no UTF-8 BOM'
  # Chinese notes must round-trip through UTF-8.
  $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
  Assert-True ($decoded.Contains('测试更新说明')) 'Chinese notes survive UTF-8 round-trip'

  # 2. Version defaults to installer/FundLens.iss AppVersion.
  $outPath2 = Join-Path $tempDir 'version2.json'
  & powershell -NoProfile -File $generator `
    -InstallerPath $fakeInstaller `
    -DownloadUrl 'https://example.com/x.exe' `
    -OutPath $outPath2 | Out-Null
  $manifest2 = (Get-Content $outPath2 -Raw -Encoding UTF8) | ConvertFrom-Json
  Assert-True ($manifest2.version -match '^\d+\.\d+\.\d+$') "version falls back to .iss AppVersion (got $($manifest2.version))"

  # 3. Non-HTTPS download URL is rejected.
  $rc = Invoke-GeneratorExpectFailure @(
    '-InstallerPath', $fakeInstaller,
    '-DownloadUrl', 'http://insecure.example.com/x.exe',
    '-OutPath', (Join-Path $tempDir 'never.json')
  )
  Assert-True ($rc -ne 0) 'non-HTTPS download URL is rejected'

  # 4. Missing installer is rejected.
  $rc = Invoke-GeneratorExpectFailure @(
    '-InstallerPath', (Join-Path $tempDir 'missing.exe'),
    '-DownloadUrl', 'https://example.com/x.exe',
    '-OutPath', (Join-Path $tempDir 'never2.json')
  )
  Assert-True ($rc -ne 0) 'missing installer is rejected'

  # 5. NotesFile reads and trims the file.
  $notesFile = Join-Path $tempDir 'notes.md'
  [System.IO.File]::WriteAllText($notesFile, "  从文件读取的说明`n")
  $outPath3 = Join-Path $tempDir 'version3.json'
  & powershell -NoProfile -File $generator `
    -InstallerPath $fakeInstaller `
    -DownloadUrl 'https://example.com/x.exe' `
    -NotesFile $notesFile `
    -OutPath $outPath3 | Out-Null
  $manifest3 = (Get-Content $outPath3 -Raw -Encoding UTF8) | ConvertFrom-Json
  Assert-True ($manifest3.notes -eq '从文件读取的说明') 'NotesFile content is read and trimmed'

  # 6. -Notes and -NotesFile together are rejected.
  $rc = Invoke-GeneratorExpectFailure @(
    '-InstallerPath', $fakeInstaller,
    '-DownloadUrl', 'https://example.com/x.exe',
    '-Notes', 'a', '-NotesFile', $notesFile,
    '-OutPath', (Join-Path $tempDir 'never3.json')
  )
  Assert-True ($rc -ne 0) '-Notes and -NotesFile together are rejected'
} finally {
  Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
