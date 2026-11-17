"""The self-check of the plan's trials section: python tools/selfcheck.py (check.sh's `tickets` runs it after `tickets.py check`).

Prints the last closed milestone's agents, hand-overs and tokens against its estimate (from .checklists/agents.tsv), then each
problem of `trials` (its docstring says what) or "trials: no problem"; exit 1 with problems. The plan's file, its trials heading
and the file whose "Replies to the owner" section is counted (`replies`, a `~` path; absent file: not checked) are read from
.claude/one_run.json. Standard library only; the tickets are read through tickets.py.
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


def replies_words(path):
    """Words of the global CLAUDE.md's "Replies to the owner" section (heading to the next "## "); None without it."""
    try:
        lines = path.read_text(encoding="utf-8").split("\n")
    except OSError:
        return None
    start = next((n for n, l in enumerate(lines) if l.startswith("## Replies to the owner")), None)
    if start is None:
        return None
    end = next((n for n in range(start + 1, len(lines)) if lines[n].startswith("## ")), len(lines))
    return len(" ".join(lines[start + 1:end]).split())


def trials(tickets, plan, replies_words=None):
    """The self-check (global section 4): a Done milestone since ACTUALS_SINCE without its actual tokens; a trial of the
    plan's Trials section ("- Open, <date>") open past CLOSED_AT_MOST closed milestones (numbered, Done, without parts,
    updated after its date); more than OPEN_AT_MOST open; one closed unmeasured (a trial ends Kept or Reverted with its
    figure); the Replies section grown past the "<n> words" its open reply trial recorded."""
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
        words = re.search(r"Replies to the owner: (\d[\d,]*) words", line)
        if words and replies_words is not None and replies_words > int(words.group(1).replace(",", "")):
            found.append(f"the global CLAUDE.md's Replies to the owner has {replies_words} words, more than the "
                         f"{words.group(1)} its trial started with: cut it back")
    for line in section.split("\n"):
        if re.match(r"- Closed, unmeasur", line):
            found.append(f"a trial ends Kept or Reverted with its figure, never closed unmeasured: {line[:90]}")
    if len(opened) > OPEN_AT_MOST:
        found.append(f"{len(opened)} trials open (at most {OPEN_AT_MOST}): measure and close some")
    return found


def closed_report(tickets, rows):
    """The last closed milestone (numbered, Done, latest updated) from its agents' rows of .checklists/agents.tsv (the
    last row per id; a part's agents, `<n>a`, count): agents, hand-overs and tokens against its estimate."""
    done = [(t["fields"].get("updated", ""), id) for id, t in tickets.items() if t["fields"].get("kind") == "milestone"
            and t["fields"].get("status") == "Done" and t["fields"].get("number") and not t["fields"].get("parent")]
    if not done:
        return None
    id = max(done)[1]
    number = tickets[id]["fields"]["number"]
    mine = {r["id"]: r for r in rows if re.match(rf"{re.escape(number)}[a-z]?[ :]", r.get("name", ""))}.values()
    tokens = sum(int(r["tokens"]) for r in mine if str(r.get("tokens", "")).isdigit()) / 1e6
    over = sum(r.get("end") == "handed over" for r in mine)
    text = (f"{number} {id}: {len(mine)} agents, {over} handed over, {round(tokens, 1):g} million tokens against "
            f"{tickets[id]['fields'].get('estimate') or '?'} estimated")
    return text + main_tokens(rows, [r for r in mine if r.get("time")])


def main_tokens(rows, mine):
    """The main session's tokens over the milestone's time (its agents' first start to last stop), as the difference of its
    `main-<session>` rows (kind main, one per agent stop): a "; main session X million (input, cache write, cache read, output)" tail."""
    if not mine:
        return ""
    stops = [r["time"] for r in mine]
    try:
        start = min(datetime.datetime.fromisoformat(r["time"].replace("Z", "+00:00")) - datetime.timedelta(minutes=float(r.get("minutes") or 0))
                    for r in mine).strftime("%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return ""
    end, cols, total = max(stops), ("input", "cache write", "cache read", "output"), [0, 0, 0, 0]
    sessions = {}
    for r in rows:
        if r.get("kind") == "main" and r.get("input", "").isdigit():
            sessions.setdefault(r["id"], []).append(r)
    for rs in sessions.values():
        at = lambda t, rs=rs: [int(r[c]) for c in cols] if (r := max((r for r in rs if r["time"] <= t), key=lambda r: r["time"], default=None)) else [0] * 4
        total = [a + b - c for a, b, c in zip(total, at(end), at(start))]
    if not any(total):
        return ""
    return f"; main session {sum(total) / 1e6:.1f} million (" + ", ".join(f"{c} {v / 1e6:.1f}" for c, v in zip(cols, total)) + ")"


def agent_rows(path=ROOT / ".checklists" / "agents.tsv"):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []  # no agents recorded (the skill's handback.py writes them)
    return [dict(zip(lines[0].split("\t"), l.split("\t"))) for l in lines[1:] if l] if lines else []


def main():
    report = closed_report(load(), agent_rows())
    if report:
        print(report)
    replies = CONFIG.get("replies")
    found = trials(load(), PLAN.read_text(encoding="utf-8"), replies_words(Path(replies).expanduser()) if replies else None)
    print(chr(10).join(found) if found else "trials: no problem")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
