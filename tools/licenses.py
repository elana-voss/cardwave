"""Writes web/public/licenses.json, what the page "About Cardwave" lists (web/src/views/about.ts).

Libraries: the crates the desktop app is built of (cargo metadata for Windows, the normal dependencies from
cardwave-desktop down, and -src crates; not those only built with or tested), the npm packages the UI bundles (web/package.json's
"dependencies" and theirs), and the programs that come with the app or are downloaded by it (`PROGRAMS`). Each
with the license texts it ships: the files named LICENSE, COPYING, NOTICE and the like at its top, and in a
crate ending in -sys or -src also those two folders down (the C library it builds, such as SQLCipher's and
OpenSSL's); a crate that ships none gets the standard texts of the licenses it names (spdx-*.txt). Models, figures and
lists are `MODELS`, `FIGURES` and `LISTS`. The texts not taken from a package are in tools/licenses/, fetched once from the
address `SOURCES` names. Each text is kept once (`texts`); a row names its texts by their place there.

`npm run dist` in desktop/ runs this first. Run from anywhere: python tools/licenses.py
"""

import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXTS = ROOT / "tools" / "licenses"
OUT = ROOT / "web" / "public" / "licenses.json"

# Where each text of tools/licenses/ came from.
SOURCES = {
    "bge-m3.txt": "https://raw.githubusercontent.com/FlagOpen/FlagEmbedding/master/LICENSE (bge-m3's own page names MIT and has no file)",
    "cc-by-4.0.txt": "https://creativecommons.org/licenses/by/4.0/legalcode.txt",
    "cc0-1.0.txt": "https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt",
    "mixamo.txt": "written for Cardwave, naming the pages of Adobe's terms (the owner, 2026-10-21: the animations come from Mixamo)",
    "llama.cpp.txt": "https://raw.githubusercontent.com/ggml-org/llama.cpp/b11528/LICENSE",
    "onnxruntime.txt": "https://raw.githubusercontent.com/microsoft/onnxruntime/v1.28.0/LICENSE",
    "onnxruntime-notices.txt": "onnxruntime/ThirdPartyNotices.txt of the wheel crates/cw-voice/src/lib.rs downloads (`RUNTIME`)",
    "yunet.txt": "https://raw.githubusercontent.com/opencv/opencv_zoo/main/models/face_detection_yunet/LICENSE",
    "spdx-*.txt": "https://raw.githubusercontent.com/spdx/license-list-data/main/text/<id>.txt",
}

MODELS = [
    ("bge-m3", "Search model", "MIT", "BAAI", "bge-m3.txt"),
    ("Pocket TTS", "Voice model", "CC BY 4.0", "Kyutai, converted by KevinAHM", "cc-by-4.0.txt"),
    ("Whisper large-v3-turbo", "Dictation model", "MIT", "OpenAI, converted by ggerganov", "spdx-MIT.txt"),
    ("YuNet", "Finds the face in a character's picture, to frame it", "MIT", "Shiqi Yu", "yunet.txt"),
]
# The group "Figures and animations" of About Cardwave (board "About Cardwave", v5).
FIGURES = [
    ("RobotExpressive", "The companion's robot", "CC0", "Tomás Laulhé, changed by Don McCurdy", "cc0-1.0.txt"),
    ("Mixamo", "Animations of the companion's woman and man", "Adobe's terms", "Adobe", "mixamo.txt"),
]
LISTS = [("models.dev", "The list of providers", "MIT")]
# Programs that are no package of Rust's or npm's: llama.cpp's llama-server comes with the app (tools/llama.py,
# with LLVM's OpenMP library), ONNX Runtime is downloaded for the voice (crates/cw-voice/src/lib.rs), with the notices
# of what it is built of. The Rust standard library, in every Rust program, is `rust`.
PROGRAMS = [
    ("llama.cpp", "b11528", "MIT", [TEXTS / "llama.cpp.txt"]),
    ("LLVM OpenMP", "", "Apache-2.0 WITH LLVM-exception", [ROOT / "desktop" / "llama" / "LICENSE-LLVM-OpenMP"]),
    ("ONNX Runtime", "1.28.0", "MIT", [TEXTS / "onnxruntime.txt", TEXTS / "onnxruntime-notices.txt"]),
]
NAMES = ("LICENSE", "LICENCE", "COPYING", "NOTICE", "UNLICENSE", "COPYRIGHT")


class Texts:
    """Each text once, by its place in `all`."""

    def __init__(self) -> None:
        self.all: list[str] = []
        self.at: dict[str, int] = {}

    def add(self, text: str) -> int:
        text = "\n".join(line.rstrip() for line in text.replace("\r\n", "\n").split("\n")).strip()
        if text not in self.at:
            self.at[text] = len(self.all)
            self.all.append(text)
        return self.at[text]

    def files(self, paths: list[pathlib.Path]) -> list[int]:
        return [self.add(path.read_text(encoding="utf-8", errors="replace")) for path in paths]


