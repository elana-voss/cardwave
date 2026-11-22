"""The layers of the web interface (milestone 96i (its ticket in docs/tickets/)): which area of web/src imports which.

  python tools/web_layers.py           the check `webimports` (tools/check.sh): prints each import LAYERS
                                       or WRAPPED forbids, by file and line, and fails on any
  python tools/web_layers.py --graph   each area's imports of other areas, with their count, cycles marked

An area is a folder of web/src; the files directly in it, `api/` and `language/` are the shared parts, which
every area may import and which import no area; `main.ts`, the app's start, is the top. LAYERS is the areas
bottom to top: an area imports only the shared parts, its own files and areas of a lower layer, so no two
areas use each other (two in one layer do not import each other). Tests count as their module's area. Read
are every relative path in a string ("../chat/title", vi.mock's too) of the .ts files.

A library in WRAPPED is named (imported, its types too) only in the area that wraps it and in the files of
REMAINDER, which still name it; tests may name it to build what they feed their module (a three.js scene).
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
# Each library and the area that wraps it.
WRAPPED = {"three": "figures", "@pixiv/three-vrm": "figures"}
# The files outside its area that still name a wrapped library (the audit by Fable over 167-171, finding 3).
REMAINDER = {"companion/figure.ts", "companion/clips.ts", "companion/ground.ts"}
LIBRARY = re.compile(r"""(?:\bfrom\s*|\bimport\s*\(?\s*)(["'])((?:@[^/"'\n]+/)?[^./"'\n][^/"'\n]*)(?:/[^"'\n]*)?\1""")
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


def library_uses():
    """Each (file, line, library) where a product file outside the wrapping area names a wrapped library."""
    for d, _, files in os.walk(SRC):
        for f in sorted(files):
            rel = os.path.relpath(os.path.join(d, f), SRC).replace(os.sep, "/")
            if not f.endswith(".ts") or ".test" in f or rel in REMAINDER:
                continue
            with open(os.path.join(d, f), encoding="utf8") as text:
                for n, line in enumerate(text, 1):
                    for m in LIBRARY.finditer(line):
                        lib = m.group(2)
                        if lib in WRAPPED and area(rel) != WRAPPED[lib]:
                            yield rel, n, lib


def forbidden(a, b):
    return b != "shared" and (a not in LEVEL or b not in LEVEL or LEVEL[b] >= LEVEL[a])


def main(args):
    if args == ["--graph"]:
        edges = collections.Counter((a, b) for _, _, _, a, b in imports())
        for (a, b), count in sorted(edges.items()):
            print(f"{a} -> {b} {count}" + (" cycle" if (b, a) in edges else ""))
        return 0
    bad = [f"web/src/{rel}:{n}: {spec} ({a} -> {b})" for rel, n, spec, a, b in imports() if forbidden(a, b)]
    bad += [f"web/src/{rel}:{n}: {lib} (only {WRAPPED[lib]}/ names it)" for rel, n, lib in library_uses()]
    if bad:
        print("\n".join(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
