"""Fills desktop/llama with llama.cpp's llama-server, which runs the search model (crates/cw-provider/src/embedder.rs) and This computer's models (crates/cw-provider/src/local.rs).

The Vulkan build of release b11528 (MIT) for the system this runs on (Windows' zip, Ubuntu's tar.gz), which
also runs on the processor alone, is downloaded from GitHub once, checked by its SHA-256, and of it only
what llama-server needs is kept (on Windows about 84 MB; the installer compresses it to about 12 MB). The
bundle ships the folder (desktop/tauri.conf.json, "resources"); `npm run dist` and `npm run dev` in desktop/
run this first. A folder that holds the build already is left as it is. Run from anywhere: python tools/llama.py

Linux trap: the tar's libraries are versioned files behind symlinks (libllama.so.0 -> libllama.so.0.6.0); the
bundle keeps no symlinks, so each is stored under the name the others load it by (its SONAME, lib*.so.N), and
the RUNPATH $ORIGIN the release sets finds them beside llama-server.

A server started by hand (cargo run in server/) finds the folder by `--llama-dir desktop/llama`.
"""

import hashlib
import io
import pathlib
import re
import sys
import tarfile
import urllib.request
import zipfile

BASE = "https://github.com/ggml-org/llama.cpp/releases/download/b11528/"
if sys.platform == "win32":
    RELEASE = BASE + "llama-b11528-bin-win-vulkan-x64.zip"
    SHA256 = "9f4f8222ac7e97531632c991e8e8b9d7532c8df5e527b3b4b1f3165f61eaa0ee"
    # llama-server and the libraries it loads; ggml-cpu-*.dll are the processor's, one per kind of processor.
    KEEP = {"llama-server.exe", "llama-server-impl.dll", "llama-common.dll", "llama.dll", "mtmd.dll", "ggml.dll",
            "ggml-base.dll", "ggml-vulkan.dll", "libomp.dll", "LICENSE-LLVM-OpenMP"}
    CPU = re.compile(r"ggml-cpu-.+\.dll")
elif sys.platform == "linux":
    RELEASE = BASE + "llama-b11528-bin-ubuntu-vulkan-x64.tar.gz"
    SHA256 = "85aa3c8d6deb70517d2bd5d11c745146464e73b0ff91a522baa404f6f77c9021"
    KEEP = {"llama-server", "libllama-server-impl.so", "libllama-common.so.0", "libllama.so.0", "libmtmd.so.0",
            "libggml.so.0", "libggml-base.so.0", "libggml-vulkan.so", "LICENSE"}
    CPU = re.compile(r"libggml-cpu-.+\.so")
else:
    sys.exit(f"llama-server is fetched only for Windows and Linux, not {sys.platform}")
FOLDER = pathlib.Path(__file__).resolve().parent.parent / "desktop" / "llama"
STAMP = FOLDER / "release.txt"


def members(data: bytes):
    """Each regular file of the release as (the name kept, its bytes); a versioned library as its SONAME."""
    if RELEASE.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(data)) as release:
            for name in release.namelist():
                yield pathlib.PurePosixPath(name).name, lambda n=name: release.read(n)
        return
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as release:
        for member in release.getmembers():
            if member.isfile():
                name = re.sub(r"(\.so\.\d+)(\.\d+)+$", r"\1", pathlib.PurePosixPath(member.name).name)
                yield name, lambda m=member: release.extractfile(m).read()


def main() -> None:
    if STAMP.exists() and STAMP.read_text().strip() == RELEASE:
        return
    print(f"Downloading {RELEASE}")
    data = urllib.request.urlopen(RELEASE, timeout=60).read()
    got = hashlib.sha256(data).hexdigest()
    assert got == SHA256, f"the download is not the release: SHA-256 {got}"
    FOLDER.mkdir(parents=True, exist_ok=True)
    for name, read in members(data):
        if name in KEEP or CPU.fullmatch(name):
            path = FOLDER / name
            path.write_bytes(read())
            path.chmod(0o755)
    STAMP.write_text(RELEASE + "\n")
    print(f"llama-server is in {FOLDER}")


if __name__ == "__main__":
    main()
