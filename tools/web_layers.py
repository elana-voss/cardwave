"""The layers of the web interface (milestone 96i of docs/cardwave-rewrite.md): which area of web/src imports which.

  python tools/web_layers.py           the check `webimports` (tools/check.sh): prints each import LAYERS
                                       forbids, by file and line, and fails on any
  python tools/web_layers.py --graph   each area's imports of other areas, with their count, cycles marked

An area is a folder of web/src; the files directly in it, `api/` and `language/` are the shared parts, which
every area may import and which import no area; `main.ts`, the app's start, is the top. LAYERS is the areas
bottom to top: an area imports only the shared parts, its own files and areas of a lower layer, so no two
areas use each other (two in one layer do not import each other). Tests count as their module's area. Read
are every relative path in a string ("../chat/title", vi.mock's too) of the .ts files.
"""

import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "web", "src")
LAYERS = [
    ["shared"],
    ["figures", "models", "interview"],
    ["voice"],
    ["library"],
    ["card"],
    ["lorebook"],
    ["chat"],
    ["settings", "setup"],
    ["companion"],
    ["shell"],
    ["views"],
    ["main"],
]
LEVEL = {area: n for n, areas in enumerate(LAYERS) for area in areas}
SPEC = re.compile(r"""(["'])(\.\.?/[^"'\n]*)\1""")


def area(rel):
    head, _, rest = rel.partition("/")
    if not rest:
        return "main" if rel in ("main.ts", "main") else "shared"
    return "shared" if head in ("api", "language") else head


def imports():
    """Each (file, line, specifier, from area, to area) between two areas."""
    for d, _, files in os.walk(SRC):
        for f in sorted(files):
            if not f.endswith(".ts"):
                continue
            rel = os.path.relpath(os.path.join(d, f), SRC).replace(os.sep, "/")
            with open(os.path.join(d, f), encoding="utf8") as text:
                for n, line in enumerate(text, 1):
                    for m in SPEC.finditer(line):
                        target = os.path.normpath(os.path.join(os.path.dirname(rel), m.group(2))).replace(os.sep, "/")
                        a, b = area(rel), area(target)
                        if a != b:
                            yield rel, n, m.group(2), a, b


def forbidden(a, b):
    return b != "shared" and (a not in LEVEL or b not in LEVEL or LEVEL[b] >= LEVEL[a])


def main(args):
    if args == ["--graph"]:
        edges = collections.Counter((a, b) for _, _, _, a, b in imports())
        for (a, b), count in sorted(edges.items()):
            print(f"{a} -> {b} {count}" + (" cycle" if (b, a) in edges else ""))
        return 0
    bad = [f"web/src/{rel}:{n}: {spec} ({a} -> {b})" for rel, n, spec, a, b in imports() if forbidden(a, b)]
    if bad:
        print("\n".join(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
