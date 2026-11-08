"""The order, the figures against aimed needs, agreement and the split of tools/needs_measure.py, on made-up data. Run: python tools/needs_measure_test.py
(tools/check.sh's `needs-tool`)."""

import argparse
import http.client
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import needs_measure as tool

NAMES = ["sex", "truth"]


def test_the_classifier_prompt_has_no_rust_escapes():
    assert '\\"' not in tool.classify_prompt()


def test_the_order_is_level_then_title():
    same = [{"id": i, "title": t, "levels": {"sex": 2}, "ranks": {}} for i, t in (("x", "Zoë"), ("y", "ÉLAN"), ("z", "alma"))]
    assert [row["id"] for row in tool.in_order(same, "sex", 2)] == ["z", "y", "x"]


def test_a_characters_cards_stay_in_one_half():
    assert tool.character("t", "woman-p05") == tool.character("t", "cast-p05") == "t-p05"
    assert tool.character("t", "man-p05") != tool.character("n", "man-p05")
    stems = [f"{user}-p{number:02}" for number in range(20) for user in ("anyone", "man", "woman")]
    cards = {f"t-{stem}": {"character": tool.character("t", stem), "card": {}} for stem in stems}
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder)
        (out / "cards.json").write_text(json.dumps(cards), encoding="utf-8")
        args = argparse.Namespace(out=folder)
        (out / "labels.txt").write_text("\n".join(f"{card} -" for card in list(cards)[1:]), encoding="utf-8")
        for refused in (True, False):
            try:
                tool.split(args)
                assert not refused
            except SystemExit:
                assert refused  # A card with no label.
            (out / "labels.txt").write_text("\n".join(f"{card} -" for card in cards), encoding="utf-8")
        tune, held = tool.half(out, "tune"), tool.half(out, "held")
        assert not tune & held and (tune | held) == set(cards) == tool.half(out, "all")
        assert abs(len(tune) - len(held)) <= 6 and held
        assert not {cards[card]["character"] for card in tune} & {cards[card]["character"] for card in held}
        try:
            tool.split(args)
            raise AssertionError("a second split")
        except SystemExit:
            pass


def test_a_card_labelled_out_is_never_sent_and_any_form_may_name_nothing():
    labels = {"a": {"sex": 2}, "b": "out", "c": {}}
    assert tool.to_send(labels, {"a", "b", "c", "no label"}) == ["a", "c"]
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder)
        answer = json.dumps({"verdict": "classified", "needs": []})
        rows = [{"id": "a", "arm": arm, "answer": answer} for arm in ("own", "b", "b@some/model")]
        (out / "results.jsonl").write_text("\n".join(json.dumps(row) for row in rows), encoding="utf-8")
        found = tool.latest(out)
        assert [found[("a", arm)]["state"] for arm in ("own", "b", "b@some/model")] == ["asked", "asked", "asked"]


def test_aimed_needs_come_from_the_index_and_the_test_cards_have_none():
    entries = [{"file": "man-p01.json", "aimed_at": "sex"}, {"file": "woman-p02.json", "aimed_at": "to be told the truth"}]
    assert tool.aimed_from(entries) == {"n-man-p01": "sex", "n-woman-p02": "truth"}
    try:
        tool.aimed_from([{"file": "x.json", "aimed_at": "a need not on the list"}])
        raise AssertionError("an aim off the list")
    except KeyError:
        pass


def aimed_rows(count: int, levels, ranks=None) -> tuple[list[dict], dict]:
    """Cards named so that the aimed ones sort last by title, each with the same levels."""
    rows = [
        {"id": f"c{i:03}", "title": f"{i:03}", "levels": levels(i), "ranks": ranks(i) if ranks else {}}
        for i in range(count)
    ]
    return rows, {f"c{i:03}": "sex" for i in range(count - 5, count)}


def test_marking_every_need_level_three_passes_found_and_fails_first_ten():
    rows = [
        {"id": f"c{need}{i}", "title": f"{need}{i}", "levels": dict.fromkeys(NAMES, 3), "ranks": {}}
        for need in NAMES
        for i in range(20)
    ]
    aimed = {row["id"]: row["id"][1:].rstrip("0123456789") for row in rows}
    result = tool.truth_figures(rows, aimed, NAMES, 2, by_rank=False)
    assert result["found"] == 1.0 and result["first_ten"] == 0.25 and result["shown"] == {"sex": 1.0, "truth": 1.0}


def test_rank_breaks_a_level_only_where_asked_and_a_higher_level_still_wins():
    rows, aimed = aimed_rows(
        20,
        lambda i: {"sex": 2},
        lambda i: {"sex": 0 if i >= 15 else 3},
    )
    by_title = tool.truth_figures(rows, aimed, NAMES, 2, by_rank=False)
    by_rank = tool.truth_figures(rows, aimed, NAMES, 2, by_rank=True)
    assert by_title["found"] == by_rank["found"] == 1.0
    assert by_title["first_ten"] == 0.0 and by_rank["first_ten"] == 1.0
    assert by_rank["per_need"]["sex"] == (5, 5, 5) and by_title["per_need"]["sex"] == (5, 5, 0)
    row_high = {"id": "h", "title": "h", "levels": {"sex": 3}, "ranks": {"sex": 9}}
    row_low = {"id": "l", "title": "l", "levels": {"sex": 2}, "ranks": {"sex": 0}}
    assert [row["id"] for row in tool.in_order([row_low, row_high], "sex", 2, by_rank=True)] == ["h", "l"]


