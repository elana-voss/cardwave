"""Every English text of the UI as one table, for a usability review (milestone 129 of docs/cardwave-rewrite.md).

  python tools/words.py [OUT]     writes OUT (default .checklists/ux/words.md) and prints a few counts

Reads web/src/language/en*.ftl. A row per key, and per attribute (`key.title`): the key, its screen (the
file and its `##` heading), its text with the lines of a select joined by spaces, and marks. It judges
nothing; it marks only: `duplicate (n)` where n keys have the very same text, `delete-remove-discard`,
`card-character` and `model-ai` where the text holds one of those words (the pairs a reader weighs for
"One thing, one name"). Its test: tools/words_test.py.
"""

import collections
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGUAGE = ROOT / "web" / "src" / "language"
OUT = ROOT / ".checklists" / "ux" / "words.md"

KEY = re.compile(r"^([A-Za-z][\w-]*)\s*=\s?(.*)$")
ATTRIBUTE = re.compile(r"^\s+\.([\w-]+)\s*=\s?(.*)$")
MARKS = [
    ("delete-remove-discard", re.compile(r"\b(delet|remov|discard)(e|es|ed|ing|s)?\b", re.I)),
    ("card-character", re.compile(r"\b(cards?|characters?)\b", re.I)),
    ("model-ai", re.compile(r"\b(models?|the AI)\b", re.I)),
]


def entries(text: str, file: str) -> list[dict]:
    """The rows of one .ftl file's text: key, screen, text."""
    rows: list[dict] = []
    heading = ""
    for line in text.splitlines():
        if line.startswith("###") or (line.startswith("#") and not line.startswith("##")):
            continue
        if line.startswith("##"):
            heading = line.lstrip("#").strip()
            continue
        if not line.strip():
            continue
        key, attribute = KEY.match(line), ATTRIBUTE.match(line)
        if key:
            rows.append({"key": key[1], "screen": f"{file}: {heading}", "text": key[2].strip()})
        elif attribute and rows:
            base = rows[-1]["key"].split(".")[0]
            rows.append({"key": f"{base}.{attribute[1]}", "screen": rows[-1]["screen"], "text": attribute[2].strip()})
        elif rows:
            rows[-1]["text"] = f"{rows[-1]['text']} {line.strip()}".strip()
    return rows


def marks(text: str) -> list[str]:
    """The names of the word pairs `text` holds a word of."""
    return [name for name, pattern in MARKS if pattern.search(text)]


def table(rows: list[dict]) -> str:
    """The Markdown table of `rows`, with their marks, then the groups of exact duplicates."""
    counts = collections.Counter(r["text"] for r in rows if r["text"])
    lines = ["| key | screen | text | marks |", "|---|---|---|---|"]
    for r in rows:
        found = ([f"duplicate ({counts[r['text']]})"] if counts[r["text"]] > 1 else []) + marks(r["text"])
        cell = r["text"].replace("|", "\\|")
        lines.append(f"| {r['key']} | {r['screen']} | {cell} | {'; '.join(found)} |")
    lines += ["", "## Exact duplicates", ""]
    for text, n in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        if n > 1:
            keys = ", ".join(r["key"] for r in rows if r["text"] == text)
            lines.append(f"- {text.replace('|', '\\|')} ({n}): {keys}")
    return "\n".join(lines) + "\n"


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    rows: list[dict] = []
    for path in sorted(LANGUAGE.glob("en*.ftl")):
        rows += entries(path.read_text(encoding="utf-8"), path.name)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(f"# The English words, {len(rows)} rows\n\n" + table(rows), encoding="utf-8")
    counts = collections.Counter(r["text"] for r in rows)
    print(f"{len(rows)} rows ({sum('.' not in r['key'] for r in rows)} keys) -> {out}")
    print(f"exact duplicates: {sum(1 for n in counts.values() if n > 1)} texts in {sum(n for n in counts.values() if n > 1)} rows")
    for name, _ in MARKS:
        print(f"{name}: {sum(name in marks(r['text']) for r in rows)} rows")


if __name__ == "__main__":
    main()
