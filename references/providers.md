# Провайдеры (известные отправители)

Накопленное знание: как для каждого отправителя определить магазин (папку),
извлечь ФПД/поля и отрендерить PDF. Читай перед составлением Gmail-запроса и
перед рендером. Соответствия ИНН → папка — в `configuration.md`.

## Готовый Gmail-запрос

Подставь `after:YYYY/M/D` = сегодня − 31 день:

```
(from:info@ofd-magnit.ru OR from:ofdreceipt@beeline.ru OR from:subscrib@e.litres.ru OR from:noreply@check.yandex.ru OR from:echeck@1-ofd.ru OR from:noreply@taxcom.ru OR from:invoice+statements@mail.anthropic.com OR from:noreply@ofd.ru OR from:no-reply@ofd.yandex.ru) after:YYYY/M/D
```

## Таблица

| `from:` | Папка | Как получить ФПД/ID | Как получить PDF |
|---|---|---|---|
| `info@ofd-magnit.ru` | `Магнит` | ФПД = `ФП <digits>` в теле (совпадает с номером «Чек N» в subject) | Рендер `htmlBody` как HTML-файла |
| `ofdreceipt@beeline.ru` | `Билайн_ОФД` | `ФП <digits>` / `ФПД` в теле | Рендер `htmlBody` как HTML-файла |
| `subscrib@e.litres.ru` | `ЛитРес` | из тела | Рендер `htmlBody` как HTML-файла |
| `noreply@check.yandex.ru` | `Яндекс_Маркет` | `fpd=` из ссылки тела | Ссылка `https://check.yandex.ru/?n=<ФД>&fn=<ФН>&fpd=<ФПД>` → Chrome `--print-to-pdf` напрямую |
| `echeck@1-ofd.ru` | по ИНН из тела (см. `configuration.md`); иначе §4 | `ФП <digits>` в `htmlBody` | Рендер `htmlBody` (обычно присутствует) |
| `noreply@taxcom.ru` | по организации из тела (до ИНН) | ФП/ФН/ФД regex из `htmlBody` | URL `https://receipt.taxcom.ru/v01/show?fp=<ФП>&fn=<ФН>&fd=<ФД>` → Chrome напрямую (редирект на GUID нормален) |
| `invoice+statements@mail.anthropic.com` | `Anthropic` | ID = номер чека из subject: `#([\d-]+)` | `plaintextBody` → обёртка HTML (см. ниже) → Chrome |
| `noreply@ofd.ru` | по организации из тела (до ИНН) | ФПД + RawId из `htmlBody` | **Chrome НЕ нужен:** `Invoke-WebRequest` `https://ofd.ru/Document/RenderDoc?RawId=<GUID>&format=pdf` |
| `no-reply@ofd.yandex.ru` | по организации из тела | vaucher-ссылка из тела | `https://ofd.yandex.ru/vaucher/<ФН>/<ФД>/<ФПД>` → Chrome напрямую |

## Детали по провайдерам

### Магнит (`info@ofd-magnit.ru`)
- Тело ~100–130 КБ HTML — часто превышает лимит токенов MCP и авто-сохраняется в
  `…\tool-results\…get_thread…txt`. Извлекай `htmlBody` через
  `scripts/extract_html_body.py`, не втягивая в контекст.
- ФПД в теле: `ФП\s+(\d{6,10})`. Совпадает с номером в subject «Чек N …», но
  каноничный источник — тело.
- Организация: АО «ТАНДЕР», ИНН 2310031475. cid-картинки (лого, QR) не грузятся —
  это норма для PDF.

### Билайн (`ofdreceipt@beeline.ru`)
- Рендер `htmlBody`. ФПД — `ФП`/`ФПД`. Организация в subject может меняться —
  но папка всегда `Билайн_ОФД`.

### Яндекс.Маркет (`noreply@check.yandex.ru`)
- Ссылка в snippet/теле: `https://check.yandex.ru/?n=<ФД>&fn=<ФН>&fpd=<ФПД>`.
  ФПД видно уже в snippet — тело для идемпотентности часто не нужно.
- ⚠ Subject «Чек + (1) подарок 💌 🎁» ИДЕНТИЧЕН `no-reply@ofd.yandex.ru`
  (Яндекс.Доставка). Различай по адресу отправителя, не по subject.

### 1-ОФД (`echeck@1-ofd.ru`)
- Папка по ИНН из тела (маппинг в `configuration.md`), иначе §4 по организации.
- ФПД — `ФП <digits>` в `htmlBody`. Рендер `htmlBody` как HTML-файла.

### Такском (`noreply@taxcom.ru`)
- `get_thread` возвращает `htmlBody` со всеми полями (ИНН, ФН, ФД, ФП) — raw MIME
  не нужен. Строй URL `https://receipt.taxcom.ru/v01/show?fp=<ФП>&fn=<ФН>&fd=<ФД>`
  → Chrome напрямую. Chrome MCP / Gmail UI не использовать — нестабильно.
- Папка — по организации до ИНН (ведите свою таблицу в `configuration.md`).

### Anthropic (`invoice+statements@mail.anthropic.com`)
- Gmail MCP отдаёт `plaintextBody`. ID = номер чека из subject `#([\d-]+)`
  (напр. `2067-2022-6800`). Дата = «Paid <Month Day, Year>» из тела → YYYY-MM-DD.
- Ссылки Stripe требуют аутентификации — НЕ использовать. Рендер: оберни
  `plaintextBody` в HTML (экранируй `<`, `>`, `&`):

```html
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
body{font-family:'Courier New',monospace;font-size:11pt;max-width:600px;margin:20px auto;padding:16px}
pre{white-space:pre-wrap;word-wrap:break-word}
</style></head><body><pre>{{body_text}}</pre></body></html>
```

### OFD.ru (`noreply@ofd.ru`)
- ФПД/RawId — из `htmlBody` (>лимита токенов → авто-файл, парсить скриптом).
- **PDF напрямую** (публичный, без авторизации, ~200 КБ, валидный `%PDF-`):
  `https://ofd.ru/Document/RenderDoc?RawId=<GUID>&format=pdf` — Chrome не нужен.
- RawId: `RenderDoc\?RawId=([0-9a-fA-F-]{36})`. ФПД: `(?:ФПД|ФП)[:\s№]+(\d{6,10})`.
- ⚠ **ОДНА Gmail-нить = НЕСКОЛЬКО разных чеков** (разные ФПД/ФН/RawId) —
  обрабатывай КАЖДОЕ сообщение нити отдельно.

### Яндекс.Доставка (`no-reply@ofd.yandex.ru`)
- Папка по организации из тела (ведите свою таблицу в `configuration.md`).
- vaucher-ссылка (href) из тела: `https://ofd.yandex.ru/vaucher/<ФН>/<ФД>/<ФПД>`
  → Chrome напрямую.
- ⚠ Subject идентичен `check.yandex.ru` — папку бери по организации из тела.