def test_a_card_not_answered_is_not_found_and_a_cut_off_shortens_what_is_shown():
    rows = [
        {"id": "a", "title": "a", "levels": {"sex": 3}, "ranks": {}},
        {"id": "b", "title": "b", "levels": {"sex": 2}, "ranks": {}},
        {"id": "c", "title": "c", "levels": {}, "ranks": {}},
        {"id": "t", "title": "t", "levels": {"sex": 3}, "ranks": {}},
    ]
    aimed = {"a": "sex", "b": "sex", "c": "sex"}
    at_two, at_three = (tool.truth_figures(rows, aimed, NAMES, cut, by_rank=False) for cut in (2, 3))
    assert abs(at_two["found"] - 2 / 3) < 1e-9 and abs(at_three["found"] - 1 / 3) < 1e-9
    assert at_two["shown"]["sex"] == 0.75 and at_three["shown"]["sex"] == 0.5  # A test-card takes a place, unscored.


def test_agreement_is_what_two_arms_share_of_what_either_shows():
    one = [{"id": "a", "levels": {"sex": 3, "truth": 2}}, {"id": "b", "levels": {"sex": 2}}]
    two = [{"id": "a", "levels": {"sex": 3}}, {"id": "b", "levels": {"truth": 3}}]
    assert tool.agreement(one, two, 2) == 0.25 and tool.agreement(one, two, 3) == 0.5
    assert tool.agreement([{"id": "a", "levels": {}}], [{"id": "a", "levels": {}}], 2) == 0.0


def test_ranks_are_the_stated_order_of_what_is_above_nothing_and_the_new_form_may_name_nothing():
    answer = {"needs": [{"need": "truth", "level": 3}, {"need": "keep_company", "level": 0}, {"need": "sex", "level": 3}, {"need": "truth", "level": 1}]}
    assert tool.read_ranks(answer, set(NAMES + ["keep_company"])) == {"truth": 0, "sex": 1}
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder)
        row = lambda card, answer: json.dumps({"id": card, "arm": "strength", "answer": json.dumps(answer)}) + "\n"
        (out / "results.jsonl").write_text(row("a", {"verdict": "classified", "needs": []}) + row("b", {"needs": []}), encoding="utf-8")
        assert tool.latest(out)[("a", "strength")]["state"] == "asked"
        assert tool.latest(out)[("b", "strength")]["state"] == "unread"


def test_a_set_from_a_folder_needs_no_label_and_its_truth_is_its_own_aimed_at():
    card = {"name": "Made Up", "description": "words " * 50, "first_mes": "hello"}
    entries = [{"file": "x-p01.json", "aimed_at": "to be told the truth"}, {"file": "x-p02.json", "aimed_at": "sex"}, {"file": "short.json", "aimed_at": "sex"}]
    with tempfile.TemporaryDirectory() as folder:
        source, out = Path(folder) / "new", Path(folder) / "out"
        source.mkdir()
        (source / "index.json").write_text(json.dumps(entries), encoding="utf-8")
        for entry in entries:
            made = {"name": "No"} if entry["file"] == "short.json" else card
            (source / entry["file"]).write_text(json.dumps(made), encoding="utf-8")
        tool.set_cards(argparse.Namespace(out=str(out), source=str(source)))
        assert tool.aimed_of(out) == {"n-x-p01": "truth", "n-x-p02": "sex"}
        assert tool.sendable(out, tool.half(out, "all")) == ["n-x-p01", "n-x-p02"]
    with tempfile.TemporaryDirectory() as folder:  # An old set still goes by its labels, and by the needs-set's index.
        out = Path(folder)
        (out / "labels.txt").write_text("a sex2\nb out\n", encoding="utf-8")
        assert tool.sendable(out, {"a", "b", "c"}) == ["a"]


def test_an_arm_is_named_by_the_prompts_own_words_so_a_changed_prompt_never_replays_old_answers():
    one, two = tool.arm_of("xiaomi/mimo-v2.6-flash", "words"), tool.arm_of("xiaomi/mimo-v2.6-flash", "other words")
    assert one.startswith("app-") and one != two and "@" not in one
    assert tool.arm_of("some/model", "words", 2) == one + "#2@some/model"
    assert tool.form_of(one + "#2@some/model") == one
    for ranked in (one, one + "#1@some/model", "served-1234abcd@some/model", "strength@some/model"):
        assert tool.ranked(ranked)
    assert not tool.ranked("b@some/model") and not tool.ranked("own")


