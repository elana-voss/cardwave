"""Tests of tools/tickets.py: python tools/tickets_test.py."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from tickets import FIELDS, index_text, load, main, new, problems, slug


def ticket(id, **over):
    """A ticket as `load` returns it: its id, its fields (all present, empty by default), its body."""
    fields = {f: "" for f in FIELDS}
    fields.update(title=id, kind="milestone", status="To do", priority="High", assignee="Claude", updated="2026-11-14")
    fields.update(over)
    return {"id": id, "fields": fields, "body": ""}


def table(*tickets):
    return {t["id"]: t for t in tickets}


def test_a_parent_with_an_open_child_cannot_be_done():
    parent = ticket("2026-11-01-001-big", status="Done", priority="Low", number="1")
    child = ticket("2026-11-01-001a-part", parent=parent["id"], number="1a")
    found = problems(table(parent, child))
    assert any("Done" in p and "001a-part" in p for p in found), found
    child["fields"].update(status="Won't do", priority="Low")
    assert problems(table(parent, child)) == [], problems(table(parent, child))


def test_an_unknown_status_or_a_missing_field_fails():
    bad = ticket("2026-11-01-002-x", status="Finished")
    assert any("status" in p and "Finished" in p for p in problems(table(bad))), problems(table(bad))
    gone = ticket("2026-11-01-003-y")
    del gone["fields"]["kind"]
    assert any("kind" in p for p in problems(table(gone))), problems(table(gone))
    nowhere = ticket("2026-11-01-004-z", parent="2026-01-01-nothing", waits_on="owner, 2026-01-01-none")
    found = problems(table(nowhere))
    assert any("2026-01-01-nothing" in p for p in found) and any("2026-01-01-none" in p for p in found), found


def test_the_index_sorts_and_nests_and_goes_stale():
    a = ticket("2026-11-02-010-later", status="To do", priority="Low")
    b = ticket("2026-11-02-011-now", status="In progress", priority="Medium")
    c = ticket("2026-11-02-012-asks", status="Planned", priority="Medium", waits_on="owner")
    kid = ticket("2026-11-02-011a-part", status="To do", priority="High", parent=b["id"], number="11a")
    old = ticket("2026-10-01-001-old", status="Done", priority="Low", number="1")
    tickets = table(a, b, c, kid, old)
    text = index_text(tickets)
    waiting = text.split("## Open")[0]
    assert "012-asks" in waiting and "010-later" not in waiting, waiting
    opened = text.split("## Open")[1].split("## Closed")[0]
    assert opened.index("011-now") < opened.index("011a-part") < opened.index("012-asks") < opened.index("010-later"), opened
    assert "↳ [" in [ln for ln in opened.splitlines() if "011a-part" in ln][0]
    assert "001-old" in text.split("## Closed")[1] and "001-old" not in opened
    assert problems(tickets, index=text) == []
    assert any("INDEX" in p for p in problems(tickets, index=text + "x"))


def test_new_writes_a_ticket_from_the_template():
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        (folder / "TEMPLATE.md").write_text("---\n" + "".join(f"{f}: \n" for f in FIELDS) + "---\n\n## Requirement\n", encoding="utf-8")
        first = new("A new thing: with a colon", None, folder, "2026-11-14")
        assert first == "2026-11-14-a-new-thing-with-a-colon", first
        child = new("Its part", first, folder, "2026-11-14")
        loaded = load(folder)
        assert loaded[child]["fields"]["parent"] == first and loaded[first]["fields"]["title"] == "A new thing: with a colon"
        assert loaded[first]["fields"]["status"] == "To do"


def test_a_bad_status_or_a_missing_title_still_lists_every_problem():
    bad = ticket("2026-11-01-005-a", status="Dnoe")
    asks = ticket("2026-11-01-006-b", title="", priority="Low", waits_on="owner")
    found = problems(table(bad, asks))
    assert any("Dnoe" in p for p in found) and any("title" in p for p in found), found


def test_two_tickets_naming_each_other_as_parent_fail():
    a = ticket("2026-11-01-007-a", parent="2026-11-01-008-b")
    b = ticket("2026-11-01-008-b", parent="2026-11-01-007-a")
    assert any("back to itself" in p for p in problems(table(a, b))), problems(table(a, b))


def test_new_defaults_and_refuses_bad_values():
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        (folder / "TEMPLATE.md").write_text("---\n" + "".join(f"{f}: \n" for f in FIELDS) + "---\n\n## Requirement\n", encoding="utf-8")
        (folder / "INDEX.md").write_text("x", encoding="utf-8")
        id = new("Plain", None, folder, "2026-11-14")
        assert problems(load(folder)) == [], problems(load(folder))
        for args in ({"kind": "epic"}, {"priority": "Never"}, {"parent": "TEMPLATE"}, {"parent": "INDEX"}):
            try:
                new("Other", args.pop("parent", None), folder, "2026-11-14", **args)
            except ValueError:
                continue
            raise AssertionError(f"accepted {args}")
        assert id


def test_the_assignee_is_checked_shown_and_set_by_new():
    odd = ticket("2026-11-01-009-a", assignee="Bob")
    assert any("assignee" in p and "Bob" in p for p in problems(table(odd))), problems(table(odd))
    design = ticket("2026-11-01-010-b", assignee="Claude Design")
    assert problems(table(design)) == [], problems(table(design))
    assert "| Claude Design |" in index_text(table(design)).split("## Closed")[0]
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        (folder / "TEMPLATE.md").write_text("---\n" + "".join(f"{f}: \n" for f in FIELDS) + "---\n\n## Requirement\n", encoding="utf-8")
        plain = new("Plain", None, folder, "2026-11-14")
        drawn = new("Drawn", None, folder, "2026-11-14", assignee="Claude Design")
        loaded = load(folder)
        assert loaded[plain]["fields"]["assignee"] == "Claude" and loaded[drawn]["fields"]["assignee"] == "Claude Design"
        try:
            new("Other", None, folder, "2026-11-14", assignee="Bob")
        except ValueError:
            return
        raise AssertionError("accepted assignee Bob")


def test_every_ticket_needs_one_of_the_four_priorities():
    for bad in ("", "Must", "Urgent"):
        found = problems(table(ticket("2026-11-01-005-p", status="Done", priority=bad)))
        assert any("priority" in p for p in found), (bad, found)
    assert not any("priority" in p for p in problems(table(ticket("2026-11-01-006-q", status="Done", priority="Critical"))))


def test_a_slug_keeps_a_word_ending_at_60():
    title = "a" * 55 + " word more"
    assert slug(title) == "a" * 55 + "-word", slug(title)
    assert slug("x" * 30 + " " + "y" * 40) == "x" * 30


def test_new_refuses_a_title_starting_with_a_dash():
    with tempfile.TemporaryDirectory() as tmp:
        import tickets
        here, tickets.HERE = tickets.HERE, Path(tmp)
        try:
            assert main(["tickets.py", "new", "--help"]) == 2
            assert list(Path(tmp).iterdir()) == []
        finally:
            tickets.HERE = here


def test_the_audit_comes_after_every_fifth_milestone():
    done = [ticket(f"2026-11-01-{n}-m", number=str(n), status="Done") for n in range(1, 6)]
    sixth = ticket("2026-11-01-6-m", number="6", status="In progress")
    assert problems(table(*done)) == [], problems(table(*done))
    assert any("audit" in p for p in problems(table(*done, sixth))), problems(table(*done, sixth))
    audit = ticket("2026-11-01-audit", kind="audit", waits_on="[2026-11-01-5-m]")
    assert any("audit" in p for p in problems(table(*done, sixth, audit))), "a milestone started before its audit is Done"
    audit["fields"]["status"] = "Done"
    assert problems(table(*done, sixth, audit)) == [], problems(table(*done, sixth, audit))
    loose = ticket("2026-11-01-loose", kind="audit", waits_on="[owner]")
    assert any("audit" in p and "loose" in p for p in problems(table(loose))), problems(table(loose))
    odd = ticket("2026-11-01-7-b", kind="backlog", number="7", status="Done")
    assert any("milestone" in p for p in problems(table(odd))), "a numbered backlog item would slip past the count"


if __name__ == "__main__":
    test_a_parent_with_an_open_child_cannot_be_done()
    test_an_unknown_status_or_a_missing_field_fails()
    test_the_index_sorts_and_nests_and_goes_stale()
    test_new_writes_a_ticket_from_the_template()
    test_a_bad_status_or_a_missing_title_still_lists_every_problem()
    test_two_tickets_naming_each_other_as_parent_fail()
    test_new_defaults_and_refuses_bad_values()
    test_the_assignee_is_checked_shown_and_set_by_new()
    test_a_slug_keeps_a_word_ending_at_60()
    test_new_refuses_a_title_starting_with_a_dash()
    test_the_audit_comes_after_every_fifth_milestone()
    print("tickets: 9 tests passed")
