"""Writes web/src/app/looks.css, the five looks of the theme menu, from the page "Cardwave Themes"'s
design/wave/v3/<look>.css (gitignored; its sources design/wave/v3/src/, built by design/wave/v3/build.py). From the repo's root.

Each look is carried over as it is, its fonts aside: written as the user's own CSS, it is scoped here to the root's
`data-theme="<id>"`. Its `:root` block becomes `:root:where([data-theme=…])`, as heavy as `:root`, and every other
selector gets `:where(:root[data-theme=…])` before it, which weighs nothing: the looks stand last in the app's
stylesheet and so win by order, as they did after it, and the user's own CSS, after them, still wins over them.
Its base64 fonts are left out; the fontsource packages' files stand in (FONTS).

The themes are web/src/theme.ts's `Theme`, their source: the looks are those but the system's, light and dark, and
the line of web/public/early.js that lists them (`EARLY_LINE`) is written here too."""
import re
from pathlib import Path



def themes() -> list[str]:
    """The themes of web/src/theme.ts's `Theme`, in its order."""
    source = Path("web/src/theme.ts").read_text(encoding="utf-8")
    return re.findall(r'"([^"]+)"', re.search(r"^export type Theme = (.+);$", source, re.M).group(1))


LOOKS = tuple(t for t in themes() if t not in ("system", "light", "dark"))
EARLY = Path("web/public/early.js")
EARLY_LINE = re.compile(r"^  const themes = \[.*$", re.M)
# Family, weight, the fontsource package and file name: the faces the looks' own @font-face lines name, Latin only.
FONTS = (
    ("Quicksand", 500, "quicksand"), ("Quicksand", 600, "quicksand"),
    ("Michroma", 400, "michroma"), ("Exo 2", 400, "exo-2"), ("Exo 2", 600, "exo-2"),
    ("Racing Sans One", 400, "racing-sans-one"), ("Yellowtail", 400, "yellowtail"),
)
HEAD = """/* The five looks of the theme menu (theme.ts), written by tools/looks.py from the page "Cardwave Themes"'s files: do
   not edit here. Each applies under the root's data-theme="<its id>" and sets its own colour scheme; none sets a size,
   so Compact works on each. Their selectors weigh what they did as the user's own CSS, which still wins over them.
   They are carried over as they are (the owner: each keeps its own character), hence the lint's two rules off. */
/* stylelint-disable no-duplicate-selectors, declaration-property-value-disallowed-list */
"""


def split_top(text: str, at: str) -> list[str]:
    """`text` split at each `at` outside brackets and quotes."""
    parts, depth, quote, start = [], 0, "", 0
    for i, c in enumerate(text):
        if quote:
            quote = "" if c == quote else quote
        elif c in "\"'":
            quote = c
        elif c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif c == at and depth == 0:
            parts.append(text[start:i])
            start = i + 1
    return parts + [text[start:]]


def scoped(selectors: str, look: str) -> str:
    """The selector list `selectors` applying only under the look `look`."""
    root, where, out = f':root:where([data-theme="{look}"])', f':where(:root[data-theme="{look}"])', []
    for one in (s.strip() for s in split_top(selectors, ",")):
        if one in (":root", ":root[data-theme]"):
            new = [root]
        elif one == "*":
            new = [where, f"{where} *"]
        else:
            assert not one.startswith((":root", "html")), one
            new = [f"{where} {one}"]
        out += [n for n in new if n not in out]
    return ", ".join(out)


def block_end(text: str, at: int) -> int:
    """Where the block opened at `at` closes, outside quotes."""
    depth, quote = 0, ""
    for i in range(at, len(text)):
        c = text[i]
        if quote:
            quote = "" if c == quote else quote
        elif c in "\"'":
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("a block left open")


def rules(text: str, look: str) -> str:
    """The rules of `text`, each scoped to `look`; an @media or @container block's rules likewise."""
    out, at = [], 0
    while at < len(text):
        gap = re.match(r"\s*(/\*.*?\*/\s*)*", text[at:], re.S).end()
        out.append(text[at:at + gap])
        at += gap
        if at >= len(text):
            break
        opens = text.index("{", at)
        close = block_end(text, opens)
        prelude, body = text[at:opens].strip(), text[opens + 1:close]
        if prelude.startswith("@"):
            assert prelude.startswith(("@media", "@container")), prelude
            out.append(f"{prelude} {{{rules(body, look)}}}")
        else:
            out.append(f"{scoped(prelude, look)} {{{body}}}")
        at = close + 1
    return "".join(out)


def main() -> None:
    faces = "".join(f'@font-face {{ font-family: "{family}"; font-style: normal; font-weight: {weight}; font-display: block; '
                    f'src: url("@fontsource/{package}/files/{package}-latin-{weight}-normal.woff2") format("woff2"); }}\n'
                    for family, weight, package in FONTS)
    parts = [HEAD, faces]
    for look in LOOKS:
        source = Path(f"design/wave/v3/{look}.css").read_text(encoding="utf-8")
        named = re.findall(r"^@font-face \{ font-family: '([^']+)'; font-weight: (\d+);", source, re.M)
        missing = [f for f in named if (f[0], int(f[1])) not in {(fam, w) for fam, w, _ in FONTS}]
        assert not missing, missing
        source = "".join(line for line in source.splitlines(keepends=True) if not line.startswith("@font-face"))
        parts.append(f"\n{rules(source, look).strip()}\n")
    Path("web/src/app/looks.css").write_text("".join(parts), encoding="utf-8", newline="\n")
    print("web/src/app/looks.css", sum(len(p) for p in parts), "characters,", len(LOOKS), "looks,", len(FONTS), "faces")
    listed = ", ".join(f'"{t}"' for t in themes() if t != "system")
    line = f"  const themes = [{listed}]; // the themes of src/theme.ts but the system's, written by tools/looks.py"
    early = EARLY.read_text(encoding="utf-8")
    assert len(EARLY_LINE.findall(early)) == 1
    EARLY.write_text(EARLY_LINE.sub(lambda _: line, early), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
