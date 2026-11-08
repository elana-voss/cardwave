"""Tests of tools/words.py: python tools/words_test.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from words import entries, marks, table

FTL = "\n".join([
    "### The file's head",
    "## The Trash (views/trash.ts)",
    "trash-delete = Delete forever",
    "trash-remove = Remove",
    "    .title = Remove the card",
    "## A chat",
    "chat-count = { $count ->",
    "    [one] 1 character",
   "   *[other] { $count } characters",
    "}",
    "chat-remove = Remove",
    "chat-ask = Ask the AI which model",
    "",
])


def test_rows_their_screen_and_text():
    rows = entries(FTL, "en.ftl")
    keys = [r["key"] for r in rows]
    assert keys == ["trash-delete", "trash-remove", "trash-remove.title", "chat-count", "chat-remove", "chat-ask"], keys
    assert rows[0]["screen"] == "en.ftl: The Trash (views/trash.ts)", rows[0]
    assert rows[3]["text"] == "{ $count -> [one] 1 character *[other] { $count } characters }", rows[3]


def test_marks_duplicates_and_the_pairs():
    rows = entries(FTL, "en.ftl")
    out = table(rows)
    assert "| trash-remove | en.ftl: The Trash (views/trash.ts) | Remove | duplicate (2); delete-remove-discard |" in out, out
    assert marks("Ask the AI which model") == ["model-ai"], marks("Ask the AI which model")
    assert marks("Delete the card") == ["delete-remove-discard", "card-character"]
    assert marks("Cards") == ["card-character"] and marks("Discarded") == ["delete-remove-discard"]
    assert marks("Carding") == [], marks("Carding")


if __name__ == "__main__":
    test_rows_their_screen_and_text()
    test_marks_duplicates_and_the_pairs()
    print("words: 2 tests passed")
