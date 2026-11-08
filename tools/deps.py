"""The packages' graph (milestone 96 of docs/cardwave-rewrite.md): which module names which, which crate
which, every use the crates' order forbids, and who names an item.

  python tools/deps.py                 the module graph of server/src and the crate graph
  python tools/deps.py --forbidden [crate …]   each named path the order forbids, by its file and line
                                       (only those from the crates given)
  python tools/deps.py --who PATH      who names PATH (`db::lock`, `cw_core::Fail`), by file and line
  python tools/deps.py --check         the check `crates` (tools/check.sh): fails on a workspace dependency
                                       the order does not allow, and on a crate that lists a library
                                       another crate wraps (WRAPS; its tests may)

ORDER is the crates bottom to top: a crate uses only those before it. Paths are read by
tools/rust_paths.py; `cargo metadata` tells the crates and their dependencies.
"""

import collections
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from rust_paths import module_of, paths_named  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SERVER = "cardwave_server"
ORDER = [
    "cw-core", "cw-platform", "cw-faces", "cw-whisper",
    "cw-prompt", "cw-ccv4",
    "cw-key", "cw-accounts", "cw-modelfiles", "cw-provider", "cw-search", "cw-voice", "cw-dictation",
    "cw-library", "cw-coding", "cw-chat", "cw-find",
    "cw-store", "cardwave-server", "cardwave-desktop",
]
# A library named by one crate alone, the one that wraps it.
WRAPS = {
    "reqwest": ["cw-platform"],
    "windows-sys": ["cw-platform", "cw-coding"],  # the tools' sandbox (tools/sandbox.rs) has its own
    "whisper-rs": ["cw-whisper"],
    "windows": ["cw-faces"],
    "windows-collections": ["cw-faces"],
    "windows-future": ["cw-faces"],
    "rusqlite": ["cw-store"],
    "sqlite-vec": ["cw-store"],
    "axum": ["cardwave-server"],
}
def metadata():
    out = subprocess.run(["cargo", "metadata", "--no-deps", "--format-version", "1", "--offline"],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return json.loads(out)["packages"]


def crates():
    """Each workspace crate: (package name, lib name as code names it, source folder)."""
    found = []
    for pkg in metadata():
        lib = next((t for t in pkg["targets"] if "lib" in t["kind"]), None) or pkg["targets"][0]
        src = Path(lib["src_path"]).parent
        found.append((pkg["name"], lib["name"].replace("-", "_"), src, pkg))
    return found


def files():
    """Every source file: (path, crate it is in, its module, the code name of that crate)."""
    out = []
    for name, code, src, _pkg in crates():
        for path in sorted(src.rglob("*.rs")):
            if name == "cardwave-desktop" or "generated" in path.parts:
                continue
            mod = module_of(path, src)
            out.append((path, name, mod, code))
    return out


def crate_of_path(path, by_code):
    """The crate an absolute path names."""
    return by_code.get(path[0])


def named_paths():
    found = crates()
    by_code = {code: name for name, code, _s, _p in found}
    names = set(by_code)
    for path, crate, mod, code in files():
        text = path.read_text(encoding="utf-8")
        for line, p in paths_named(text, mod, code, names):
            yield path, crate, line, p, crate_of_path(p, by_code)


def forbidden(only):
    rank = {c: i for i, c in enumerate(ORDER)}
    seen = set()
    for path, crate, line, p, target in named_paths():
        if target is None or target == crate or (only and crate not in only):
            continue
        if rank.get(target, 99) > rank.get(crate, 99):
            key = (path, "::".join(p))
            if key not in seen:
                seen.add(key)
                print(f"{path.relative_to(ROOT).as_posix()}:{line} {crate} -> {target}: {'::'.join(p)}")


def who(item):
    want = item.split("::")
    for path, _crate, line, p, _t in named_paths():
        for i in range(len(p) - len(want) + 1):
            if p[i: i + len(want)] == want:
                print(f"{path.relative_to(ROOT).as_posix()}:{line} {'::'.join(p)}")
                break


def graph():
    mods = collections.defaultdict(collections.Counter)
    edges = collections.defaultdict(collections.Counter)
    for path, crate, _line, p, target in named_paths():
        if target is None:
            continue
        rel = path.relative_to(ROOT).parts
        top = rel[2].removesuffix(".rs") if rel[0] == "server" and len(rel) > 2 else rel[1]
        if p[0] == SERVER and len(p) > 1 and p[1] != top:
            mods[top][p[1]] += 1
        if target != crate:
            edges[crate][target] += 1
    print("== modules of server/src: the modules each names")
    for m in sorted(mods, key=lambda m: -len(mods[m])):
        print(f"{m}: {len(mods[m])} ({' '.join(sorted(mods[m]))})")
    print("\n== crates: paths named (!! where the order forbids)")
    rank = {c: i for i, c in enumerate(ORDER)}
    for a in sorted(edges, key=lambda c: rank.get(c, 99)):
        for b, n in sorted(edges[a].items(), key=lambda e: rank.get(e[0], 99)):
            flag = "!!" if rank.get(b, 99) > rank.get(a, 99) else "  "
            print(f"{flag} {a} -> {b}: {n}")


def check():
    """The check `crates`: prints each dependency the order or WRAPS refuses; exit 1 if any."""
    found = crates()
    names = {name for name, *_ in found}
    rank = {c: i for i, c in enumerate(ORDER)}
    bad = []
    for name, _code, _src, pkg in found:
        if name not in rank:
            bad.append(f"{name}: not in the order (tools/deps.py ORDER)")
            continue
        for dep in pkg["dependencies"]:
            if dep["kind"] == "build":
                continue
            d = dep["name"]
            if d in names and rank.get(d, 99) >= rank[name]:
                bad.append(f"{name} -> {d}: the order allows only crates below it")
            owners = set(WRAPS.get(d, []))
            if owners and name not in owners and dep["kind"] != "dev":  # a test may drive a library itself
                bad.append(f"{name} lists {d}, which {' and '.join(sorted(owners))} wraps")
    for line in bad:
        print(line)
    return 1 if bad else 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["--forbidden"]:
        forbidden(set(args[1:]))
    elif args[:1] == ["--who"]:
        who(args[1])
    elif args[:1] == ["--check"]:
        sys.exit(check())
    else:
        graph()
