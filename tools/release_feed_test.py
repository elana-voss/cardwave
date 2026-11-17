"""Tests of tools/release_feed.py: python tools/release_feed_test.py."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from release_feed import feed


def test_each_installer_is_the_entry_its_kind_of_app_asks_for():
    with tempfile.TemporaryDirectory() as tmp:
        names = ["Cardwave_1_x64-setup.exe", "Cardwave_1_amd64.AppImage", "Cardwave_1_amd64.deb"]
        pairs = []
        for name in names:
            (Path(tmp) / f"{name}.sig").write_text(f"sig of {name}\n", encoding="utf-8")
            pairs.append((str(Path(tmp) / name), f"https://example.org/{name}"))
        platforms = feed(pairs)["platforms"]
    assert platforms == {
        "windows-x86_64": {"signature": "sig of Cardwave_1_x64-setup.exe", "url": "https://example.org/Cardwave_1_x64-setup.exe"},
        "linux-x86_64-appimage": {"signature": "sig of Cardwave_1_amd64.AppImage", "url": "https://example.org/Cardwave_1_amd64.AppImage"},
        "linux-x86_64-deb": {"signature": "sig of Cardwave_1_amd64.deb", "url": "https://example.org/Cardwave_1_amd64.deb"},
    }


if __name__ == "__main__":
    test_each_installer_is_the_entry_its_kind_of_app_asks_for()
    print("ok")
