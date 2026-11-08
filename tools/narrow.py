"""A crate's interface (milestone 96): its `pub` items, and `pub` narrowed where no other crate needs it.

  python tools/narrow.py --list CRATE   each `pub` item of crates/CRATE (file:line and the line), then the count
  python tools/narrow.py --count        the count of `pub` items of each crate, server's included
  python tools/narrow.py --unused CRATE each `pub` item of crates/CRATE whose name no file outside it names, nor
                                        a used item's signature or fields shows
  python tools/narrow.py CRATE          makes `pub(crate)` each `pub` item of crates/CRATE whose name no file
                                        outside it names; the compiler then tells what was still needed
                                        (a private type in a public signature) and what is dead

An item is a line that begins with `pub ` (a function, type, field, method, constant, module, re-export).
A name counts as used where it is written as a word in another crate's code or in any crate's `tests/`
(an integration test is a crate of its own), strings and comments left out, so a common name (`new`)
stays `pub`: the narrowing is safe, not complete.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from rust_paths import blank  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ITEM = re.compile(r"(?m)^([ \t]*)pub (?:(?:async|unsafe|const|extern \"C\")\s+)*(?:(fn|struct|enum|const|static|type|trait|mod|use|union)\b)?\s*(?:mut\s+)?([A-Za-z_]\w*)?")


def crate_sources(folder: Path):
    return sorted(p for p in (folder / "src").rglob("*.rs") if "generated" not in p.parts)


def crates():
    out = {"cardwave-server": ROOT / "server"}
    out.update({p.name: p for p in sorted((ROOT / "crates").glob("*")) if (p / "Cargo.toml").exists()})
    return out


def items(folder: Path):
    """Each `pub` item: (file, line number, its name, the line)."""
    for path in crate_sources(folder):
        text = path.read_text(encoding="utf-8")
        code = blank(text)
        lines = text.splitlines()
        for m in ITEM.finditer(code):
            line = code.count("\n", 0, m.start())
            name = m.group(3)
            if m.group(2) == "use":
                name = re.findall(r"(\w+)\s*[;}]?\s*$", lines[line].rstrip(";"))[-1:] or [None]
                name = name[0]
            yield path, line + 1, name, lines[line].strip(), exposed(code, m.end(), m.group(2))


def exposed(code: str, at: int, kind):
    """The words an item shows to its users: a fn's signature, a type's body, a field's or const's type
    (a name before `:`, a field's or parameter's, is left out by `interface`)."""
    if kind in ("struct", "enum", "trait", "union", "type"):
        end, depth = at, 0
        while end < len(code):
            c = code[end]
            if c in "{(":
                depth += 1
            elif c in "})":
                depth -= 1
                if depth == 0:
                    break
            elif c == ";" and depth == 0:
                break
            end += 1
        return code[at:end]
    stop = {"fn": "{;", "const": "=;", "static": "=;"}.get(kind, ",;\n{")
    end = at
    while end < len(code) and code[end] not in stop:
        end += 1
    return code[at:end]


def words_outside(folder: Path):
    """Every word written outside the crate, and the names written before `{` there (a struct built by
    a literal, which needs every field visible, `..Default::default()` included)."""
    words, built = set(), set()
    others = [ROOT / "server" / "src", ROOT / "server" / "tests", ROOT / "desktop" / "src"]
    others += [p / "src" for p in (ROOT / "crates").glob("*")]
    others += [p / "tests" for p in (ROOT / "crates").glob("*")]
    for other in others:
        if not other.exists():
            continue
        for path in other.rglob("*.rs"):
            if other == folder / "src" and path != other / "main.rs":  # the binary is a crate of its own
                continue
            code = blank(path.read_text(encoding="utf-8"))
            words |= set(re.findall(r"\w+", code))
            built |= set(re.findall(r"(\w+)\s*\{", code))
    return words, built


def interface(folder: Path) -> set[str]:
    """The names other crates use, and what those items show: a type in a used fn's signature or a used
    type's fields is part of the interface though no other crate writes its name."""
    used, built = words_outside(folder)
    found = list(items(folder))
    while True:
        more = set()
        for _p, _l, name, _t, shown in found:
            if name in built:
                more |= set(re.findall(r"\w+", shown)) - used
            elif name in used:
                more |= set(re.findall(r"\w+", re.sub(r"\b\w+\s*:(?!:)", " ", shown))) - used
        if not more:
            return used
        used |= more


def main(args):
    if args[:1] == ["--count"]:
        for name, folder in crates().items():
            print(f"pub items {name}: {sum(1 for _ in items(folder))}")
    elif args[:1] == ["--list"]:
        found = list(items(crates()[args[1]]))
        for path, line, _name, text, _shown in found:
            print(f"{path.relative_to(ROOT).as_posix()}:{line} {text}")
        print(f"{len(found)} pub items")
    elif args[:1] == ["--unused"]:
        folder = crates()[args[1]]
        used = interface(folder)
        found = [(p, n, t) for p, n, name, t, _s in items(folder) if name and name not in used]
        for path, line, text in found:
            print(f"{path.relative_to(ROOT).as_posix()}:{line} {text}")
        print(f"{len(found)} pub items no other crate names")
    else:
        folder = crates()[args[0]]
        used = interface(folder)
        by_file = {}
        for path, line, name, _text, _shown in items(folder):
            if name and name not in used:
                by_file.setdefault(path, []).append(line)
        for path, lines in by_file.items():
            text = path.read_text(encoding="utf-8").split("\n")
            for line in lines:
                text[line - 1] = re.sub(r"\bpub ", "pub(crate) ", text[line - 1], count=1)
            path.write_text("\n".join(text), encoding="utf-8", newline="")
            print(f"{path.relative_to(ROOT).as_posix()}: {len(lines)} narrowed")


if __name__ == "__main__":
    main(sys.argv[1:])
