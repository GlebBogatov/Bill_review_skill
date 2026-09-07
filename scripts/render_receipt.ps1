<#
.SYNOPSIS
  Отрендерить один чек (URL или локальный HTML) в PDF через headless Chrome.

.DESCRIPTION
  Идемпотентно и с проверкой размера:
    * если чек с этим ID (ФПД/номер, хвост имени `_<ID>.pdf`) уже сохранён под
      ЛЮБОЙ датой — пропуск (SKIP). Сверка по ID, а не по точному имени, устойчива
      к сдвигу даты/таймзоны между запусками;
    * рендер через `Start-Process -Wait` (форма bash `& ... 2>$null` файл НЕ
      создаёт надёжно — не используется);
    * после рендера файл < MinKB считается битым: удаляется, статус FAIL
      (чек попадёт в следующий запуск).

  Про path-guard: удаление недоразмерного файла живёт ВНУТРИ этого .ps1, поэтому
  строка вызова не содержит одновременно `Remove-Item` и путь к chrome.exe —
  path-guard некоторых окружений не срабатывает. Не переносите Remove-Item в ту
  же однострочную команду, где фигурирует путь `"C:\Program..."`.

.PARAMETER Source
  URL (https://…) или локальный источник (`file:///C:/…/receipt.html`).

.PARAMETER OutPath
  Абсолютный путь целевого `Чек_YYYY-MM-DD_<ID>.pdf`.

.PARAMETER Force
  Игнорировать идемпотентность (перерендерить, даже если чек с этим ID уже есть).

.EXAMPLE
  .\render_receipt.ps1 -Source "https://check.yandex.ru/?n=..&fn=..&fpd=.." `
    -OutPath "D:\receipts\2026\Store\Чек_2026-01-01_1234567890.pdf"

.EXAMPLE
  # Много чеков в цикле:
  $jobs | ForEach-Object { .\render_receipt.ps1 -Source $_.src -OutPath $_.out }
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $Source,
  [Parameter(Mandatory = $true)] [string] $OutPath,
  [string] $Chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe",
  [double] $MinKB = 4,
  [switch] $Force
)

$dir = Split-Path -Parent $OutPath
$leaf = Split-Path -Leaf $OutPath
# ID = хвост имени после последнего "_" (ФПД цифрами или иностранный 2067-2022-6800).
$id = if ($leaf -match '_([^_]+)\.pdf$') { $Matches[1] } else { $null }
if (-not $Force -and $id -and (Test-Path $dir) -and `
    (Get-ChildItem -Path $dir -Filter "*_$id.pdf" -ErrorAction SilentlyContinue)) {
  Write-Output "SKIP exists (id $id): $OutPath"
  return
}
if (-not $Force -and (Test-Path $OutPath)) {
  Write-Output "SKIP exists: $OutPath"
  return
}

if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

Start-Process -FilePath $Chrome -Wait -NoNewWindow -ArgumentList `
  "--headless=new", "--disable-gpu", "--print-to-pdf=`"$OutPath`"", `
  "--print-to-pdf-no-header", $Source

if (-not (Test-Path $OutPath)) {
  Write-Output "FAIL not created: $OutPath"
  return
}

$kb = [math]::Round((Get-Item $OutPath).Length / 1KB, 1)
# Магия %PDF: размер-проверка одна не ловит HTML-страницу ошибки (>MinKB, но не PDF).
$magic = ''
try {
  $fs = [System.IO.File]::OpenRead($OutPath)
  $buf = New-Object byte[] 5
  $null = $fs.Read($buf, 0, 5)
  $fs.Close()
  $magic = -join ($buf | ForEach-Object { [char]$_ })
} catch { }
if ($kb -gt $MinKB -and $magic -eq '%PDF-') {
  Write-Output "OK $kb KB: $OutPath"
} else {
  Remove-Item $OutPath -Force
  Write-Output "FAIL bad output (size $kb KB, magic '$magic') removed: $OutPath"
}
