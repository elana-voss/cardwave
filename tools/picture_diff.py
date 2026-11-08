"""Where each changed stored picture of the browser tests differs from its committed one, so a renewal is read
without viewing every picture. From the repo's root: `python tools/picture_diff.py [<commit>] [<table>]`.

Per picture changed against <commit> (default HEAD) under e2e/, ImageMagick's `magick` gives the box of the pixels
that differ (`WxH+X+Y`) and how many differ; a picture of another size says both sizes. The table (default
.checklists/picture_diff.tsv) holds a line per picture; printed are the counts and the boxes most pictures share,
at most 10 lines, so a change that should touch one place (the rail's foot) shows its outliers.
"""

import collections
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def run(*args: str) -> str:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=False).stdout.strip()


def differs(old: pathlib.Path, new: pathlib.Path) -> tuple[str, str]:
    """The box of the differing pixels and their count; the sizes where they differ."""
    sizes = [run("magick", "identify", "-format", "%wx%h", str(p)) for p in (old, new)]
    if sizes[0] != sizes[1]:
        return f"size {sizes[0]} -> {sizes[1]}", ""
    diff = [str(old), str(new), "-compose", "difference", "-composite", "-threshold", "0"]
    box = run("magick", *diff, "-format", "%@", "info:")
    count = run("magick", *diff, "-format", "%[fx:int(mean*w*h)]", "info:")
    return box, count


def main() -> None:
    commit = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    table = ROOT / (sys.argv[2] if len(sys.argv) > 2 else ".checklists/picture_diff.tsv")
    names = run("git", "diff", "--name-only", commit, "--", "e2e/*.png").splitlines()
    rows = []
    with tempfile.TemporaryDirectory() as scratch:
        old = pathlib.Path(scratch) / "old.png"
        for name in names:
            blob = subprocess.run(["git", "show", f"{commit}:{name}"], cwd=ROOT, capture_output=True, check=False)
            if blob.returncode != 0:
                rows.append((name, "new", ""))
                continue
            old.write_bytes(blob.stdout)
            rows.append((name, *differs(old, ROOT / name)))
    table.write_text("".join("\t".join(row) + "\n" for row in rows), encoding="utf-8")
    print(f"{len(rows)} pictures changed against {commit}; table {table.relative_to(ROOT)}")
    for box, n in collections.Counter(row[1] for row in rows).most_common(9):
        print(f"{n:4}  {box}")


if __name__ == "__main__":
    main()
