"""Adds a `[many]` variant to each plural select of a language's .ftl files that lacks one.

Spanish, Portuguese, Italian and French have CLDR's plural form "many" (a million and up: "1 000 000 de
elementos"), which the structure test (web/src/language/structure.test.ts) asks of every plural select. A
select counts as plural when it has a `[one]` variant; its `[many]` is a copy of its `*[other]` line, put
before it; nested selects each get their own. Only one-line `*[other]` variants are copied; a longer one is printed for a hand edit.

Usage: python tools/plural_many.py web/src/language/es.ftl [more files]
"""

import re
import sys


def add_many(text: str) -> tuple[str, int, list[str]]:
    lines = text.split("\n")
    out: list[str] = []
    added, by_hand = 0, []
    selects: list[list[str]] = []  # the open selects, innermost last, each its variant names so far
    for line in lines:
        if not line.startswith(" "):
            selects = []
        variant = re.match(r"^\s*\*?\[([^\]]+)\]", line)
        if variant and selects:
            names = selects[-1]
            names.append(variant.group(1))
            if line.lstrip().startswith("*[other]") and "one" in names and "many" not in names:
                indent = line[: len(line) - len(line.lstrip())]
                body = line.lstrip()[len("*[other]"):]
                if body.strip():
                    out.append(f"{indent} [many]{body}")
                    added += 1
                else:
                    by_hand.append(line)
        elif line.lstrip().startswith("}") and selects:
            selects.pop()
        if line.rstrip().endswith("->"):
            selects.append([])
        out.append(line)
    return "\n".join(out), added, by_hand


def main() -> None:
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8", newline="") as f:
            text = f.read()
        new, added, by_hand = add_many(text)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(new)
        print(f"{path}: {added} [many] added" + (f"; by hand: {len(by_hand)}" if by_hand else ""))
        for line in by_hand:
            print("  " + line.strip())


if __name__ == "__main__":
    main()
