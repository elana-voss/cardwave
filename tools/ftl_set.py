"""Sets or renames UI texts in every language at once (web/src/language/<code><part>.ftl).

  python tools/ftl_set.py DATA.json      applies DATA and prints one line per file changed

DATA is a list of steps:
  {"part": ".errors", "key": "error-x", "text": {"en": "...", "de": "...", ...}}  sets the message's value
      (all after `key = `, a select's lines joined by "\n") in each language named; every language of
      the part must be named, so none is left behind (the golden-file rule of CLAUDE.md).
  {"part": ..., "key": ..., "variant": "y", "text": {...}}  sets only the select's line `[y] ...`.
  {"rename": "old-key", "to": "new-key"}  renames a message's key in every file of every language.
  {"part": ..., "key": "new-key", "after": "old-key", "text": {...}}  adds a message after `old-key`'s.
  {"remove": "key"}  removes a message from every file of every language.
A message runs from its `key =` line to the line before the next message, comment or blank line. Each key
must occur once per file; a step that finds it otherwise stops before anything is written. Line ends kept.
Its test: tools/ftl_set_test.py.
"""

import json
import re
import sys
from pathlib import Path

LANGUAGE = Path(__file__).resolve().parent.parent / "web" / "src" / "language"
NEXT = re.compile(r"^(#|[A-Za-z][\w-]*\s*=|\s*$)")


def languages(folder: Path, part: str) -> list[str]:
    """The language codes having a file of `part` ("" for the main file)."""
    tail = f"{part}.ftl"
    codes = []
    for file in folder.glob(f"*{tail}"):
        code = file.name[: -len(tail)]
        if "." not in code:
            codes.append(code)
    return sorted(codes)


def span(lines: list[str], key: str) -> tuple[int, int]:
    """The first and past-last line of `key`'s message; it must occur once."""
    starts = [i for i, line in enumerate(lines) if re.match(rf"^{re.escape(key)}\s*=", line)]
    if len(starts) != 1:
        raise SystemExit(f"{key}: found {len(starts)} times")
    end = starts[0] + 1
    while end < len(lines) and not NEXT.match(lines[end]):
        end += 1
    return starts[0], end


def set_text(text: str, key: str, value: str, newline: str) -> str:
    lines = text.split(newline)
    first, end = span(lines, key)
    if "\t" in value or "\f" in value:
        raise SystemExit(f"{key}: a tab or form feed in its text")
    lines[first:end] = f"{key} = {value}".split("\n")
    return newline.join(lines)


def add_after(text: str, key: str, after: str, value: str, newline: str) -> str:
    lines = text.split(newline)
    if any(re.match(rf"^{re.escape(key)}\s*=", line) for line in lines):
        raise SystemExit(f"{key}: there already")
    _, end = span(lines, after)
    lines.insert(end, f"{key} = x")
    return set_text(newline.join(lines), key, value, newline)


def remove(text: str, key: str, newline: str) -> str:
    lines = text.split(newline)
    first, end = span(lines, key)
    del lines[first:end]
    return newline.join(lines)


def set_variant(text: str, key: str, variant: str, value: str, newline: str) -> str:
    lines = text.split(newline)
    first, end = span(lines, key)
    found = [i for i in range(first, end) if re.match(rf"^\s*\*?\[{re.escape(variant)}\] ", lines[i])]
    if len(found) != 1:
        raise SystemExit(f"{key} [{variant}]: found {len(found)} times")
    head = re.match(r"^\s*\*?\[[^\]]+\] ", lines[found[0]]).group(0)
    lines[found[0]] = head + value
    return newline.join(lines)


def rename(text: str, old: str, new: str, newline: str) -> str:
    lines = text.split(newline)
    first, _ = span(lines, old)
    lines[first] = re.sub(rf"^{re.escape(old)}", new, lines[first])
    return newline.join(lines)


def add_after(text: str, key: str, after: str, value: str, newline: str) -> str:
    lines = text.split(newline)
    if any(re.match(rf"^{re.escape(key)}\s*=", line) for line in lines):
        raise SystemExit(f"{key}: there already")
    _, end = span(lines, after)
    lines[end:end] = [f"{key} = PLACE"]
    return set_text(newline.join(lines), key, value, newline)


def files_with(folder: Path, key: str, read) -> list[Path]:
    """Every language file holding `key`; at least one."""
    files = [f for f in sorted(folder.glob("*.ftl")) if re.search(rf"^{re.escape(key)}\s*=", read(f), re.M)]
    if not files:
        raise SystemExit(f"{key}: in no file")
    return files


def apply(steps: list[dict], folder: Path = LANGUAGE) -> list[Path]:
    """Applies every step in memory, then writes the files changed."""
    texts: dict[Path, str] = {}

    def read(path: Path) -> str:
        if path not in texts:
            texts[path] = path.read_bytes().decode("utf-8")
        return texts[path]

    for step in steps:
        if "remove" in step:
            files = [f for f in sorted(folder.glob("*.ftl")) if re.search(rf"^{re.escape(step['remove'])}\s*=", read(f), re.M)]
            if not files:
                raise SystemExit(f"{step['remove']}: in no file")
            for path in files:
                nl = "\r\n" if "\r\n" in read(path) else "\n"
                texts[path] = remove(read(path), step["remove"], nl)
            continue
        if "rename" in step:
            for path in files_with(folder, step["rename"], read):
                nl = "\r\n" if "\r\n" in read(path) else "\n"
                texts[path] = rename(read(path), step["rename"], step["to"], nl)
            continue
        codes = languages(folder, step["part"])
        if sorted(step["text"]) != codes:
            raise SystemExit(f"{step['key']}: languages {sorted(step['text'])}, files {codes}")
        for code in codes:
            path = folder / f"{code}{step['part']}.ftl"
            nl = "\r\n" if "\r\n" in read(path) else "\n"
            if "after" in step:
                texts[path] = add_after(read(path), step["key"], step["after"], step["text"][code], nl)
            elif "variant" in step:
                texts[path] = set_variant(read(path), step["key"], step["variant"], step["text"][code], nl)
            else:
                texts[path] = set_text(read(path), step["key"], step["text"][code], nl)
    changed = [p for p, t in texts.items() if p.read_bytes().decode("utf-8") != t]
    for path in changed:
        path.write_bytes(texts[path].encode("utf-8"))
    return changed


if __name__ == "__main__":
    for path in apply(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))):
        print(path.name)
