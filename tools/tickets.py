"""The tickets of docs/tickets/: python tools/tickets.py new "<title>" [--parent ID] [--kind K] [--priority P] [--assignee A] | index | check.

A ticket is a file `YYYY-MM-DD-<slug>.md` (its id: the name without `.md`), a front matter of flat `key: value` lines
(a list is `[a, b]`; a line starting with `#` is a comment) and a body of `##` sections; docs/tickets/TEMPLATE.md holds the
fields and what each may hold. `index` writes INDEX.md (generated, never edited by hand); `check` fails on a missing or
unknown field, a value outside its list, a parent or waits-on that names no ticket, a parent Done with an open child, a
priority missing or not Critical, High, Medium or Low (closed tickets too), a sixth milestone started past the last audit
(kind audit) or one started past an audit not yet Done (`audit_due`), and a stale INDEX.md. Standard library only; the front matter is parsed by hand.
Trap: a title is one line and may hold colons (only the first ": " of a line splits), but no newline; one starting
with "-" (`new --help`) is refused with the usage, as no ticket is meant by it.
"""

import datetime
import re
import sys
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent / "docs" / "tickets"
FIELDS = ["title", "kind", "status", "priority", "assignee", "number", "parent", "waits_on", "estimate", "actual", "cost", "commits", "design", "updated"]
KINDS = ["milestone", "backlog", "defect", "question", "audit"]
STATUSES = ["In progress", "Blocked", "Planned", "To do", "Done", "Won't do"]  # the open ones in index order, then the closed
PRIORITIES = ["Critical", "High", "Medium", "Low"]
ASSIGNEES = ["Claude", "Claude Design", "owner"]  # who works the ticket
CLOSED = ("Done", "Won't do")
ID = re.compile(r"^\d{4}-\d\d-\d\d-[a-z0-9]+(-[a-z0-9]+)*$")


def not_one_of(key, value, allowed):
    """The complaint when `value` is not among `allowed`, else None; shared by `problems` and `new`."""
    if value not in allowed:
        return f"{key} {value!r} is not one of {', '.join(allowed)}"
    return None


def parse(text):
    """(fields, body) of a ticket's text; the fields as the strings they are written as."""
    if not text.startswith("---\n"):
        return {}, text
    head, _, body = text[4:].partition("\n---\n")
    fields = {}
    for line in head.splitlines():
        if line.startswith("#") or not line.strip():
            continue
        key, _, value = line.partition(":")
        fields[key.strip()] = value.strip()
    return fields, body


def items(value):
    """The entries of `[a, b]` or `a, b`; none for an empty value."""
    return [x.strip() for x in value.strip().strip("[]").split(",") if x.strip()]


def load(folder=HERE):
    """id -> {"id", "fields", "body"} of every ticket file in the folder (not TEMPLATE.md, INDEX.md)."""
    tickets = {}
    for path in sorted(Path(folder).glob("*.md")):
        if path.name in ("TEMPLATE.md", "INDEX.md"):
            continue
        fields, body = parse(path.read_text(encoding="utf-8"))
        tickets[path.stem] = {"id": path.stem, "fields": fields, "body": body}
    return tickets


