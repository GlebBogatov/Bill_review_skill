#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Извлечь htmlBody/plaintextBody из сохранённого JSON-результата get_thread.

Крупные тела (напр. Магнит ~100–130 КБ) get_thread авто-сохраняет в файл
`…\\tool-results\\…get_thread…txt`, когда результат превышает лимит токенов MCP.
Этот скрипт достаёт тело нужного сообщения БЕЗ втягивания в контекст модели и
пишет его в HTML-файл, готовый к рендеру headless Chrome.

Использование:
    python extract_html_body.py <thread_json> <out.html> [--index N] [--plain]

  <thread_json>  путь к сохранённому JSON get_thread
  <out.html>     куда записать тело
  --index N      номер сообщения в нити (по умолчанию 0)
  --plain        взять plaintextBody (Anthropic) и обернуть в HTML-шаблон

После записи печатает в stderr найденные regex-поля (ФПД/ФН/ФД/дата) для сверки.
"""
import re
import sys
import json
import html as _html

TEMPLATE = (
    "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><style>"
    "body{font-family:'Courier New',monospace;font-size:11pt;max-width:600px;"
    "margin:20px auto;padding:16px}pre{white-space:pre-wrap;word-wrap:break-word}"
    "</style></head><body><pre>{body}</pre></body></html>"
)


def fields(text):
    plain = re.sub(r"<[^>]+>", " ", text)
    def g(pat):
        m = re.search(pat, plain)
        return m.group(1) if m else None
    return {
        "ФПД": g(r"(?:ФПД|ФП)[:\s№]+(\d{6,10})"),
        "ФН": g(r"(?:ФН|FN|№\s*ФН)[:\s№]+(\d{16})"),
        "ФД": g(r"(?:ФД|FD|№\s*ФД)[:\s№]+(\d+)"),
        "дата": g(r"(\d{2}\.\d{2}\.\d{4})"),
    }


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    if len(args) < 2:
        sys.stderr.write(
            "usage: extract_html_body.py <thread_json> <out.html> "
            "[--index N] [--plain]\n")
        return 2
    src, out = args[0], args[1]
    idx = 0
    if "--index" in argv:
        idx = int(argv[argv.index("--index") + 1])
    plain = "--plain" in argv

    with open(src, encoding="utf-8") as fh:
        data = json.load(fh)
    msg = data["messages"][idx]
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
