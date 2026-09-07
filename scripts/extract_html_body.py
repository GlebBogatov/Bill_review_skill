#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Извлечь htmlBody/plaintextBody из сохранённого JSON-результата get_thread.

Крупные тела (напр. Магнит ~100–130 КБ) get_thread авто-сохраняет в файл
`…\\tool-results\\…get_thread…txt`, когда результат превышает лимит токенов MCP.
Этот скрипт достаёт тело нужного сообщения БЕЗ втягивания в контекст модели и
пишет его в HTML-файл, готовый к рендеру headless Chrome.

Использование:
    python extract_html_body.py <thread_json> <out.html> [--index N] [--plain]
    python extract_html_body.py <thread_json> --fields-only [--index N]
    python extract_html_body.py <thread_json> --fields-only --all

  <thread_json>   путь к сохранённому JSON get_thread
  <out.html>      куда записать тело (не нужен при --fields-only)
  --index N       номер сообщения в нити (по умолчанию 0)
  --plain         взять plaintextBody (Anthropic) и обернуть в HTML-шаблон
  --fields-only   не писать HTML: напечатать в stdout JSON фискальных полей
                  (ФПД/ФН/ФД/ИНН/RawId/дата) выбранного сообщения
  --all           с --fields-only: обойти ВСЕ сообщения нити (важно для ofd.ru,
                  где одна нить = несколько разных чеков)

После записи HTML печатает в stderr найденные regex-поля для глазной сверки.
"""
import io
import re
import sys
import json
import html as _html

# Кириллица в путях/полях: не падать на cp1251-консолях Windows / в песочнице.
for _s in ("stdout", "stderr"):
    _f = getattr(sys, _s, None)
    if _f is not None and hasattr(_f, "reconfigure"):
        try:
            _f.reconfigure(encoding="utf-8")
        except Exception:
            pass

TEMPLATE = (
    "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><style>"
    "body{font-family:'Courier New',monospace;font-size:11pt;max-width:600px;"
    "margin:20px auto;padding:16px}pre{white-space:pre-wrap;word-wrap:break-word}"
    "</style></head><body><pre>{body}</pre></body></html>"
)


def fields(text):
    """Извлечь фискальные поля из тела (HTML или plaintext)."""
    plain = re.sub(r"<[^>]+>", " ", text)

    def g(pat, src=plain):
        m = re.search(pat, src)
        return m.group(1) if m else None

    return {
        "ФПД": g(r"(?:ФПД|ФП)[:\s№]+(\d{6,10})"),
        "ФН": g(r"(?:ФН|FN|№\s*ФН)[:\s№]+(\d{16})"),
        "ФД": g(r"(?:ФД|FD|№\s*ФД)[:\s№]+(\d+)"),
        "ИНН": g(r"ИНН[:\s№]*(\d{10,12})"),
        # RawId ищем в СЫРОМ теле (в href, не в тексте): GUID из ссылки RenderDoc.
        "RawId": g(r"RenderDoc\?RawId=([0-9a-fA-F-]{36})", text),
        "дата": g(r"(\d{2}\.\d{2}\.\d{4})"),
    }


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    fields_only = "--fields-only" in argv
    do_all = "--all" in argv
    plain = "--plain" in argv
    idx = 0
    if "--index" in argv:
        idx = int(argv[argv.index("--index") + 1])

    if not args or (not fields_only and len(args) < 2):
        sys.stderr.write(
            "usage: extract_html_body.py <thread_json> <out.html> "
            "[--index N] [--plain]\n"
            "       extract_html_body.py <thread_json> --fields-only "
            "[--index N] [--all]\n")
        return 2

    src = args[0]
    with open(src, encoding="utf-8") as fh:
        data = json.load(fh)
    messages = data["messages"]

    if fields_only:
        targets = range(len(messages)) if do_all else [idx]
        out = []
        for i in targets:
            m = messages[i]
            body = m.get("htmlBody") or m.get("plaintextBody") or ""
            rec = {"index": i, "id": m.get("id"), "date": m.get("date"),
                   "subject": m.get("subject")}
            rec.update(fields(body))
            out.append(rec)
        print(json.dumps(out if do_all else out[0], ensure_ascii=False, indent=2))
        return 0

    out = args[1]
    msg = messages[idx]
    if plain:
        body = TEMPLATE.replace("{body}", _html.escape(msg["plaintextBody"]))
    else:
        body = msg["htmlBody"]
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(body)

    sys.stderr.write(f"subject: {msg.get('subject')}\n")
    sys.stderr.write(f"date: {msg.get('date')}\n")
    sys.stderr.write(f"fields: {fields(body)}\n")
    sys.stderr.write(f"written {len(body)} chars -> {out}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
