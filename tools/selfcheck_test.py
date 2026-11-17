"""Tests of tools/selfcheck.py: python tools/selfcheck_test.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from selfcheck import closed_report, trials
from tickets_test import table, ticket


def plan(*lines):
    return "# Plan\n\n## 12. Trials (self-optimization)\n\n" + "\n".join(lines) + "\n\n## 13. Next\n- Open, 2026-01-01: not a trial\n"


def test_trials_want_the_actual_of_a_done_milestone_since_2026_11_15():
    old = ticket("2026-11-14-1-old", status="Done", number="1")
    new = ticket("2026-11-15-2-new", status="Done", number="2")
    assert trials(table(old, new), plan()) == ["2026-11-15-2-new: Done without its actual tokens"], trials(table(old, new), plan())
    new["fields"]["actual"] = "3.1"
    assert trials(table(old, new), plan()) == []


def test_a_trial_open_past_five_closed_milestones_fails():
    done = [ticket(f"2026-11-15-{n}-m", status="Done", number=str(n), actual="1", updated="2026-11-16") for n in range(1, 7)]
    parent = ticket("2026-11-15-7-p", status="Done", number="7", actual="1", updated="2026-11-16")
    part = ticket("2026-11-15-7a-part", status="Done", number="7a", actual="1", parent=parent["id"], updated="2026-11-15")
    line = "- Open, 2026-11-15: a trial."
    assert any("2026-11-15: a trial" in p for p in trials(table(*done[:6], parent, part), plan(line)))
    assert trials(table(*done[:5], parent, part), plan(line)) == [], "a parent with parts and a part dated on the day do not count"


def test_more_than_ten_open_trials_fail():
    lines = [f"- Open, 2026-11-17: trial {n}." for n in range(11)]
    assert any("11 trials open" in p for p in trials({}, plan(*lines))), trials({}, plan(*lines))
    assert trials({}, plan(*lines[:10])) == []


def test_the_replies_section_may_not_grow_past_the_reply_trial():
    line = "- Open, 2026-11-17: the reply rules rewritten. Replies to the owner: 585 words."
    assert trials({}, plan(line), replies_words=585) == []
    assert any("586 words" in p for p in trials({}, plan(line), replies_words=586))


def test_a_trial_never_closes_unmeasured():
    for line in ("- Closed, unmeasured, 2026-11-17: x.", "- Closed, unmeasurable, 2026-11-17: x."):
        assert any("Kept or Reverted" in p for p in trials({}, plan(line))), trials({}, plan(line))
    assert trials({}, plan("- Kept, 2026-11-17: x. Figure: 1. Before: 2.")) == []


def test_the_last_closed_milestone_is_reported_from_its_agents():
    old = ticket("2026-11-15-7-old", status="Done", number="7", actual="1", updated="2026-11-15")
    last = ticket("2026-11-16-8-last", status="Done", number="8", actual="2", estimate="3", updated="2026-11-16")
    rows = [{"id": "a", "name": "8 Last: build by Opus 5.5 medium", "tokens": "500000", "end": "handed over"},
            {"id": "a", "name": "8 Last: build by Opus 5.5 medium", "tokens": "1000000", "end": "handed over"},
            {"id": "b", "name": "8b Last: build by Opus 5.5 medium", "tokens": "1500000", "end": "reported"},
            {"id": "c", "name": "80 Other: build by Opus 5.5 medium", "tokens": "9000000", "end": "reported"}]
    assert closed_report(table(old, last), rows) == "8 2026-11-16-8-last: 2 agents, 1 handed over, 2.5 million tokens against 3 estimated"


if __name__ == "__main__":
    test_trials_want_the_actual_of_a_done_milestone_since_2026_11_15()
    test_a_trial_open_past_five_closed_milestones_fails()
    test_more_than_ten_open_trials_fail()
    test_the_replies_section_may_not_grow_past_the_reply_trial()
    test_a_trial_never_closes_unmeasured()
    test_the_last_closed_milestone_is_reported_from_its_agents()
    print("selfcheck: 6 tests passed")
