<#
.SYNOPSIS
  Подтянуть последнюю версию скилла из git и зеркалировать «публичные» файлы в
  рабочую папку скилла, НЕ трогая приватную конфигурацию и журнал.

.DESCRIPTION
  Механизм авто-доставки изменений из репозитория в «живой» скилл:
    1. `git -C <CloneDir> pull --ff-only` — best-effort: при сетевой/auth-ошибке
       печатает предупреждение и продолжает с тем, что уже есть в клоне.
    2. Копирует из клона в <LiveDir> только ПУБЛИЧНЫЕ файлы (список ниже).
       `references/configuration.md` НЕ копируется — в <LiveDir> лежат реальные
       локальные значения; журнал и `.git` тоже не трогаются.

  Источник истины для публичных файлов — git-репозиторий: правь их через репозиторий,
  локальные правки этих файлов в <LiveDir> будут перезаписаны при следующем прогоне.

.PARAMETER CloneDir  git-клон репозитория (working tree).
.PARAMETER LiveDir   рабочая папка скилла — цель зеркалирования.
.PARAMETER NoPull    пропустить git pull (только зеркалировать текущий клон).

.EXAMPLE
  .\sync_skill.ps1 -CloneDir "C:\Users\<Имя>\Bill_review_skill" `
                   -LiveDir  "C:\Users\<Имя>\.claude\scheduled-tasks\bill-review"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $CloneDir,
  [Parameter(Mandatory = $true)] [string] $LiveDir,
  [switch] $NoPull
)

# git может быть не на PATH в окружении планировщика — найдём явно.
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
    catch { Write-Warning "git pull не удался: $($_.Exception.Message). Зеркалирую текущий клон." }
  } else {
    Write-Warning "git не найден — пропускаю pull, зеркалирую текущий клон."
  }
}

# ПУБЛИЧНЫЕ (зеркалируемые) файлы. configuration.md, журнал, .git — НАМЕРЕННО не тут.
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
  if (-not (Test-Path $src)) { Write-Warning "нет в клоне: $rel"; continue }
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