def problems(tickets, index=None):
    """The list of what is wrong with the tickets (and, given the INDEX.md's text, with it)."""
    found = []
    children = {}
    for id, t in tickets.items():
        f = t["fields"]
        if not ID.match(id):
            found.append(f"{id}: the file name is not YYYY-MM-DD-<slug>.md")
        for key in FIELDS:
            if key not in f:
                found.append(f"{id}: the field {key} is missing")
        for key in f:
            if key not in FIELDS:
                found.append(f"{id}: the field {key} is not in the template")
        if not f.get("title"):
            found.append(f"{id}: the title is empty")
        for key, allowed in (("kind", KINDS), ("status", STATUSES), ("assignee", ASSIGNEES)):
            if key in f and (bad := not_one_of(key, f[key], allowed)):
                found.append(f"{id}: {bad}")
        waits = items(f.get("waits_on", ""))
        if "priority" in f and (bad := not_one_of("priority", f["priority"], PRIORITIES)):
            found.append(f"{id}: {bad}")
        for key in ("estimate", "actual", "cost"):
            if f.get(key, "") and not re.fullmatch(r"\d+(\.\d+)?", f[key]):
                found.append(f"{id}: {key} {f[key]!r} is not a number")
        if f.get("updated") is not None and not re.fullmatch(r"\d{4}-\d\d-\d\d", f["updated"]):
            found.append(f"{id}: updated {f['updated']!r} is not a date")
        for w in waits:
            if w != "owner" and w not in tickets:
                found.append(f"{id}: waits_on names {w}, which is no ticket")
        parent = f.get("parent", "")
        if parent:
            if parent == id or parent not in tickets:
                found.append(f"{id}: parent {parent} is no other ticket")
            else:
                children.setdefault(parent, []).append(id)
    for id in tickets:
        seen, walk = set(), id
        while walk in tickets and tickets[walk]["fields"].get("parent") and walk not in seen:
            seen.add(walk)
            walk = tickets[walk]["fields"]["parent"]
        if walk in seen and walk == id:
            found.append(f"{id}: its parents lead back to itself")
    for parent, kids in children.items():
        if tickets[parent]["fields"].get("status") == "Done":
            for kid in kids:
                if tickets[kid]["fields"].get("status") not in CLOSED:
                    found.append(f"{parent}: Done, but its child {kid} is {tickets[kid]['fields'].get('status')}")
    found += audit_due(tickets)
    if index is not None and index != index_text(tickets):
        found.append("INDEX.md is stale: python tools/tickets.py index")
    return found


def audit_due(tickets):
    """The audit by Fable comes after every fifth milestone: an audit ticket's waits_on names the last milestone it
    covers; a milestone (a whole number; a part numbered so, as 151 of 151-157, counts as one) is started when it or a
    part of it is In progress or Done. Fails on a sixth started past the last audit, and on one started past an audit
    not yet Done."""
    def num(id):
        f = tickets[id]["fields"]
        ok = f.get("kind") == "milestone" and re.fullmatch(r"\d+", f.get("number", ""))
        return int(f["number"]) if ok else None
    started = {id if num(id) is not None else tickets[id]["fields"].get("parent") or id
               for id, t in tickets.items() if t["fields"].get("status") in ("In progress", "Done")}
    started = {n: id for id in started if id in tickets and (n := num(id)) is not None}
    found, covered = [], 0
    for id, t in tickets.items():
        f = t["fields"]
        if f.get("kind") != "milestone" and not f.get("parent") and re.fullmatch(r"\d+", f.get("number", "")):
            found.append(f"{id}: a whole number on its own is a milestone's; kind milestone, else no number")
    for id, t in tickets.items():
        if t["fields"].get("kind") != "audit":
            continue
        last = [n for w in items(t["fields"].get("waits_on", "")) if w in tickets and (n := num(w)) is not None]
        if not last:
            found.append(f"{id}: an audit's waits_on names the last milestone it covers")
            continue
        covered = max(covered, max(last))
        if t["fields"].get("status") != "Done":
            found += [f"{started[n]}: started before the audit {id} is Done" for n in sorted(started) if n > max(last)]
    past = sorted(n for n in started if n > covered)
    if len(past) > 5:
        found.append(f"{started[past[-1]]}: {len(past)} milestones started since the last audit; an audit ticket comes first "
                     f"(kind audit, waits_on [{started[past[4]]}])")
    return found


def _number_key(f):
    m = re.match(r"\d+", f.get("number", ""))
    return int(m.group()) if m else 99999


def _sort_key(t):
    f = t["fields"]
    prio = PRIORITIES.index(f["priority"]) if f.get("priority") in PRIORITIES else len(PRIORITIES)
    status = STATUSES.index(f["status"]) if f.get("status") in STATUSES else len(STATUSES)  # a bad status sorts last; `check` reports it
    return (status, prio, _number_key(f), t["id"])


def _cell(text):
    return text.replace("|", "\\|")


