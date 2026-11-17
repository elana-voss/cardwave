"""Writes the updater's feed `latest.json` for a release (.github/workflows/installer.yml).

Usage: python tools/release_feed.py <out.json> <installer> <download url> [<installer> <download url> ...]

The version is the workspace's (`Cargo.toml`), the notes that version's part of
`web/public/whats-new.md` (under `# <version>`), each signature the installer's
`.sig` beside it, which `tauri signer sign` wrote. Each installer is the entry
its kind's app asks for (`ENTRIES`, by the file's ending): the updater looks for
`<os>-<arch>-<bundle>` first, so the AppImage and the .deb each find their own.
The app's updater (desktop/src/update.rs) reads the file from the latest release.
"""

import datetime
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def version() -> str:
    text = (ROOT / "Cargo.toml").read_text(encoding="utf-8")
    found = re.search(r'^version = "([^"]+)"', text, re.MULTILINE)
    assert found, "Cargo.toml names no version"
    return found.group(1)


def notes(of: str) -> str:
    text = (ROOT / "web" / "public" / "whats-new.md").read_text(encoding="utf-8")
    parts = re.split(r"^# ", text, flags=re.MULTILINE)
    for part in parts:
        head, _, body = part.partition("\n")
        if head.strip() == of:
            return body.strip()
    return ""


# The feed's entry for each installer's ending, as Tauri's updater names the app it runs in.
ENTRIES = {".exe": "windows-x86_64", ".AppImage": "linux-x86_64-appimage", ".deb": "linux-x86_64-deb"}


def entry(installer: str) -> str:
    for ending, name in ENTRIES.items():
        if installer.endswith(ending):
            return name
    raise SystemExit(f"{installer}: not an installer the feed knows ({', '.join(ENTRIES)})")


def feed(pairs: list[tuple[str, str]]) -> dict:
    number = version()
    return {
        "version": number,
        "notes": notes(number),
        "pub_date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "platforms": {
            entry(installer): {"signature": pathlib.Path(installer + ".sig").read_text(encoding="utf-8").strip(), "url": url}
            for installer, url in pairs
        },
    }


def main() -> None:
    out, rest = sys.argv[1], sys.argv[2:]
    if not rest or len(rest) % 2:
        raise SystemExit(__doc__)
    pairs = list(zip(rest[::2], rest[1::2]))
    pathlib.Path(out).write_text(json.dumps(feed(pairs), indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
