"""The Rust paths of a source file, for tools/deps.py and tools/crate_move.py: its `use` trees, the
paths written in its code (`crate::a::B`, `super::C`, `db::lock` after `use crate::db` or `mod db;`), each resolved
to the module it names from the file's place, and a rewrite of them by a map of old paths to new.

A file's module is told by its place: `server/src/api/errors.rs` is `api::errors` of `server`,
`crates/cw-core/src/fail.rs` is `fail` of cw-core; a `use` or path inside an inline `mod x { }` is in
`…::x`. Strings, chars and comments are skipped when paths are found. Traps: a macro's own syntax is
read as code; a glob `use a::*` is kept as it is, a rewrite never splits it.
"""

import re
from pathlib import Path

WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def blank(text: str) -> str:
    """`text` with every string, char and comment turned into spaces, its lines and offsets kept."""
    out = list(text)
    i, n = 0, len(text)

    def wipe(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            wipe(i, j)
            i = j
        elif text.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if text.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif text.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            wipe(i, j)
            i = j
        elif (m := re.compile(r'b?r(#*)"').match(text, i)) and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_")):
            end = '"' + m.group(1)
            j = text.find(end, m.end())
            j = n if j < 0 else j + len(end)
            wipe(i + 1, j)
            i = j
        elif c == '"' or (c == "b" and text.startswith('b"', i) and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_"))):
            j = i + (2 if c == "b" else 1)
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            wipe(i + 1, j)
            i = j + 1
        elif c == "'":
            m = re.compile(r"'(\\(x[0-9a-fA-F]{2}|u\{[0-9a-fA-F]+\}|.)|[^\\'])'").match(text, i)
            if m:
                wipe(i + 1, m.end() - 1)
                i = m.end()
            else:
                i += 1  # a lifetime
        else:
            i += 1
    return "".join(out)


def module_of(path: Path, src: Path) -> list[str]:
    """The module path of the file `path` in the source folder `src` (`lib.rs`, `main.rs` are the root)."""
    parts = list(path.relative_to(src).with_suffix("").parts)
    if parts and parts[-1] in ("lib", "main", "mod"):
        parts.pop()
    return parts


def inline_mods(code: str) -> list[tuple[int, int, str]]:
    """The spans of the inline `mod x { … }` in blanked `code`, outermost first."""
    spans = []
    for m in re.finditer(r"\bmod\s+([A-Za-z_]\w*)\s*\{", code):
        depth, j = 1, m.end()
        while j < len(code) and depth:
            depth += {"{": 1, "}": -1}.get(code[j], 0)
            j += 1
        spans.append((m.start(), j, m.group(1)))
    return spans


def scope_at(base: list[str], spans, pos: int) -> list[str]:
    return base + [name for a, b, name in spans if a < pos < b]


# ---- use trees ---------------------------------------------------------------------------------

USE = re.compile(r"(?m)^([ \t]*)((?:pub(?:\([^)]*\))?\s+)?)use\s+")


def find_uses(code: str):
    """Each `use …;` of blanked `code`: (start, end, indent, visibility, tree text)."""
    for m in USE.finditer(code):
        j = code.find(";", m.end())
        yield m.start(), j + 1, m.group(1), m.group(2), code[m.end():j]


def parse_tree(text: str) -> list[tuple[list[str], str | None]]:
    """The leaves of a use tree: (path segments, alias); `self` in braces is the prefix, `*` a segment."""
    tokens = re.findall(r"::|[{},*]|\bas\b|[A-Za-z_]\w*", text)
    pos = 0

    def tree(prefix):
        nonlocal pos
        leaves, segs = [], list(prefix)
        while pos < len(tokens):
            t = tokens[pos]
            if t == "{":
                pos += 1
                while tokens[pos] != "}":
                    leaves += tree(segs)
                    if tokens[pos] == ",":
                        pos += 1
                pos += 1
                return leaves
            if t in (",", "}"):
                break
            if t == "::":
                pos += 1
                continue
            if t == "as":
                leaves.append((segs, tokens[pos + 1]))
                pos += 2
                return leaves
            if t == "self" and len(segs) == len(prefix) and prefix:
                pos += 1
                continue  # `{self}`: the prefix itself
            segs = segs + [t]
            pos += 1
        leaves.append((segs, None))
        return leaves

    return tree([])


def render_tree(leaves) -> str:
    """One use tree for `leaves` that share their first segment, nested by common prefix."""
    def text(items, depth):
        if len(items) == 1 and len(items[0][0]) == depth + 1:
            segs, alias = items[0]
            return segs[depth] + (f" as {alias}" if alias else "")
        groups: dict[str, list] = {}
        selfs = []
        for segs, alias in items:
            if len(segs) == depth:
                selfs.append(alias)
            else:
                groups.setdefault(segs[depth], []).append((segs, alias))
        parts = [("self" if a is None else f"self as {a}") for a in selfs]
        for name, sub in groups.items():
            if len(sub) == 1 and len(sub[0][0]) == depth + 1:
                parts.append(text(sub, depth))
            else:
                parts.append(f"{name}::{text(sub, depth + 1)}")
        return parts[0] if len(parts) == 1 else "{" + ", ".join(parts) + "}"

    return text(leaves, 0)


def child_mods(code: str, scope: list[str], spans, krate: str) -> dict[tuple, dict[str, list[str]]]:
    """The modules a file declares (`mod x;`, `mod x { }`), by the scope they are declared in: a bare
    `x::Y` there names `[krate, …scope, x, Y]` (`dictation::Setup` in lib.rs)."""
    out: dict[tuple, dict[str, list[str]]] = {}
    for m in re.finditer(r"\bmod\s+([A-Za-z_]\w*)\s*[;{]", code):
        here = scope_at(scope, spans, m.start())
        out.setdefault(tuple(here), {})[m.group(1)] = [krate] + here + [m.group(1)]
    return out


def resolve(segs: list[str], scope: list[str], krate: str) -> list[str] | None:
    """`segs` as an absolute path `[crate name, …]`, or None for a name not of a crate path."""
    if not segs:
        return None
    if segs[0] == "crate":
        return [krate] + segs[1:]
    if segs[0] in ("super", "self"):
        at = list(scope)
        i = 0
        while i < len(segs) and segs[i] in ("super", "self"):
            if segs[i] == "super":
                if not at:
                    return None
                at.pop()
            i += 1
        return [krate] + at + segs[i:]
    return None


def relative(path: list[str], krate: str) -> list[str]:
    """An absolute path written from inside `krate`: its own crate is `crate`."""
    return ["crate"] + path[1:] if path[0] == krate else path


# ---- rewriting -----------------------------------------------------------------------------------

def mapped(path: list[str], moves: list[tuple[list[str], list[str]]]) -> list[str] | None:
    """`path` after the longest move that is a prefix of it, or None."""
    best = None
    for old, new in moves:
        if path[: len(old)] == old and (best is None or len(old) > len(best[0])):
            best = (old, new)
    return None if best is None else best[1] + path[len(best[0]):]


def rewrite(text: str, scope: list[str], krate: str, moves, crate_names: set[str], home: str | None = None):
    """`text` with its use trees and written paths moved by `moves` (absolute old → absolute new paths,
    `[crate, …]`), read as a file of `krate` and written as one of `home` (where it moves to); returns
    the text and the absolute paths it names outside `krate`."""
    home = home or krate
    code = blank(text)
    spans = inline_mods(code)
    edits = []  # (start, end, new text)
    mods = child_mods(code, scope, spans, krate)  # a bare path through a declared module is rewritten
    aliases = {k: dict(v) for k, v in mods.items()}  # names a use or `mod` brings in, by its scope
    named = []

    def alias_scope(pos):
        return tuple(scope_at(scope, spans, pos))

    for start, end, indent, vis, tree in find_uses(code):
        here = scope_at(scope, spans, start)
        leaves = parse_tree(tree)
        out, changed = [], False
        for segs, alias in leaves:
            path = resolve(segs, here, krate)
            if path is None and segs and segs[0] in crate_names:
                path = segs
            new = mapped(path, moves) if path else None
            if new is not None and segs[-1] != "*":
                changed = True
                segs2 = relative(new, home)
                if alias is None and segs2[-1] != segs[-1] and segs[-1] != "self":
                    alias = segs[-1]  # keeps the name the file uses
                out.append((segs2, alias))
                full = new
            else:
                out.append((segs, alias))
                full = path
            if full is not None:
                name = alias or (full[-1] if full[-1] != "*" else None)
                if name:
                    aliases.setdefault(tuple(here), {})[name] = full
                if full[0] != krate:
                    named.append(full)
        if changed:
            by_root: dict[str, list] = {}
            for segs, alias in out:
                by_root.setdefault(segs[0], []).append((segs, alias))
            stmts = [f"{indent}{vis}use {render_tree(group)};" for group in by_root.values()]
            edits.append((start, end, "\n".join(stmts)))

    # paths written in code
    use_spans = [(a, b) for a, b, *_ in find_uses(code)]
    for m in re.finditer(r"(?<![\w:])((?:[A-Za-z_]\w*::)+[A-Za-z_]\w*)", code):
        if any(a <= m.start() < b for a, b in use_spans):
            continue
        segs = m.group(1).split("::")
        here = scope_at(scope, spans, m.start())
        path = resolve(segs, here, krate)
        by_alias = False
        if path is None:
            for depth in range(len(here), -1, -1):
                known = aliases.get(tuple(here[:depth]), {})
                if segs[0] in known:
                    path = known[segs[0]] + segs[1:]
                    by_alias = known[segs[0]] != mods.get(tuple(here[:depth]), {}).get(segs[0])
                    break
        if path is None and segs[0] in crate_names:
            path = segs
        if path is None:
            continue
        # A name a moved use brings in still names the same thing.
        new = None if by_alias and mapped(path[: len(path) - len(segs) + 1], moves) else mapped(path, moves)
        if new is not None:
            edits.append((m.start(), m.end(), "::".join(relative(new, home))))
            path = new
        if path[0] != krate:
            named.append(path)
    for a, b, new in sorted(edits, reverse=True):
        text = text[:a] + new + text[b:]
    return text, named


def paths_named(text: str, scope: list[str], krate: str, crate_names: set[str]) -> list[tuple[int, list[str]]]:
    """Every absolute path `text` names, with its line: those of its uses and those written in code."""
    code = blank(text)
    spans = inline_mods(code)
    out, aliases = [], child_mods(code, scope, spans, krate)
    use_spans = []
    for start, end, _indent, _vis, tree in find_uses(code):
        use_spans.append((start, end))
        here = scope_at(scope, spans, start)
        line = code.count("\n", 0, start) + 1
        for segs, alias in parse_tree(tree):
            path = resolve(segs, here, krate) or (segs if segs and segs[0] in crate_names else None)
            if path:
                out.append((line, path))
                if segs[-1] != "*":
                    aliases.setdefault(tuple(here), {})[alias or path[-1]] = path
    for m in re.finditer(r"(?<![\w:])((?:[A-Za-z_]\w*::)+[A-Za-z_]\w*)", code):
        if any(a <= m.start() < b for a, b in use_spans):
            continue
        segs = m.group(1).split("::")
        here = scope_at(scope, spans, m.start())
        path = resolve(segs, here, krate)
        if path is None:
            for depth in range(len(here), -1, -1):
                known = aliases.get(tuple(here[:depth]), {})
                if segs[0] in known:
                    path = known[segs[0]] + segs[1:]
                    break
        if path is None and segs[0] in crate_names:
            path = segs
        if path:
            out.append((code.count("\n", 0, m.start()) + 1, path))
    return out
