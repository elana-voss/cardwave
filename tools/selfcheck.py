"""The self-check of the plan's trials section: python tools/selfcheck.py (check.sh's `tickets` runs it after `tickets.py check`).

Prints the last closed milestone's agents, hand-overs and tokens against its estimate (from .checklists/agents.tsv, where an agent's row holds the tokens
of the reviews it started), then each
problem of `trials` (its docstring says what) or "trials: no problem"; exit 1 with problems. The plan's file and its trials heading
are read from .claude/one_run.json. Standard library only; the tickets are read through tickets.py.
"""

import datetime
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from tickets import load

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / ".claude" / "one_run.json").read_text(encoding="utf-8"))
PLAN = ROOT / CONFIG["plan"]
TRIALS = CONFIG["trials"]
ACTUALS_SINCE = "2026-11-15"  # the owner's decision: older Done milestones may lack their actual
OPEN_AT_MOST, CLOSED_AT_MOST = 10, 5


def trials(tickets, plan):
    """The self-check (global section 4): a Done milestone since ACTUALS_SINCE without its actual tokens; a trial of the
    plan's Trials section ("- Open, <date>") open past CLOSED_AT_MOST closed milestones (numbered, Done, without parts,
    updated after its date); more than OPEN_AT_MOST open; one closed unmeasured (a trial ends Kept or Reverted with its
    figure)."""
    found = []
    children = {t["fields"].get("parent") for t in tickets.values()}
    closed = []
    for id, t in tickets.items():
        f = t["fields"]
        if f.get("kind") != "milestone" or f.get("status") != "Done":
            continue
        if id[:10] >= ACTUALS_SINCE and not f.get("actual"):
            found.append(f"{id}: Done without its actual tokens")
        if f.get("number") and id not in children:
            closed.append(f.get("updated", ""))
    section = plan.split("\n" + TRIALS, 1)[-1].split("\n## ", 1)[0] if "\n" + TRIALS in plan else ""
    opened = [l for l in section.split("\n") if re.match(r"- Open, \d{4}-\d\d-\d\d", l)]
    for line in opened:
        later = sum(u > line[8:18] for u in closed)
        if later > CLOSED_AT_MOST:
            found.append(f"trial open across {later} closed milestones (at most {CLOSED_AT_MOST}): {line[:90]}")
    for line in section.split("\n"):
        if re.match(r"- Closed, unmeasur", line):
            found.append(f"a trial ends Kept or Reverted with its figure, never closed unmeasured: {line[:90]}")
    if len(opened) > OPEN_AT_MOST:
        found.append(f"{len(opened)} trials open (at most {OPEN_AT_MOST}): measure and close some")
    return found


def closed_report(tickets, rows):
    """The last closed milestone (numbered, Done, latest updated) from its agents' rows of .checklists/agents.tsv (the
    last row per id; a part's agents, `<n>a`, count): agents, hand-overs and tokens against its estimate. A review that
    ran within another of its agents' time was started by that agent, whose row holds its tokens already."""
    done = [(t["fields"].get("updated", ""), id) for id, t in tickets.items() if t["fields"].get("kind") == "milestone"
            and t["fields"].get("status") == "Done" and t["fields"].get("number") and not t["fields"].get("parent")]
    if not done:
        return None
    id = max(done)[1]
    number = tickets[id]["fields"]["number"]
    agents = {}
    for r in rows:
        if re.match(rf"{re.escape(number)}[a-z]?[ :]", r.get("name", "")):
            agents.setdefault(r["id"], []).append(r)
    last = {a: rs[-1] for a, rs in agents.items()}
    spans = {a: s for a, rs in agents.items() if (s := span(rs))}
    inside = {a for a, (start, end) in spans.items() if "review" in last[a].get("kind", "") and
              any(b != a and s <= start and end <= e for b, (s, e) in spans.items())}
    tokens = sum(int(r["tokens"]) for a, r in last.items() if a not in inside and str(r.get("tokens", "")).isdigit()) / 1e6
    over = sum(r.get("end") == "handed over" for r in last.values())
    text = (f"{number} {id}: {len(last)} agents, {over} handed over, {round(tokens, 1):g} million tokens against "
            f"{tickets[id]['fields'].get('estimate') or '?'} estimated")
    if not spans:
        return text
    return text + main_tokens(rows, min(s for s, _ in spans.values()), max(e for _, e in spans.values()))


def moment(text):
    """A row's time as a datetime, or None where it has none that reads."""
    try:
        return datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None


def span(rows):
    """An agent's time from its rows: its first start (a stop less its minutes) to its last stop; None without times."""
    stops = [(at, r) for r in rows if (at := moment(r.get("time")))]
    try:
        return (min(at - datetime.timedelta(minutes=float(r.get("minutes") or 0)) for at, r in stops),
                max(at for at, _ in stops)) if stops else None
    except ValueError:
        return None  # minutes that do not read


def main_tokens(rows, start, end):
    """The main session's tokens from `start` to `end`, as the difference of its `main-<session>` rows (kind main, one per
    agent stop, each its session's total so far): a "; main session X million (input, cache write, cache read, output)" tail."""
    cols = ("input", "cache write", "cache read", "output")
    sessions = {}
    for r in rows:
        if r.get("kind") == "main" and r.get("input", "").isdigit() and (at := moment(r.get("time"))):
            sessions.setdefault(r["id"], []).append((at, [int(r[c]) for c in cols]))

    def total(stamps, t):
        return max(((at, n) for at, n in stamps if at <= t), key=lambda s: s[0], default=(None, [0] * 4))[1]

    sums = [0] * 4
    for stamps in sessions.values():
        sums = [s + b - a for s, a, b in zip(sums, total(stamps, start), total(stamps, end))]
    if not any(sums):
        return ""
    return f"; main session {sum(sums) / 1e6:.1f} million (" + ", ".join(f"{c} {v / 1e6:.1f}" for c, v in zip(cols, sums)) + ")"


def agent_rows(path=ROOT / ".checklists" / "agents.tsv"):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []  # no agents recorded (the skill's handback.py writes them)
    return [dict(zip(lines[0].split("\t"), l.split("\t"))) for l in lines[1:] if l] if lines else []


def main():
    tickets = load()
    report = closed_report(tickets, agent_rows())
    if report:
        print(report)
    found = trials(tickets, PLAN.read_text(encoding="utf-8"))
    print(chr(10).join(found) if found else "trials: no problem")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
