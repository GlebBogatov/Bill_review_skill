# bill-review

Claude Code / Agent **skill**: собирает фискальные чеки и квитанции из Gmail и
рендерит их в организованный PDF-архив (`<год>/<магазин>/Чек_ДАТА_ID.pdf`),
идемпотентно — один чек не сохраняется дважды между запусками.

> A Claude Code skill that harvests fiscal receipts from Gmail and renders them
> to an organized, de-duplicated PDF archive. Built for Russian OFD providers
> (Магнит, Билайн, Яндекс, ОФД.ру, Такском, 1-ОФД, …) and foreign invoices
> (Anthropic). Windows-first (headless Chrome + PowerShell + Python).

## Что внутри

```
SKILL.md                    # рабочий процесс (окно → запрос → идемпотентность → рендер → журнал)
references/
  providers.md              # таблица отправителей: как извлечь ФПД и получить PDF
  configuration.md          # ПОЛЬЗОВАТЕЛЬСКИЕ настройки — заполнить перед запуском
scripts/
  collect_saved_ids.py      # множество уже сохранённых ID из архива (идемпотентность)
  extract_html_body.py      # htmlBody/plaintextBody из сохранённого get_thread
  render_receipt.ps1        # рендер URL/HTML в PDF headless Chrome + проверка размера
```

## Установка

Скопируй содержимое репозитория в папку скилла Claude Code, названную по имени
скилла:

```
~/.claude/skills/bill-review/     # SKILL.md, references/, scripts/
```

(или в `.claude/skills/bill-review/` внутри проекта). Затем отредактируй
`references/configuration.md` под свою среду.

## Требования

- Gmail MCP (read-only достаточно)
- Google Chrome (headless `--print-to-pdf`)
- Python 3, PowerShell (Windows)

## Использование

- **Интерактивно:** «собери чеки за месяц» / «сохрани квитанции из почты» —
  скилл триггерится по описанию.
- **По расписанию:** оберни в cron/scheduled-task Claude Code (напр. ежедневно
  утром); логика идемпотентна, повторные окна безопасны.

Подробности механики — в `SKILL.md`. Провайдер-специфика — в
`references/providers.md`.

## Приватность

`references/configuration.md` содержит пути/аккаунт/список магазинов. Если репозиторий
публичный — держи реальные значения в приватной копии, оставив плейсхолдеры. См.
примечание в самом файле.
