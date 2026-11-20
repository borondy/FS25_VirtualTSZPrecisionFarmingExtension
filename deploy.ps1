# Copies the mod to an unzipped test folder (overwrites, removes files that no longer exist in the source).
# Target, in order: -Target parameter, $env:FS25_DEPLOY_DIR, first line of the git-ignored file .deploy-target.
# Usage: powershell -ExecutionPolicy Bypass -File deploy.ps1 [-Target <path>]
param(
    [string]$Target
)

$source = $PSScriptRoot
if (-not $Target) { $Target = $env:FS25_DEPLOY_DIR }
$targetFile = Join-Path $source '.deploy-target'
if (-not $Target -and (Test-Path $targetFile)) { $Target = (Get-Content $targetFile -TotalCount 1).Trim() }
if (-not $Target) {
    Write-Error "No deploy target. Pass -Target, set FS25_DEPLOY_DIR, or put a path in .deploy-target"
    exit 1
}
$Target = [System.IO.Path]::GetFullPath((Join-Path $source $Target))

if (-not (Test-Path (Join-Path $source 'modDesc.xml'))) {
    Write-Error "modDesc.xml not found in $source"
    exit 1
}

# robocopy: /MIR mirror (copy changed, delete removed), /XD /XF = not part of the game mod
robocopy $source $Target /MIR /XD assets .vscode .git .claude tools TODOs tests docs /XF README.md CLAUDE.md CLAUDE.local.md .deploy-target .gitignore deploy.ps1 create-zip.ps1 .zipignore TESTS.md *.zip /NFL /NDL /NJH /NP /R:2 /W:1
$code = $LASTEXITCODE
if ($code -ge 8) {
    Write-Error "robocopy failed with exit code $code"
    exit $code
}
Write-Output "Deployed to $Target"
exit 0
