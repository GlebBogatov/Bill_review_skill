#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Собрать множество уже сохранённых ID чеков из архива за год.

Источник истины идемпотентности — файлы на диске. Скрипт рекурсивно обходит
папку года и вытаскивает <ID> из имён `Чек_YYYY-MM-DD_<ID>.pdf`
(<ID> — ФПД цифрами или иностранный номер вида 2067-2022-6800).

Использование:
    python collect_saved_ids.py "<АРХИВ>\\<год>" [--json]

Без --json печатает по одному ID в строку (плюс итоговый count в stderr),
что удобно для быстрой глазной сверки. С --json печатает {id: [[папка, дата], ...]}.
"""
import os
import re
import sys
import json

# Кириллица в путях/выводе: не падать на cp1251-консолях Windows / в песочнице.
for _s in ("stdout", "stderr"):
    _f = getattr(sys, _s, None)
    if _f is not None and hasattr(_f, "reconfigure"):
        try:
            _f.reconfigure(encoding="utf-8")
        except Exception:
            pass

# ФПД (цифры) либо иностранный ID с дефисами.
PAT = re.compile(r"Чек_(\d{4}-\d{2}-\d{2})_([\d]+(?:-\d+)*)\.pdf$")


def collect(root):
    ids = {}
    for dirpath, _dirs, files in os.walk(root):
        folder = os.path.basename(dirpath)
        for f in files:
            m = PAT.search(f)
            if m:
                ids.setdefault(m.group(2), []).append([folder, m.group(1)])
    return ids


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: collect_saved_ids.py <year_dir> [--json]\n")
        return 2
    root = argv[1]
    as_json = "--json" in argv[2:]
    if not os.path.isdir(root):
        sys.stderr.write(f"not a directory: {root}\n")
        return 1
    ids = collect(root)
    if as_json:
        print(json.dumps(ids, ensure_ascii=False))
    else:
        for k in sorted(ids):
            print(k)
    sys.stderr.write(f"total unique ids: {len(ids)}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
