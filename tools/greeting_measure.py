#!/usr/bin/env python3
"""Writes the cards of a folder of finished interviews through the server, for milestone
117's before and after on one model, and keeps each first greeting for reading by hand.

    python tools/greeting_measure.py run  <usable folder> <out> <run> --server <exe> [--model M] [--spend N] [--every N]
    python tools/greeting_measure.py show <usable folder> <out> <run> <from> <to>      prints cards <from>..<to> to read
    python tools/greeting_measure.py count <out> <run>                 prints the counts of verdicts-<run>.txt

`<usable folder>` is read only: `cards/units/us-*.json` (profile, choices) and
`interviews/units/<source>.json` (process, sensitive). All that is written goes under `<out>/<run>`:
the server's data folder and its key `db.key` (never the OS store), `server.log`, `units/<unit>.json` (a card written; a unit that has one is
not written again), `usage.json`. It holds the cards' text, so `<out>` is never a tracked folder.
A reader's reading, no truth: `<out>/verdicts-<run>.txt`, a line `<unit> acts|clean same|other` per card (the
character's gender read as the interview's or not; stored files say `right|wrong` for these).

Traps: the server does not read a provider's usage, so a proxy in this process stands between it
and the provider: it holds the key (env NANOGPT_API_KEY, the server gets a dummy), adds usage to the
stream, retries 429 and 5xx, totals tokens per schema name and stops at `--spend` over all the runs
under `<out>`; `usage.json` is added to by a rerun. It refuses every call that is not the writer's:
the needs classifier after a write sends no schema, so any other call without one is a format
fallback, filed as `unformatted`.
The proxy's handler and retries and the app driver: tools/measure_common.py.
Posting `/api/interview/write` directly skips the interview's own calls, as the answers are given.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import pathlib
import sys
import threading
import time
import urllib.error
import urllib.request

from measure_common import App, ProxyHandler, QuietServer, Refused, fetch, free_port, kept_key, piece_of, start_app, upstream_request, usage_of

UPSTREAM = "https://nano-gpt.com/api/v1"
WRITER = {"writer_plan", "writer_card", "writer_rewrite"}
AT_ONCE = 4
UPSTREAM_SILENCE = 900
WRITE_TIMEOUT = 3600


class Usage:
    """The tokens of this run, per schema name, written out after each call."""

    def __init__(self, path, before, limit):
        self.path, self.before, self.limit = path, before, limit
        self.lock = threading.Lock()
        kept = load(path) if path.exists() else {}
        self.roles = kept.get("roles", {})
        self.refused = kept.get("refused", 0)

    def add(self, role, prompt, completion):
        with self.lock:
            row = self.roles.setdefault(role, {"calls": 0, "in": 0, "out": 0})
            row["calls"] += 1
            row["in"] += prompt
            row["out"] += completion
            self.write()

    def refuse(self):
        with self.lock:
            self.refused += 1
            self.write()

    def write(self):
        self.path.write_text(json.dumps({"roles": self.roles, "refused": self.refused}), encoding="utf-8")

    def spent(self):
        with self.lock:
            return self.before + sum(row["in"] + row["out"] for row in self.roles.values())

    def over(self):
        return self.spent() >= self.limit


def proxy_class(usage, key):
    class Proxy(ProxyHandler):
        def do_POST(self):
            body = self.body()
            role = ((body.get("response_format") or {}).get("json_schema") or {}).get("name", "unformatted")
            if (role not in WRITER and role != "unformatted") or is_background(body):
                usage.refuse()
                return self.refuse(403, "not measured")
            if usage.over():
                return self.refuse(403, "the measuring's spend is reached")
            request = upstream_request(UPSTREAM, self.path, body, key)
            reply, failure, _, _ = fetch(request, urllib.request.urlopen, time.sleep, UPSTREAM_SILENCE)
            if reply is None:
                return self.send(failure[0], "application/json", failure[1])
            self.pass_on(reply, role)
            return None

        def pass_on(self, reply, role):
            """Streams the reply on, chunked, reading the usage from its lines as they pass."""
            self.send_response(reply.status)
            self.send_header("Content-Type", reply.headers.get("Content-Type", "text/event-stream"))
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            prompt = completion = 0
            try:
                for line in iter(reply.readline, b""):
                    if b'"usage"' in line:
                        prompt, completion = (usage_of(piece_of(line) or {}) or (prompt, completion))[:2]
                    self.wfile.write(b"%x\r\n%s\r\n" % (len(line), line))
                    self.wfile.flush()
                self.wfile.write(b"0\r\n\r\n")
            finally:  # The server may stop reading at [DONE]; the provider has billed the call all the same.
                usage.add(role, prompt, completion)

    return Proxy


def is_background(body):
    """The worker's call on a card just made (needs, describe): sent without a schema, told by its user text."""
    return str(body["messages"][-1].get("content", "")).startswith("<card_to_")


def load(path):
    return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))


