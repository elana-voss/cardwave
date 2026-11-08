"""Moves modules of web/src (milestone 96i of docs/cardwave-rewrite.md) and rewrites every path that names them.

  python tools/web_move.py OLD NEW [OLD NEW …]   paths below web/src, with .ts (chat/title.ts title.ts)

Each OLD goes to NEW by `git mv`, its test (`.test.ts` beside it) too. Then, in every .ts file of web/src, each
relative import ("../chat/title", also vi.mock's) that names a moved module, or that a moved file makes from its
new place, is written for where both are now; and each mention of a moved file's path in web/src (its .ftl too), e2e and
tools/check.sh (`chat/title.ts`, `web/src/chat/title.ts`, `../chat/title.ts`) is renamed. Prints the files it changed. Line ends are kept.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "web", "src")
SPEC = re.compile(r"""(["'])(\.\.?/[^"'\n]*)\1""")


def norm(path):
    return os.path.normpath(path).replace(os.sep, "/")


def module(rel_file, spec):
    """The module (below web/src, without .ts) a relative specifier in rel_file names."""
    target = norm(os.path.join(os.path.dirname(rel_file), spec))
    return target[:-3] if target.endswith(".ts") else target


def specifier(rel_file, target):
    out = norm(os.path.relpath(target, os.path.dirname(rel_file) or "."))
    return out if out.startswith(".") else "./" + out


def ts_files():
    for d, _, files in os.walk(SRC):
        for f in files:
            if f.endswith(".ts"):
                yield norm(os.path.relpath(os.path.join(d, f), SRC))


def main(args):
    if not args or len(args) % 2:
        sys.exit(__doc__)
    moves = {}
    for old, new in zip(args[::2], args[1::2]):
        moves[old[:-3]] = new[:-3]
        if os.path.exists(os.path.join(SRC, old[:-3] + ".test.ts")):
            moves[old[:-3] + ".test"] = new[:-3] + ".test"
    for old, new in moves.items():
        subprocess.run(["git", "mv", f"web/src/{old}.ts", f"web/src/{new}.ts"], cwd=ROOT, check=True)
    back = {new: old for old, new in moves.items()}
    mentions = [(re.compile(r"(?<![\w./-])((?:web/src/|\.\./|\./)?)" + re.escape(old) + r"\.ts\b"), new) for old, new in moves.items()]
    changed = []
    files = [os.path.join("web", "src", f) for f in ts_files()]
    files += [os.path.join("web", "src", "language", f) for f in os.listdir(os.path.join(SRC, "language")) if f.endswith(".ftl")]
    files += [os.path.join("e2e", d, f) for d in ("", "tests") for f in os.listdir(os.path.join(ROOT, "e2e", d)) if f.endswith(".ts")]
    files.append(os.path.join("tools", "check.sh"))
    for path in files:
        full = os.path.join(ROOT, path)
        with open(full, encoding="utf8", newline="") as f:
            text = f.read()
        out = text
        rel = norm(path)[len("web/src/"):] if norm(path).startswith("web/src/") else None
        if rel is not None:
            was = back.get(rel[:-3], rel[:-3]) + ".ts"

            def fix(m):
                target = module(was, m.group(2))
                if target not in moves and rel == was:
                    return m.group(0)
                target = moves.get(target, target)
                if not os.path.exists(os.path.join(SRC, target + ".ts")) and not os.path.exists(os.path.join(SRC, target)):
                    return m.group(0)
                return m.group(1) + specifier(rel, target) + m.group(1)

            out = SPEC.sub(fix, out)
        for pattern, new in mentions:
            out = pattern.sub(lambda m: m.group(1) + new + ".ts", out)
        if out != text:
            with open(full, "w", encoding="utf8", newline="") as f:
                f.write(out)
            changed.append(norm(path))
    print("\n".join(changed))


if __name__ == "__main__":
    main(sys.argv[1:])
