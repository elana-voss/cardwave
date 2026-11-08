"""Writes the updater's feed `latest.json` for a release (.github/workflows/installer.yml).

Usage: python tools/release_feed.py <installer.exe> <download url> <out.json>

The version is the workspace's (`Cargo.toml`), the notes that version's part of
`web/public/whats-new.md` (under `# <version>`), the signature the installer's
`.sig` beside it, which `tauri signer sign` wrote. The app's updater
(desktop/src/update.rs) reads the file from the latest release.
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


def main() -> None:
    installer, url, out = sys.argv[1:4]
    signature = pathlib.Path(installer + ".sig").read_text(encoding="utf-8").strip()
    number = version()
    feed = {
        "version": number,
        "notes": notes(number),
        "pub_date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "platforms": {"windows-x86_64": {"signature": signature, "url": url}},
    }
    pathlib.Path(out).write_text(json.dumps(feed, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
