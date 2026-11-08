"""Moves modules of the server into a crate of the workspace, and items to their new paths (milestone 96).

  python tools/crate_move.py CRATE [MODULE …] [--flat] [--map OLD=NEW …]

CRATE (`cw-core`) is made where it is not yet: `crates/CRATE/Cargo.toml` and `src/lib.rs`, a member and a
workspace dependency of the root `Cargo.toml`. Each MODULE of `server/src` (its `m.rs` and its folder `m/`)
goes there by `git mv`, its `mod m;` leaves `server/src/lib.rs` and `pub mod m;` joins the crate's.
Every `use` and written path in server/src, server/tests, desktop/src and crates/*/src that names a moved
module, or an item OLD (`api::Fail`, a server path; or `cw_core::fail::Fail`), is rewritten to its new place
(`cw_core::Fail` written NEW); inside the crate it is `crate::…`. Each crate's `Cargo.toml` then lists the
workspace crates and libraries its files name, and server's drops those it no longer names. Ends with
`cargo fmt --all`. `--flat` (one MODULE): the module is the crate, its `m.rs` or `m/mod.rs` the crate's
`lib.rs` and its folder's files the crate's (`crate::prompt::Role` → `cw_prompt::Role`). Prints each path a moved file names that stays behind (an edge to cut by hand).
Paths are read by tools/rust_paths.py (its traps).
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from rust_paths import blank, module_of, paths_named, rewrite  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SERVER = "cardwave_server"


def code_name(crate: str) -> str:
    return crate.replace("-", "_")


def sources():
    """Every Rust source to rewrite: (path, its crate's code name, its source folder or None for tests)."""
    out = []
    for path in sorted((ROOT / "server" / "src").rglob("*.rs")):
        out.append((path, SERVER, ROOT / "server" / "src"))
    for path in sorted((ROOT / "server" / "tests").rglob("*.rs")):
        out.append((path, "server_tests", None))
    for path in sorted((ROOT / "desktop" / "src").rglob("*.rs")):
        out.append((path, "cardwave_desktop", ROOT / "desktop" / "src"))
    for crate in sorted((ROOT / "crates").glob("*/src")):
        for path in sorted(crate.rglob("*.rs")):
            out.append((path, code_name(crate.parent.name), crate))
    return out


def workspace_crates() -> set[str]:
    names = {SERVER, "cardwave_desktop"}
    names |= {code_name(p.name) for p in (ROOT / "crates").glob("*") if p.is_dir()}
    return names


def make_crate(crate: str):
    folder = ROOT / "crates" / crate
    if (folder / "Cargo.toml").exists():
        return
    (folder / "src").mkdir(parents=True, exist_ok=True)
    (folder / "Cargo.toml").write_text(
        f'[package]\nname = "{crate}"\nversion.workspace = true\nedition.workspace = true\n'
        f"license.workspace = true\npublish.workspace = true\n\n[lib]\ndoctest = false\n\n[dependencies]\n", encoding="utf-8", newline="")
    (folder / "src" / "lib.rs").write_text("", encoding="utf-8", newline="")
    root = ROOT / "Cargo.toml"
    text = root.read_text(encoding="utf-8")
    text = re.sub(r'members = \[([^\]]*)\]', lambda m: f'members = [{m.group(1)}, "crates/{crate}"]', text, count=1)
    text = text.replace("[workspace.dependencies]\n",
                        f'[workspace.dependencies]\n{crate} = {{ path = "crates/{crate}" }}\n', 1)
    root.write_text(text, encoding="utf-8", newline="")


def parse_path(text: str) -> list[str]:
    segs = text.split("::")
    return segs if segs[0] in workspace_crates() | {"crate"} else [SERVER] + segs


def workspace_deps() -> list[str]:
    text = (ROOT / "Cargo.toml").read_text(encoding="utf-8").split("[workspace.dependencies]", 1)[1]
    return re.findall(r"(?m)^([A-Za-z0-9_-]+)\s*=", text)


def names_in(paths) -> set[str]:
    """The crates and libraries named in the code of `paths` (`name::` or `use name`)."""
    found = set()
    for p in paths:
        code = blank(p.read_text(encoding="utf-8"))
        found |= set(re.findall(r"(?<![\w:])([A-Za-z_]\w*)::", code))
        found |= set(re.findall(r"\buse\s+([A-Za-z_]\w*)", code))
    return found


def server_dep_sections() -> dict[str, str]:
    """Which section of server/Cargo.toml lists each dependency (`[dependencies]`, a target's …)."""
    section, out = None, {}
    for line in (ROOT / "server" / "Cargo.toml").read_text(encoding="utf-8").splitlines():
        if line.startswith("["):
            section = line
        elif section and "dependencies" in section and (m := re.match(r"([A-Za-z0-9_-]+)\s*[.=]", line)):
            out.setdefault(m.group(1), section)
    return out


def set_deps(cargo: Path, files, own: str | None):
    """Adds to `cargo` each workspace dependency `files` name and it lacks."""
    named = names_in(files)
    text = cargo.read_text(encoding="utf-8")
    sections = server_dep_sections()
    for dep in workspace_deps():
        if dep == own or code_name(dep) not in named:
            continue
        if re.search(rf"(?m)^{re.escape(dep)}\s*[.=]", text):
            continue
        section = sections.get(dep, "[dependencies]") if dep != own else "[dependencies]"
        if not dep.startswith("cw-") and section not in text:
            text = text.rstrip("\n") + f"\n\n{section}\n"
        anchor = section if section in text else "[dependencies]"
        text = text.replace(anchor + "\n", f"{anchor}\n{dep}.workspace = true\n", 1)
    cargo.write_text(text, encoding="utf-8", newline="")


def drop_unnamed(cargo: Path, files):
    """Drops from `cargo`'s dependencies each workspace one `files` no longer name."""
    named = names_in(files)
    lines, out, section = cargo.read_text(encoding="utf-8").splitlines(), [], ""
    for line in lines:
        if line.startswith("["):
            section = line
        m = re.match(r"([A-Za-z0-9_-]+)\.workspace = true", line)
        if m and section == "[dependencies]" and code_name(m.group(1)) not in named:
            print(f"{cargo.relative_to(ROOT).as_posix()}: dropped {m.group(1)}")
            continue
        out.append(line)
    cargo.write_text("\n".join(out) + "\n", encoding="utf-8", newline="")


def regroup(text: str) -> str:
    """Puts each top-level `use cw_…;` with the uses of the other crates, which rustfmt then sorts."""
    found = re.findall(r"(?m)^use cw_\w+::[^;]*;\n", text)
    if not found:
        return text
    for stmt in found:
        text = text.replace(stmt, "", 1)
    text = re.sub(r"\n\n\n+", "\n\n", text)
    blocks = list(re.finditer(r"(?m)(?:^use [^;]*;\n)+", text))
    for b in blocks:
        if not re.match(r"use (std|core|alloc|crate|super|self)::", b.group(0)):
            return text[:b.end()] + "".join(found) + text[b.end():]
    after = [b for b in blocks if re.match(r"use (std|core|alloc)::", b.group(0))]
    head = re.match(r"(?:(?://!.*|#!\[.*\]|)\n)*", text).end()  # a file's head comment stays first
    at = after[0].end() + 1 if after else (blocks[0].start() if blocks else head)
    return text[:at] + "".join(found) + "\n" + text[at:]


def main(argv):
    crate, rest = argv[0], argv[1:]
    modules, maps, flat = [], [], False
    while rest:
        arg = rest.pop(0)
        if arg == "--flat":
            flat = True
        elif arg == "--map":
            old, new = rest.pop(0).split("=")
            maps.append((parse_path(old), new.split("::")))
        else:
            modules.append(arg)
    make_crate(crate)
    home = code_name(crate)
    if flat and len(modules) != 1:
        sys.exit("--flat takes one module")
    moves = [([SERVER, m], [home] if flat else [home, m]) for m in modules] + maps
    src = ROOT / "server" / "src"
    dest = ROOT / "crates" / crate / "src"

    def moved_to(path: Path) -> Path:
        """Where a moved file goes: flat, the module's own file is lib.rs and its folder's files the crate's."""
        rel = path.relative_to(src)
        if not flat:
            return dest / rel
        if rel.parts in ((f"{modules[0]}.rs",), (modules[0], "mod.rs")):
            return dest / "lib.rs"
        return dest / Path(*rel.parts[1:])
    moving = set()
    for m in modules:
        for p in [src / f"{m}.rs", *sorted((src / m).rglob("*.rs"))]:
            if p.exists():
                moving.add(p)
    names = workspace_crates()
    texts = {}
    for path, krate, folder in sources():
        scope = module_of(path, folder) if folder else []
        old = path.read_text(encoding="utf-8")
        new, _ = rewrite(old, scope, krate, moves, names, home if path in moving else None)
        new = regroup(new) if new != old else new
        if new != old:
            texts[path] = new
    if flat:
        (dest / "lib.rs").unlink()
        m = modules[0]
        for p in [src / f"{m}.rs", *(sorted((src / m).iterdir()) if (src / m).is_dir() else [])]:
            if p.exists():
                to = dest / "lib.rs" if p.name in (f"{m}.rs", "mod.rs") and p.parent in (src, src / m) else dest / p.name
                subprocess.run(["git", "mv", str(p), str(to)], cwd=ROOT, check=True)
    else:
        for m in modules:
            for p in (src / f"{m}.rs", src / m):
                if p.exists():
                    subprocess.run(["git", "mv", str(p), str(dest / p.name)], cwd=ROOT, check=True)
    for path, new in texts.items():
        if path in moving:
            path = moved_to(path)
        path.write_text(new, encoding="utf-8", newline="")
    lib = src / "lib.rs"
    text = lib.read_text(encoding="utf-8")
    for m in modules:
        text, n = re.subn(rf"(?m)^(?:[ \t]*(?:///.*|#\[.*\])\n)*[ \t]*(?:pub(?:\([^)]*\))? )?mod {m};\n", "", text)
        if not n:
            print(f"server/src/lib.rs: no `mod {m};` found")
    lib.write_text(text, encoding="utf-8", newline="")
    new_lib = ROOT / "crates" / crate / "src" / "lib.rs"
    lib_text = new_lib.read_text(encoding="utf-8")
    for m in [] if flat else modules:
        if f"mod {m};" not in lib_text:
            lib_text += f"pub mod {m};\n"
    new_lib.write_text(lib_text, encoding="utf-8", newline="")
    # What a moved file names that stayed behind.
    own = {p.stem for p in (ROOT / "crates" / crate / "src").iterdir()}
    if flat:  # the crate root's own items
        own |= set(re.findall(r"\b(?:fn|struct|enum|const|static|type|mod|trait|macro_rules!)\s+(\w+)",
                              blank((dest / "lib.rs").read_text(encoding="utf-8"))))
    for path in sorted((ROOT / "crates" / crate / "src").rglob("*.rs")):
        scope = module_of(path, ROOT / "crates" / crate / "src")
        for line, p in paths_named(path.read_text(encoding="utf-8"), scope, home, names):
            if p[0] == home and len(p) > 1 and p[1] not in own and p[1] not in ("self", "super"):
                print(f"left behind: {path.relative_to(ROOT).as_posix()}:{line} {'::'.join(p)}")
    # Dependencies.
    crate_files = list((ROOT / "crates" / crate / "src").rglob("*.rs"))
    set_deps(ROOT / "crates" / crate / "Cargo.toml", crate_files, crate)
    for folder in [ROOT / "server", ROOT / "desktop", *sorted((ROOT / "crates").glob("*"))]:
        if folder.name == crate or not (folder / "Cargo.toml").exists():
            continue
        files = list((folder / "src").rglob("*.rs"))
        if folder.name == "server":
            files += list((folder / "tests").rglob("*.rs"))
        set_deps(folder / "Cargo.toml", files, None)
    server_files = list(src.rglob("*.rs")) + list((ROOT / "server" / "tests").rglob("*.rs")) + [ROOT / "server" / "build.rs"]
    drop_unnamed(ROOT / "server" / "Cargo.toml", server_files)
    subprocess.run(["cargo", "fmt", "--all"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main(sys.argv[1:])