def test_shape_says_how_many_needs_a_card_gets_and_how_many_of_them_at_the_top():
    rows = [
        {"answered": True, "levels": {"sex": 3, "truth": 3, "a": 2, "b": 2, "c": 2}},
        {"answered": True, "levels": {"sex": 3, "truth": 1}},
        {"answered": True, "levels": {}},
        {"answered": False, "levels": {}},
    ]
    assert tool.shape(rows) == {"cards": 3, "mean": 2.0, "median": 1, "at_five": 1, "top_share": 0.5, "one_or_two_top": 2}
    assert tool.shape([])["cards"] == 0


def test_the_sample_is_thirty_of_the_tune_half_the_same_each_time():
    cards = {f"n-man-p{i:03}": {"character": f"n-p{i:03}", "card": {}} for i in range(80)}
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder)
        (out / "cards.json").write_text(json.dumps(cards), encoding="utf-8")
        (out / "labels.txt").write_text("\n".join(f"{card} -" for card in cards), encoding="utf-8")
        tool.split(argparse.Namespace(out=folder))
        drawn = tool.sample_of(out)
        assert len(drawn) == len(set(drawn)) == 30 and drawn == tool.sample_of(out)
        assert set(drawn) <= tool.half(out, "tune")
        assert drawn != sorted(drawn)  # The first 20 are as random as the 30.


def test_steadiness_counts_identical_cards_and_the_first_ten_places_that_move():
    row = lambda card, title, levels, ranks=None, answered=True: {"id": card, "title": title, "levels": levels, "ranks": ranks or {}, "answered": answered}
    one = [row("a", "a", {"sex": 3, "truth": 1}), row("b", "b", {"sex": 2}), row("c", "c", {"sex": 2}), row("u", "u", {}, answered=False), row("v", "v", {})]
    two = [row("a", "a", {"sex": 2}), row("b", "b", {"sex": 2, "truth": 2}), row("c", "c", {"sex": 3}), row("u", "u", {}, answered=False), row("v", "v", {})]
    result = tool.steadiness(one, two, NAMES)
    # a stays (the level below the cut-off is not counted), b gains a need, c stays, u was not read, v names nothing both times.
    assert (result["cards"], result["identical"]) == (5, 3)
    # sex: a b c against c a b, three places move; truth: nothing against b, one.
    assert (result["moved"], result["filled"]) == (4, 4)


def test_what_the_running_app_shows_of_a_card_reads_as_an_answer():
    needs = [{"need": "truth", "level": 2, "quote": "", "rank": 1}, {"need": "sex", "level": 3, "quote": "", "rank": 0}]
    rows = [
        tool.served_row("a", "served-x", {"state": "found", "needs": needs}),
        tool.served_row("b", "served-x", {"state": "zero", "needs": []}),
        tool.served_row("c", "served-x", {"state": "refused", "needs": []}),
        tool.served_row("d", "served-x", {"state": "failed", "needs": []}),
    ]
    assert "failed" in rows[3] and all("failed" not in row for row in rows[:3])
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder)
        (out / "results.jsonl").write_text("\n".join(json.dumps(row) for row in rows), encoding="utf-8")
        found = tool.latest(out)
    assert found[("a", "served-x")]["levels"] == {"sex": 3, "truth": 2} and found[("a", "served-x")]["ranks"] == {"sex": 0, "truth": 1}
    assert [found[(card, "served-x")]["state"] for card in "bcd"] == ["asked", "refused", "failed"]


def test_the_card_goes_as_the_app_sends_it():
    card = {"title": "Mé", "tags": ["a"], "characters": [{"name": "Mé", "description": "x"}]}
    text = tool.messages_of("p", card)[1]["content"]
    assert text.startswith('<card_to_read>\n{"title": "Mé", "tags": ["a"], "characters": [{"name": "Mé", "description": "x"}]}\n')


def test_a_stream_reads_as_one_answer():
    lines = [
        b'data: {"choices":[{"delta":{"content":"{\\"a\\""}}]}\n',
        b"\n",
        b": comment\n",
        b'data: {"choices":[{"delta":{"content":":1}"},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":2}}\n',
        b"data: [DONE]\n",
    ]
    reply = tool.reply_of_stream(lines)
    assert reply["choices"][0] == {"finish_reason": "stop", "message": {"content": '{"a":1}'}}
    assert reply["usage"]["prompt_tokens"] == 3
    assert "failed" in tool.reply_of_stream([b'data: {"error":{"message":"no"}}\n'])


def test_a_stream_cut_short_is_a_failed_ask_not_the_end_of_the_run():
    class Cut:
        def __enter__(self):
            raise http.client.IncompleteRead(b"")

        def __exit__(self, *_):
            return False

    real = tool.urllib.request.urlopen
    tool.urllib.request.urlopen = lambda *_, **__: Cut()
    try:
        assert tool.call([], "m", "k", attempts=1) == {"failed": "IncompleteRead"}
    finally:
        tool.urllib.request.urlopen = real


for name, test in list(globals().items()):
    if name.startswith("test_"):
        test()
print("ok")