def license_files(folder: pathlib.Path, deep: bool) -> list[pathlib.Path]:
    found = sorted(p for p in folder.iterdir() if p.is_file() and p.name.upper().startswith(NAMES))
    if deep:
        for inner in sorted(p for p in folder.iterdir() if p.is_dir()):
            for second in [inner, *sorted(p for p in inner.iterdir() if p.is_dir())]:
                found += sorted(p for p in second.iterdir() if p.is_file() and p.name.upper().startswith(NAMES))
    return found


def standard(expression: str, name: str) -> list[pathlib.Path]:
    """The standard texts of the licenses an SPDX expression names, of those kept, for the package `name`.
    An exception (`WITH LLVM-exception`) has no text of its own here and is left out."""
    expression = re.sub(r"\bWITH\s+\S+", " ", expression)
    ids = [part for part in re.split(r"[\s()/]+|\bOR\b|\bAND\b", expression) if part]
    paths = [TEXTS / f"spdx-{id}.txt" for id in dict.fromkeys(ids)]
    missing = [path.name for path in paths if not path.exists()]
    assert not missing, f"{name}: no standard text for {missing}; fetch it as SOURCES says"
    return paths


def rust() -> tuple:
    """The Rust standard library's row, as `PROGRAMS` has one: the version of the rustc that builds the app."""
    version = subprocess.run(["rustc", "-V"], capture_output=True, check=True, text=True).stdout.split()[1]
    return ("Rust standard library", version, "MIT OR Apache-2.0", standard("MIT OR Apache-2.0", "Rust standard library"))


def crates(texts: Texts) -> list[dict]:
    meta = json.loads(subprocess.run(
        ["cargo", "metadata", "--format-version", "1", "--filter-platform", "x86_64-pc-windows-msvc"],
        cwd=ROOT, capture_output=True, check=True, text=True, encoding="utf-8").stdout)
    packages = {p["id"]: p for p in meta["packages"]}
    nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
    members = set(meta["workspace_members"])
    start = next(i for i in members if packages[i]["name"] == "cardwave-desktop")
    seen, todo = set(), [start]
    while todo:
        for dep in nodes[todo.pop()]["deps"]:
            normal = any(kind["kind"] is None for kind in dep["dep_kinds"])
            # A -src crate is a build dependency whose C library is linked in (OpenSSL's); what builds it is not.
            if (normal or dep["name"].endswith("_src")) and dep["pkg"] not in seen:
                seen.add(dep["pkg"])
                if normal:
                    todo.append(dep["pkg"])
    rows = []
    # In a fixed order, so that the texts keep their places from run to run (a set's order changes with each run).
    for package in (packages[i] for i in sorted(seen - members)):
        folder = pathlib.Path(package["manifest_path"]).parent
        files = license_files(folder, package["name"].endswith(("-sys", "-src")))
        if not files and package.get("license_file"):
            files = [folder / package["license_file"]]
        assert package["license"], f"{package['name']} names no license"
        if not files:
            files = standard(package["license"], package["name"])
        rows.append({"name": package["name"], "version": package["version"], "license": package["license"], "texts": texts.files(files)})
    return rows


def npm(texts: Texts) -> list[dict]:
    modules = ROOT / "web" / "node_modules"
    todo = list(json.loads((ROOT / "web" / "package.json").read_text(encoding="utf-8"))["dependencies"])
    rows, seen = [], set()
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        seen.add(name)
        folder = modules / name
        package = json.loads((folder / "package.json").read_text(encoding="utf-8"))
        todo += list(package.get("dependencies", {}))
        assert isinstance(package.get("license"), str), f"{name} names no license"
        files = license_files(folder, False) or standard(package["license"], name)
        rows.append({"name": name, "version": package["version"], "license": package["license"], "texts": texts.files(files)})
    return rows


def main() -> None:
    texts = Texts()
    models, figures = ([{"name": name, "what": what, "license": license, "by": by, "text": texts.files([TEXTS / file])[0]}
                        for name, what, license, by, file in rows] for rows in (MODELS, FIGURES))
    # models.dev's notice is the head of the file tools/providers.py writes from its list.
    toml = (ROOT / "crates" / "cw-provider" / "providers" / "models.dev.toml").read_text(encoding="utf-8").split("\n")
    head = [line[2:] if line.startswith("# ") else "" for line in toml[: toml.index("")] if line.startswith("#")]
    notice = "\n".join(head[head.index("models.dev is under the MIT License:") + 2:])
    lists = [{"name": name, "what": what, "license": license, "by": "", "text": texts.add(notice)} for name, what, license in LISTS]
    libraries = crates(texts) + npm(texts)
    libraries += [{"name": name, "version": version, "license": license, "texts": texts.files(files)}
                  for name, version, license, files in [*PROGRAMS, rust()]]
    libraries.sort(key=lambda row: (row["name"].lower(), row["version"]))
    OUT.parent.mkdir(exist_ok=True)
    data = {"models": models, "figures": figures, "lists": lists, "libraries": libraries, "texts": texts.all}
    # A row or a text a line, so that a change shows as the lines it changed.
    one = lambda value: json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    parts = [f"{one(key)}:[\n" + ",\n".join(one(item) for item in items) + "\n]" for key, items in data.items()]
    OUT.write_text("{\n" + ",\n".join(parts) + "\n}\n", encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(ROOT)}: {len(libraries)} libraries, {len(texts.all)} texts, {OUT.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    main()
