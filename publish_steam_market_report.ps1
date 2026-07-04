Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Git = "C:\Users\bianc\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe"
$GitRemoteHelper = "C:\Users\bianc\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\mingw64\bin"
$UpdateScript = Join-Path $Root "auto_update_steam_market_report.ps1"

$env:GIT_EXEC_PATH = $GitRemoteHelper
$env:PATH = "$GitRemoteHelper;$env:PATH"

& powershell -NoProfile -ExecutionPolicy Bypass -File $UpdateScript

& $Git --git-dir=.git-local --work-tree=. add steam_market_report.html steam_market_history.json
$status = & $Git --git-dir=.git-local --work-tree=. status --porcelain -- steam_market_report.html steam_market_history.json
if (-not [string]::IsNullOrWhiteSpace(($status -join "`n"))) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
  & $Git --git-dir=.git-local --work-tree=. commit -m "Update market report $stamp"
  & $Git --git-dir=.git-local --work-tree=. push origin main
  & $Git --git-dir=.git-local --work-tree=. push origin main:gh-pages
} else {
  Write-Host "No report changes to publish."
}
