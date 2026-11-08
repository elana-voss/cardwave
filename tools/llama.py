"""Fills desktop/llama with llama.cpp's llama-server, which runs the search model (crates/cw-provider/src/embedder.rs) and This computer's models (crates/cw-provider/src/local.rs).

The Vulkan build of release b11528 (MIT), which also runs on the processor alone, is downloaded from
GitHub once, checked by its SHA-256, and of it only what llama-server needs is kept (about 84 MB; the
installer compresses it to about 12 MB). The installer ships the folder (desktop/tauri.conf.json,
"resources"); `npm run dist` and `npm run dev` in desktop/ run this first. A folder that holds the
build already is left as it is. Run from anywhere: python tools/llama.py

A server started by hand (cargo run in server/) finds the folder by `--llama-dir desktop/llama`.
"""

import hashlib
import io
import pathlib
import urllib.request
import zipfile

RELEASE = "https://github.com/ggml-org/llama.cpp/releases/download/b11528/llama-b11528-bin-win-vulkan-x64.zip"
SHA256 = "9f4f8222ac7e97531632c991e8e8b9d7532c8df5e527b3b4b1f3165f61eaa0ee"
# llama-server and the libraries it loads; ggml-cpu-*.dll are the processor's, one per kind of processor.
KEEP = {"llama-server.exe", "llama-server-impl.dll", "llama-common.dll", "llama.dll", "mtmd.dll", "ggml.dll",
        "ggml-base.dll", "ggml-vulkan.dll", "libomp.dll", "LICENSE-LLVM-OpenMP"}
FOLDER = pathlib.Path(__file__).resolve().parent.parent / "desktop" / "llama"
STAMP = FOLDER / "release.txt"


def main() -> None:
    if STAMP.exists() and STAMP.read_text().strip() == RELEASE:
        return
    print(f"Downloading {RELEASE}")
    data = urllib.request.urlopen(RELEASE, timeout=60).read()
    got = hashlib.sha256(data).hexdigest()
    assert got == SHA256, f"the download is not the release: SHA-256 {got}"
    FOLDER.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as release:
        for name in release.namelist():
            base = pathlib.PurePosixPath(name).name
            if base in KEEP or (base.startswith("ggml-cpu-") and base.endswith(".dll")):
                (FOLDER / base).write_bytes(release.read(name))
    STAMP.write_text(RELEASE + "\n")
    print(f"llama-server is in {FOLDER}")


if __name__ == "__main__":
    main()
