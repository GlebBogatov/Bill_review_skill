# bill-review

Claude Code / Agent **skill**: собирает фискальные чеки и квитанции из Gmail и
рендерит их в организованный PDF-архив (`<год>/<магазин>/Чек_ДАТА_ID.pdf`),
идемпотентно — один чек не сохраняется дважды между запусками.

> A Claude skill that harvests fiscal receipts from Gmail and renders them to an
> organized, de-duplicated PDF archive. Built for Russian OFD providers (Магнит,
> Билайн, Яндекс, ОФД.ру, Такском, 1-ОФД, Saby/СБИС, Платформа ОФД, …) and
> foreign invoices (Anthropic). Windows-first (headless Chrome + PowerShell +
> Python).

## Что внутри

```
SKILL.md                    # рабочий процесс (окно → запрос → идемпотентность → рендер → журнал)
README.md                   # этот файл
references/
  providers.md              # таблица отправителей: как извлечь ФПД и получить PDF
  configuration.md          # ПОЛЬЗОВАТЕЛЬСКИЕ настройки — заполнить перед запуском (плейсхолдеры)
scripts/
  collect_saved_ids.py      # множество уже сохранённых ID из архива (идемпотентность)
  extract_html_body.py      # htmlBody/поля из сохранённого get_thread (+ режим --fields-only)
  render_receipt.ps1        # рендер URL/HTML в PDF headless Chrome + проверка размера и %PDF
  sync_skill.ps1            # git pull + зеркалирование публичных файлов в рабочую папку
```

## Установка

### Claude Code

Скопируй содержимое репозитория в папку скилла Claude Code:

```
~/.claude/skills/bill-review/          # SKILL.md, references/, scripts/
```

(или в `.claude/skills/bill-review/` внутри проекта; либо как scheduled-task в
`~/.claude/scheduled-tasks/bill-review/`). Затем отредактируй
`references/configuration.md` под свою среду. Встроенные инструменты
(Bash/PowerShell, Gmail MCP, файлы) покрывают все нужды без доп. MCP.

### Claude Desktop

Формат уже совместим со Skills. Загрузи в Settings → Capabilities → **Skills**
(включи Code execution) zip-архив со скиллом или распакуй папку в каталог
скиллов.

⚠ **Важно про песочницу.** Встроенная песочница Skills в Claude Desktop —
изолированный Linux-контейнер: она **не видит** локальный диск, локальный Chrome
и твой Gmail. Поэтому одной загрузки скилла недостаточно — нужен **локальный
MCP-мост** с исполнением команд и доступом к файловой системе (например
**Desktop Commander**) плюс **Gmail-коннектор**. Через них пойдут вызовы
`python`/`powershell`, скачивание PDF и чтение/запись архива.

| Ресурс | Claude Code | Claude Desktop |
|---|---|---|
| Поиск/чтение Gmail (read) | Gmail MCP | Gmail-коннектор |
| Файловая система архива | встроенный доступ | локальный exec/FS-MCP |
| Запуск Python / PowerShell / Chrome | встроенный shell | локальный exec-MCP |

## Требования

- Gmail MCP / Gmail-коннектор (read-only достаточно)
- Google Chrome (headless `--print-to-pdf`); для OFD.ru — `Invoke-WebRequest`
- Python 3, PowerShell (Windows)

## Использование

- **Интерактивно:** «собери чеки за месяц» / «сохрани квитанции из почты» —
  скилл триггерится по описанию.
- **По расписанию:** оберни в cron/scheduled-task (напр. ежедневно утром);
  логика идемпотентна, повторные окна безопасны.

Подробности механики — в `SKILL.md`. Провайдер-специфика — в
`references/providers.md`.

## Автосинхронизация из git

`scripts/sync_skill.ps1` подтягивает свежую версию из репозитория и зеркалирует
**публичные** файлы (`SKILL.md`, `README.md`, `references/providers.md`,
`scripts/*`) в рабочую папку скилла. `references/configuration.md` (реальные
локальные значения) и журнал прогонов **не трогаются**.

```powershell
scripts/sync_skill.ps1 -CloneDir "<клон репозитория>" -LiveDir "<рабочая папка скилла>"
```

Повесь на расписание (планировщик Windows или ежедневный scheduled-task Claude),
чтобы изменения из git приходили в скилл автоматически. Источник истины для
публичных файлов — репозиторий: правь их здесь, а не в рабочей копии.

## Приватность

`references/configuration.md` в репозитории — только **плейсхолдеры**. Реальные
значения (домашний путь, аккаунт Gmail, список магазинов с ИНН) держи в
`configuration.local.md` (в `.gitignore`) или в рабочей папке скилла вне
репозитория. Журнал прогонов (`sessions_bill_review.md`) — тоже приватный, в
`.gitignore`. `sync_skill.ps1` намеренно не переносит эти файлы.