def index_text(tickets):
    """The text of INDEX.md: waiting on the owner, the open tickets (children under their parent), the closed ones."""
    is_open = {id for id, t in tickets.items() if t["fields"].get("status") not in CLOSED}
    kids = {}
    for id in is_open:
        parent = tickets[id]["fields"].get("parent", "")
        if parent in is_open:
            kids.setdefault(parent, []).append(tickets[id])
    out = ["# Tickets", "", "Generated by `python tools/tickets.py index`; never edited by hand. The fields are in `TEMPLATE.md`.", "", "## Waiting on the owner", ""]
    waiting = sorted((tickets[i] for i in is_open if "owner" in items(tickets[i]["fields"].get("waits_on", ""))), key=_sort_key)
    out += [f"- [{_cell(t['fields'].get('title', ''))}]({t['id']}.md): {t['fields'].get('kind', '')}, {t['fields'].get('status', '')}" for t in waiting] or ["None."]
    out += ["", "## Open", "", "| Ticket | Kind | Status | Priority | Assignee | No. | Waits on | Estimate | Actual | Updated |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]

    def rows(t, depth):
        f = t["fields"]
        mark = "↳ " * depth
        cells = [f"{mark}[{_cell(f.get('title', ''))}]({t['id']}.md)", f.get("kind", ""), f.get("status", ""), f.get("priority", ""), f.get("assignee", ""), f.get("number", ""),
                 ", ".join(items(f.get("waits_on", ""))), f.get("estimate", ""), f.get("actual", ""), f.get("updated", "")]
        out.append("| " + " | ".join(cells) + " |")
        for kid in sorted(kids.get(t["id"], []), key=_sort_key):
            rows(kid, depth + 1)

    for t in sorted((tickets[i] for i in is_open if tickets[i]["fields"].get("parent", "") not in is_open), key=_sort_key):
        rows(t, 0)
    out += ["", "## Closed", ""]
    for id in sorted((i for i in tickets if i not in is_open), reverse=True):
        f = tickets[id]["fields"]
        number = f" {f['number']}," if f.get("number") else ""
        out.append(f"- [{_cell(f.get('title', ''))}]({id}.md): {f.get('kind', '')},{number} {f.get('status', '')}, {id[:10]}")
    return "\n".join(out) + "\n"


def slug(title):
    words = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    if len(words) <= 60 or words[60] == "-":  # a word that ends exactly at 60 stays whole
        return words[:60]
    return words[:60].rsplit("-", 1)[0]


def new(title, parent, folder=HERE, today=None, kind=None, priority=None, assignee=None):
    """Writes a ticket from TEMPLATE.md; returns its id. Fails (ValueError) on a name taken, a parent that does not exist, an unknown kind, priority or assignee."""
    folder = Path(folder)
    today = today or date.today().isoformat()
    id = f"{today}-{slug(title)}"
    if (folder / f"{id}.md").exists():
        raise ValueError(f"{id}.md exists")
    if parent and (parent in ("TEMPLATE", "INDEX") or not (folder / f"{parent}.md").exists()):
        raise ValueError(f"the parent {parent} is no ticket")
    for key, value, allowed in (("kind", kind, KINDS), ("priority", priority, PRIORITIES), ("assignee", assignee, ASSIGNEES)):
        if value is not None and (bad := not_one_of(key, value, allowed)):
            raise ValueError(bad)
    fields, _ = parse((folder / "TEMPLATE.md").read_text(encoding="utf-8"))
    fields.update(title=title, parent=parent or "", updated=today, status="To do")
    fields["kind"] = kind or fields.get("kind") or "backlog"
    fields["priority"] = priority or fields.get("priority") or "Medium"  # every ticket has one; `check` fails without
    fields["assignee"] = assignee or fields.get("assignee") or "Claude"
    head = "".join(f"{k}: {fields.get(k, '')}\n".replace(": \n", ":\n") for k in FIELDS)
    (folder / f"{id}.md").write_text(f"---\n{head}---\n\n## Requirement\n\n", encoding="utf-8", newline="\n")
    return id


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "new" and len(argv) > 2 and not argv[2].startswith("-"):
        opts = dict(zip(argv[3::2], argv[4::2]))
        try:
            print(new(argv[2], opts.get("--parent"), folder=HERE, kind=opts.get("--kind"), priority=opts.get("--priority"), assignee=opts.get("--assignee")))
        except ValueError as e:
            print(e)
            return 1
    elif cmd == "index":
        (HERE / "INDEX.md").write_text(index_text(load()), encoding="utf-8", newline="\n")
    elif cmd == "check":
        index = HERE / "INDEX.md"
        found = problems(load(), index.read_text(encoding="utf-8") if index.exists() else "")
        print("\n".join(found) if found else f"tickets: {len(load())} tickets, no problem")
        return 1 if found else 0
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
