"""Tests of tools/plural_many.py: python tools/plural_many_test.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plural_many import add_many


def test_every_nested_select_gets_many():
    text = "\n".join([
        "importing-some = { $kind ->",
        "    [lorebook] { $count ->",
        "        [one] one lorebook",
        "       *[other] { $count } lorebooks",
        "    }",
        "   *[file] { $count ->",
        "        [one] one file",
        "       *[other] { $count } files",
        "    }",
        "}",
        "",
    ])
    new, added, by_hand = add_many(text)
    assert added == 2 and not by_hand, (added, by_hand)
    assert new.count("[many]") == 2, new


def test_a_select_holding_many_is_left():
    text = "n = { $count ->\n    [one] one\n    [many] many\n   *[other] other\n}\n"
    assert add_many(text) == (text, 0, [])


def test_a_select_not_plural_is_left():
    text = "n = { $kind ->\n    [a] a\n   *[other] other\n}\n"
    assert add_many(text) == (text, 0, [])


if __name__ == "__main__":
    for name, test in sorted(globals().items()):
        if name.startswith("test_"):
            test()
    print("plural_many: tests passed")