def request_of(usable, unit_file):
    """The write's body for a finished unit: its answers as they were given."""
    unit = load(unit_file)
    source = load(usable / "interviews" / "units" / f"{unit['source']}.json")
    profile, choices = unit["profile"], unit["choices"]
    sensitive = source["sensitive"]
    extra = {"choices": [], "multi": False, "probe": False, "picks": [], "free": ""}
    seed = hashlib.sha256(unit_file.stem.encode()).hexdigest()[:16]
    interview = {
        "style": source["process"].lower(),
        "log": [{**entry, **extra} for entry in profile["question_log"]],
        "asking": None,
        "ahead": [],
        "waiting": None,
        "top": [],
        "kinds": profile["kinds"],
        "guard_hit": False,
        "changed": None,
        "read": {
            "character": choices["character_gender"],
            "treat": choices["treat_user"],
            "words": choices["character_words"],
        },
        "seed": seed,
    }
    return {
        "interview": interview,
        "lines": profile["needs"],
        "verdicts": ["keep" for _ in profile["needs"]],
        "private": {"open": sensitive["open"], "rows": sensitive["rows"], "free": sensitive["free"]},
        "other_model": None,
    }


def write_one(address, usable, unit_file, units):
    started = time.time()
    done = units / f"{unit_file.stem}.json"
    try:
        app = App(address)
        written = app.must("POST", "/api/interview/write", request_of(usable, unit_file), timeout=WRITE_TIMEOUT)
        card = app.must("GET", f"/api/cards/{written['card_id']}")
    except Refused as failure:
        return unit_file.stem, f"failed {failure}"
    except (urllib.error.URLError, OSError, KeyError, AssertionError) as failure:
        return unit_file.stem, f"failed: {failure}"  # An unreadable unit stops itself, not the run's summary.
    done.write_text(json.dumps({"seconds": round(time.time() - started), "card": card}, ensure_ascii=False), encoding="utf-8")
    return unit_file.stem, None


def units_of(usable, every):
    """Every `every`th unit of the sorted list, the first among them."""
    return sorted(usable.glob("cards/units/us-*.json"))[::every]


def spent_elsewhere(out, run):
    total = 0
    for other in out.glob("*/usage.json"):
        if other.parent.name != run:
            total += sum(row["in"] + row["out"] for row in load(other)["roles"].values())
    return total


def run(args):
    key = os.environ.get("NANOGPT_API_KEY")
    if not key:
        sys.exit("NANOGPT_API_KEY is not set")
    usable, out = pathlib.Path(args.usable), pathlib.Path(args.out)
    here = out / args.run
    units = here / "units"
    units.mkdir(parents=True, exist_ok=True)
    usage = Usage(here / "usage.json", spent_elsewhere(out, args.run), args.spend)
    proxy_port, server_port = free_port(), free_port()
    proxy = QuietServer(("127.0.0.1", proxy_port), proxy_class(usage, key))
    threading.Thread(target=proxy.serve_forever, daemon=True).start()
    address = f"http://127.0.0.1:{server_port}"
    with open(here / "server.log", "ab") as log:
        server = start_app(args.server, server_port, here / "data", log, kept_key(here / "db.key"))
    failed = []
    try:
        app = App(address)
        app.wait(server, here / "server.log")
        app.must("PUT", "/api/provider", {"base_url": f"http://127.0.0.1:{proxy_port}/v1", "model": args.model, "api_key": "proxy"})
        files = units_of(usable, args.every)
        todo = [file for file in files if not (units / f"{file.stem}.json").exists()]
        with concurrent.futures.ThreadPoolExecutor(AT_ONCE) as pool:
            for name, failure in pool.map(lambda file: write_one(address, usable, file, units), todo):
                print(name, failure or "written", flush=True)
                if failure:
                    failed.append(name)
    finally:
        server.terminate()
        proxy.shutdown()
    print(f"{len(list(units.glob('*.json')))} of {len(files)} written, {len(failed)} failed; refused calls {usage.refused}")
    for role, row in sorted(usage.roles.items()):
        print(f"{role}: {row['calls']} calls, {row['in']} in, {row['out']} out")
    print(f"spent over all runs {usage.spent()} of {args.spend}")


def show(args):
    """A card's first greeting with what its gender must be measured against."""
    here = pathlib.Path(args.out) / args.run / "units"
    for path in sorted(here.glob("*.json"))[args.start : args.end]:
        choices = load(pathlib.Path(args.usable) / "cards" / "units" / path.name)["choices"]
        print(f"=== {path.stem} | char {choices['character_gender']} {choices['character_words']} | user {choices['treat_user']}")
        for person in load(path)["card"]["characters"]:
            print(f"[{person['name']}] {person['description'][:200]}")
            print(person["greetings"][0])


def count(args):
    rows = [line.split() for line in (pathlib.Path(args.out) / f"verdicts-{args.run}.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    other = sum(row[2] in ("other", "wrong") for row in rows)
    print(f"{len(rows)} cards, one reader's reading: read as acting for the user {sum(row[1] == 'acts' for row in rows)}; gender read otherwise {other}")


def main():
    parser = argparse.ArgumentParser()
    verbs = parser.add_subparsers(dest="verb", required=True)
    start = verbs.add_parser("run")
    start.add_argument("usable")
    start.add_argument("out")
    start.add_argument("run")
    start.add_argument("--server", required=True)
    start.add_argument("--model", default="xiaomi/mimo-v2.6-flash")
    start.add_argument("--spend", type=int, default=2_400_000)
    start.add_argument("--every", type=int, default=1)
    start.set_defaults(act=run)
    shown = verbs.add_parser("show")
    shown.add_argument("usable")
    shown.add_argument("out")
    shown.add_argument("run")
    shown.add_argument("start", type=int)
    shown.add_argument("end", type=int)
    shown.set_defaults(act=show)
    counted = verbs.add_parser("count")
    counted.add_argument("out")
    counted.add_argument("run")
    counted.set_defaults(act=count)
    args = parser.parse_args()
    args.act(args)


if __name__ == "__main__":
    main()
