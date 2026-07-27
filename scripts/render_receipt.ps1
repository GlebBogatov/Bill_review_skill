<#
.SYNOPSIS
  Отрендерить один чек (URL или локальный HTML) в PDF через headless Chrome.

.DESCRIPTION
  Идемпотентно и с проверкой размера:
    * если целевой PDF уже существует — пропуск (SKIP);
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
  [double] $MinKB = 4
)

if (Test-Path $OutPath) {
  Write-Output "SKIP exists: $OutPath"
  return
}

$dir = Split-Path -Parent $OutPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

Start-Process -FilePath $Chrome -Wait -NoNewWindow -ArgumentList `
  "--headless=new", "--disable-gpu", "--print-to-pdf=`"$OutPath`"", `
  "--print-to-pdf-no-header", $Source

if (-not (Test-Path $OutPath)) {
  Write-Output "FAIL not created: $OutPath"
  return
}

$kb = [math]::Round((Get-Item $OutPath).Length / 1KB, 1)
if ($kb -gt $MinKB) {
  Write-Output "OK $kb KB: $OutPath"
} else {
  Remove-Item $OutPath -Force
  Write-Output "FAIL too small ($kb KB) removed: $OutPath"
}
