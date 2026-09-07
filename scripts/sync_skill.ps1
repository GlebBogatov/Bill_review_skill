<#
.SYNOPSIS
  Pull the latest skill from git and mirror the PUBLIC files into the live skill
  folder, WITHOUT touching the private configuration or the run journal.

.DESCRIPTION
  Auto-delivery of repo changes into the live skill:
    1. `git -C <CloneDir> pull --ff-only` - best-effort: on a network/auth error
       it warns and continues with whatever is already in the clone.
    2. Copies only the PUBLIC files (list below) from the clone into <LiveDir>.
       `references/configuration.md` is NOT copied (the live folder holds the real
       local values); the journal and `.git` are left alone too.

  The git repository is the source of truth for the public files: edit them via
  the repo, not in the live copy - local edits to those files are overwritten on
  the next run.

  ASCII-only on purpose: a .ps1 with non-ASCII bytes saved without a BOM is
  misread by Windows PowerShell 5.1 (cp1251) and fails to parse.

.PARAMETER CloneDir  git clone (working tree).
.PARAMETER LiveDir   live skill folder - the mirror target.
.PARAMETER NoPull    skip git pull (mirror the current clone only).

.EXAMPLE
  .\sync_skill.ps1 -CloneDir "C:\Users\<Name>\Bill_review_skill" `
                   -LiveDir  "C:\Users\<Name>\.claude\scheduled-tasks\bill-review"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $CloneDir,
  [Parameter(Mandatory = $true)] [string] $LiveDir,
  [switch] $NoPull
)

# git may be off PATH under Task Scheduler - resolve it explicitly.
function Resolve-Git {
  $c = Get-Command git -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  foreach ($p in @(
      "$env:ProgramFiles\Git\cmd\git.exe",
      "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
      "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

if (-not $NoPull) {
  $git = Resolve-Git
  if ($git) {
    Write-Output "== git pull ($CloneDir) =="
    try { & $git -C $CloneDir pull --ff-only 2>&1 | ForEach-Object { Write-Output $_ } }
    catch { Write-Warning "git pull failed: $($_.Exception.Message). Mirroring current clone." }
  } else {
    Write-Warning "git not found - skipping pull, mirroring current clone."
  }
}

# PUBLIC (mirrored) files. configuration.md, journal, .git are intentionally excluded.
$files = @(
  'SKILL.md', 'README.md', 'LICENSE',
  'references/providers.md',
  'scripts/collect_saved_ids.py', 'scripts/extract_html_body.py',
  'scripts/render_receipt.ps1', 'scripts/sync_skill.ps1'
)

$changed = 0
foreach ($rel in $files) {
  $src = Join-Path $CloneDir $rel
  $dst = Join-Path $LiveDir  $rel
  if (-not (Test-Path $src)) { Write-Warning "missing in clone: $rel"; continue }
  $dstDir = Split-Path -Parent $dst
  if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
  $same = (Test-Path $dst) -and
    ((Get-FileHash $src -Algorithm SHA256).Hash -eq (Get-FileHash $dst -Algorithm SHA256).Hash)
  if (-not $same) {
    Copy-Item $src $dst -Force
    Write-Output "updated: $rel"
    $changed++
  }
}
Write-Output "== done: $changed file(s) updated in $LiveDir =="
