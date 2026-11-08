"""Tests of tools/ftl_set.py: python tools/ftl_set_test.py."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ftl_set import apply


def test_sets_a_message_and_a_variant_in_every_language_and_renames_a_key():
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        for code in ("en", "de"):
            (folder / f"{code}.errors.ftl").write_bytes(b"a = { $x ->\r\n    [y] Y\r\n   *[other] O\r\n}\r\nb = B\r\n")
        select = "{ $z ->\n   *[other] Z\n}"
        steps = [
            {"part": ".errors", "key": "a", "text": {"en": select, "de": select}},
            {"rename": "b", "to": "c"},
            {"part": ".errors", "key": "a", "variant": "other", "text": {"en": "-", "de": "W"}},
        ]
        apply(steps, folder)
        assert (folder / "en.errors.ftl").read_bytes() == b"a = { $z ->\r\n   *[other] -\r\n}\r\nc = B\r\n"
        assert (folder / "de.errors.ftl").read_bytes() == b"a = { $z ->\r\n   *[other] W\r\n}\r\nc = B\r\n"


def test_adds_a_message_after_another_and_removes_one():
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        for code in ("en", "de"):
            (folder / f"{code}.ftl").write_bytes(b"a = { $x ->\r\n   *[other] O\r\n}\r\nb = B\r\n")
        steps = [
            {"part": "", "key": "n", "after": "a", "text": {"en": "N", "de": "{ $y ->\n   *[other] M\n}"}},
            {"remove": "b"},
        ]
        apply(steps, folder)
        assert (folder / "en.ftl").read_bytes() == b"a = { $x ->\r\n   *[other] O\r\n}\r\nn = N\r\n"
        assert (folder / "de.ftl").read_bytes() == b"a = { $x ->\r\n   *[other] O\r\n}\r\nn = { $y ->\r\n   *[other] M\r\n}\r\n"


if __name__ == "__main__":
    for name, test in sorted(globals().items()):
        if name.startswith("test_"):
            test()
    print("ftl_set: tests passed")
