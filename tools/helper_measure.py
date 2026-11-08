#!/usr/bin/env python3
"""Milestone 126a: every job of the Helper model (the background model) asked through the app, one model a run.

    python tools/helper_measure.py run OUT --provider nano|xai --model M [--spend USD] [--fake] [--server EXE]
    python tools/helper_measure.py figures OUT        tables of every run under OUT: OUT/figures.txt, OUT/samples.txt
    python tools/helper_measure.py estimate OUT RUN   each candidate's cost of a run like RUN (a --fake one): OUT/estimate.txt

A run starts the app on a fresh data folder under OUT/<run> with a proxy of this process as its provider: the chat
model `cw-fake-chat` and the image model are answered by the proxy; every Helper call (`job_of` tells which job by
its prompt) goes to the provider, or with --fake gets a canned valid answer. It writes OUT/<run>/calls.jsonl (per
call: job, seconds of its last try, retries, tokens, the answer, whether the app can use it, `usable`, the app's own rule rewritten) and
app.json (what the app shows: each card's needs, the describe failure, the endpoints' answers).
The cards are tools/helper_cards.json (one per need, `aim` the need it was written for) and tools/helper_maren.toml, a
card with two modes and a lorebook; never anyone's library. What the user says and the canned answers: tools/helper_fixtures.json.
The proxy's handler and retries, the app driver and the card files: tools/measure_common.py. Prices: OUT/nano_all.json (nano-gpt's public list) and
OUT/xai.json (xAI's /language-models, unit 1e-4 USD a million).
Traps: the stream's usage is asked for (`stream_options`); without it tokens are four characters each. xAI counts
reasoning tokens apart from completion tokens, both billed as output. --spend stops new calls once passed.
"""

import argparse
import base64
import hashlib
import io  # noqa: F401  The test makes its HTTP errors with tool.io.
import json
import os
import pathlib
import re
import shutil
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request

from measure_common import App, ProxyHandler, QuietServer, ccv4_card, fetch, free_port, piece_of, png, start_app, upstream_request, usage_of, v2_card

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "tools" / "helper_cards.json"
# --provider agent: no upstream; answers written by Claude's agents into OUT/agent-<model>-queue (`ask_agent`).
UPSTREAMS = {"nano": ("https://nano-gpt.com/api/v1", "NANOGPT_API_KEY"), "xai": ("https://api.x.ai/v1", "XAI_API_KEY")}
FAKE_CHAT = "cw-fake-chat"
MODES = ["Roleplay", "Assistant"]
RATINGS = {"sfw", "suggestive", "nsfw", "nsfw-extreme"}
NEEDS = {card["aim"] for card in json.loads(CARDS.read_text(encoding="utf-8"))}  # the app's LIST, one card a need
MOVES = {"walk", "climb", "let_go", "play", "react", "look", "say", "wait"}
# Each candidate as (provider, model); why others are left out is in the plan under 126a.
CANDIDATES = [
    ("nano", "anthropic/claude-haiku-5.5"), ("nano", "anthropic/claude-sonnet-5.5"),
    ("nano", "openai/gpt-5.6-luna"), ("nano", "openai/gpt-5.6-terra"), ("nano", "openai/gpt-5.4-mini"),
    ("nano", "google/gemini-3.5-flash-lite"), ("nano", "google/gemini-3.8-flash"),
    ("nano", "deepseek/deepseek-v4.1-flash"), ("nano", "deepseek/deepseek-v4-pro"), ("nano", "deepseek/deepseek-v4-flash-0731"),
    ("nano", "qwen/qwen3.8-flash"), ("nano", "qwen/qwen3.8-max"),
    ("nano", "mistralai/mistral-small-4-119b-2603"), ("nano", "mistralai/mistral-medium-3.5"),
    ("nano", "z-ai/glm-5.3-flash"), ("nano", "z-ai/glm-5.3"),
    ("xai", "grok-4.20-0309-non-reasoning"), ("xai", "grok-4.3"), ("xai", "grok-build-0.1"),
]
# Output tokens a job's answer takes, Claude's guess, for the estimate only (a fake answer is shorter).
OUT_GUESS = {"classify": 350, "write": 250, "needs": 300, "title": 15, "pick_mode": 10, "memory": 300,
             "chat_picture_words": 80, "card_picture_words": 80, "lore_translate": 60, "lore_keywords_translate": 15,
             "rewrite": 150, "keywords": 15, "companion": 60}
FIXTURES = json.loads((ROOT / "tools" / "helper_fixtures.json").read_text(encoding="utf-8"))
TALK = FIXTURES["talk"]  # What the user says to Maren.
MAREN = (ROOT / "tools" / "helper_maren.toml").read_text(encoding="utf-8")  # Two modes and a lorebook.
# A canned valid answer per job, as the app gets it: an object as JSON text.
FAKES = {job: json.dumps(said) if isinstance(said, dict) else said for job, said in FIXTURES["fakes"].items()}
PIXEL = base64.b64encode(png([])).decode()  # The image model's answer.


def job_of(body: dict) -> str:
    """Which Helper job a request is, told by its prompt's start; `chat` for the chat model's own calls."""
    if body.get("model") == FAKE_CHAT:
        return "chat"
    texts = [str(message.get("content", "")) for message in body.get("messages", [])]
    system, user = (texts[0] if texts else ""), (texts[-1] if texts else "")
    marks = [("You rewrite one text of a character card for roleplay: the card's lorebook entry's keywords", "lore_keywords_translate"),
             ("You rewrite one text of a character card for roleplay: the card's lorebook entry", "lore_translate"),
             ("You rewrite one text", "rewrite"), ("You write the keywords of one entry", "keywords"),
             ("You title a chat", "title"), ("You pick the mode of a chat.", "pick_mode"),
             ("You write what a character card's picture shows", "card_picture_words"),
             ("You move a character's figure", "companion")]
    for mark, job in marks:
        if system.startswith(mark):
            return job
    if any(text.startswith("Read these new messages of a ") for text in texts):
        return "memory"
    if user.startswith("<card_to_classify>"):
        return "classify"
    if user.startswith("<card_to_read>"):
        return "needs"
    if user.startswith("<card>\n") and "<facets>" in user:
        return "write"
    if any("Ignore previous instructions" in text for text in texts):
        return "chat_picture_words"
    return "other"


def object_of(text: str):
    """The JSON object of an answer as the app reads one (`cw_provider::object`): first `{` to last `}`."""
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        return None
    try:
        value = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def words(text: str) -> str:
    return text.rsplit("</think>", 1)[-1].strip().strip("\"'`").strip()


def written(row: dict, run: str) -> int:
    """A call's written tokens: nano-gpt's completion tokens hold the reasoning already, xAI's do not."""
    return row["out"] + (row["reasoning"] if run.startswith("xai") else 0)


def memory_rows(text: str) -> int:
    """The FACTS and EVENTS rows the app would read (`memory::hybrid::sections`; rows before any heading are events)."""
    rows = 0
    for line in text.splitlines():
        if re.match(r"(?i)^\W*(FACTS|EVENTS)\b", line):
            line = re.sub(r"(?i)^\W*(FACTS|EVENTS)\b\W*", "", line)
        cells = [cell.strip(" -*") for cell in line.strip(" -*|").split("|")] if "|" in line else []
        if cells and cells[0].lower() not in ("subject", "event") and any(cells):
            rows += 1
    return rows


def usable(job: str, text: str) -> bool:
    """Whether the app can use `text` as the answer of `job`, by the app's own rule."""
    found = object_of(text)
    if job == "classify":
        verdict = str((found or {}).get("verdict", "")).strip().lower()
        return found is not None and (verdict.startswith("reject") or str(found.get("rating", "")).strip().lower() in RATINGS)
    if job == "write":
        return found is not None and bool(" ".join(str(found.get("logline", "")).split()))
    if job == "needs":
        needs, classified = (found or {}).get("needs"), str((found or {}).get("verdict", "")).strip().lower() == "classified"
        return isinstance(needs, list) and ((classified and not needs) or any(
            isinstance(need, dict) and need.get("need") in NEEDS and isinstance(need.get("level"), int) and 0 <= need["level"] <= 3
            for need in needs))
    if job == "title":
        return found is not None and bool(str(found.get("title", "")).strip())
    if job == "pick_mode":
        return found is not None and found.get("mode") in MODES
    if job == "memory":
        return memory_rows(text) > 0
    if job == "companion":
        steps = (found or {}).get("steps")
        return isinstance(steps, list) and all(isinstance(step, dict) and step.get("do") in MOVES for step in steps)
    if job in ("keywords", "lore_keywords_translate"):
        return any(word.strip(" \"'.*-") for word in re.split(r"[,\n，、،]", words(text)))
    return bool(words(text))


class Calls:
    """The Helper calls of a run, written to calls.jsonl as each ends; the spend so far; when the proxy was last busy."""

    def __init__(self, path: pathlib.Path, price: tuple, limit: float, provider: str):
        self.path, self.price, self.limit, self.provider = path, price, limit, provider
        self.lock = threading.Lock()
        self.busy, self.last, self.spent = 0, time.time(), 0.0
        self.queue: pathlib.Path | None = None  # --provider agent: asks/ and answers/ here.
        self.waiting = 0  # Asks of this pass that have no answer yet.

    def begin(self):
        with self.lock:
            self.busy += 1

    def end(self, row: dict | None):
        with self.lock:
            self.busy -= 1
            self.last = time.time()
            if row:
                self.spent += row["usd"]
                with self.path.open("a", encoding="utf-8") as file:
                    file.write(json.dumps(row, ensure_ascii=False) + "\n")

    def quiet(self, seconds: float) -> bool:
        with self.lock:
            return self.busy == 0 and time.time() - self.last >= seconds

    def cost(self, prompt: int, completion: int, reasoning: int) -> float:
        billed = completion + (reasoning if self.provider == "xai" else 0)
        return (prompt * self.price[0] + billed * self.price[1]) / 1e6


def ask_key(body: dict) -> str:
    """A request's name in the queue: the hash of its messages, so a pass sends the same request under the same name."""
    return hashlib.sha256(json.dumps(body.get("messages", []), sort_keys=True).encode()).hexdigest()[:16]


def render_ask(job: str, body: dict) -> str:
    """A request as an agent reads it: each message under its role."""
    parts = [f"job: {job}"] + [f"=== {message.get('role')} ===\n{message.get('content', '')}" for message in body.get("messages", [])]
    return "\n\n".join(parts) + "\n"


def stream_of(text: str, prompt: int) -> bytes:
    pieces = [{"choices": [{"delta": {"content": text}}]}, {"choices": [], "usage": {"prompt_tokens": prompt, "completion_tokens": len(text) // 4}}]
    return b"".join(b"data: " + json.dumps(piece).encode() + b"\n\n" for piece in pieces) + b"data: [DONE]\n\n"


def fake_answer(job: str, body: dict) -> str:
    if job in FAKES:
        return FAKES[job]
    if job in ("chat_picture_words", "card_picture_words"):
        return FIXTURES["picture_words"]
    return FIXTURES["other"]


def proxy_class(calls: Calls, upstream: str | None, key: str | None):
    class Proxy(ProxyHandler):
        def do_POST(self):
            body = self.body()
            if self.path.endswith("/images/generations"):
                return self.send(200, "application/json", json.dumps({"data": [{"b64_json": PIXEL}]}).encode())
            job = job_of(body)
            sent = sum(len(str(message.get("content", ""))) for message in body.get("messages", [])) // 4
            if job == "chat":
                return self.send(200, "text/event-stream", stream_of(FAKES["chat"], sent))
            calls.begin()
            row = None
            try:
                row = self.helper(job, body, sent)
            finally:
                calls.end(row)
            return None

        def helper(self, job: str, body: dict, sent: int) -> dict | None:
            """A Helper call answered and its row: from the provider, or canned without one."""
            started = time.time()
            if calls.queue is not None:
                return self.ask_agent(job, body, sent, started)
            if upstream is None:
                text = fake_answer(job, body)
                data = stream_of(text, sent) if body.get("stream") else json.dumps({"choices": [{"message": {"content": text}}]}).encode()
                self.send(200, "text/event-stream" if body.get("stream") else "application/json", data)
                return self.row(job, started, text, (sent, len(text) // 4, 0), sent)
            if calls.spent >= calls.limit:
                self.refuse(403, "the run's spend is reached")
                return None
            request = upstream_request(upstream, self.path, body, key)
            reply, failure, retries, started = fetch(request, urllib.request.urlopen, time.sleep)
            if reply is None:
                self.send(failure[0], "application/json", failure[1])
                return {**self.row(job, started, "", (sent, 0, 0), sent), "failed": True, "retries": retries}
            text, used = self.pass_on(reply)
            return {**self.row(job, started, text, used, sent), "retries": retries}

        def ask_agent(self, job: str, body: dict, sent: int, started: float) -> dict | None:
            """The answer an agent wrote to this very request, or the request written out for one and the call failed."""
            key = ask_key(body)
            answer = calls.queue / "answers" / f"{key}.txt"
            if not answer.exists():
                with calls.lock:
                    calls.waiting += 1
                ask = calls.queue / "asks" / f"{key}.txt"
                if not ask.exists():
                    ask.write_text(render_ask(job, body), encoding="utf-8")
                self.refuse(400, "waiting for an agent answer")
                return None
            text = answer.read_text(encoding="utf-8").strip()
            data = stream_of(text, sent) if body.get("stream") else json.dumps({"choices": [{"message": {"content": text}}]}).encode()
            self.send(200, "text/event-stream" if body.get("stream") else "application/json", data)
            return {**self.row(job, started, text, None, sent), "seconds": 0.0}

        def row(self, job, started, text, used, sent) -> dict:
            prompt, completion, reasoning = used if used else (sent, len(text) // 4, 0)
            return {"job": job, "seconds": round(time.time() - started, 2), "in": prompt, "out": completion, "reasoning": reasoning,
                    "counted": used is not None, "usd": calls.cost(prompt, completion, reasoning), "usable": usable(job, text), "text": text}

        def pass_on(self, reply):
            """Passes the reply on whole, reading its text and usage, streamed or not."""
            data = reply.read()
            text, used = "", None
            if "event-stream" in reply.headers.get("Content-Type", ""):
                for line in data.decode(errors="replace").splitlines():
                    piece = piece_of(line)
                    if piece is None:
                        continue  # [DONE] and empty lines carry nothing.
                    for choice in piece.get("choices") or []:
                        text += (choice.get("delta") or {}).get("content") or ""
                    used = usage_of(piece) or used
            else:
                piece = json.loads(data or b"{}")
                text = ((piece.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
                used = usage_of(piece)
            self.send(reply.status, reply.headers.get("Content-Type", "application/json"), data)
            return text, used

    return Proxy


def card_file(card: dict) -> bytes:
    """A test card of helper_cards.json as a SillyTavern V2 card file."""
    return v2_card({"name": card["name"], "description": card["description"], "scenario": card["scenario"], "first_mes": card["greeting"],
                    "personality": "", "mes_example": "", "tags": card["tags"]})


def settle(calls: Calls, quiet: float, most: int = 600):
    """Waits until no Helper call has run for `quiet` seconds."""
    end = time.time() + most
    while time.time() < end and not calls.quiet(quiet):
        time.sleep(0.5)


def described(app: App, ids: dict, most: int = 3600) -> dict:
    """Each card's needs as the app shows them, once every card's reading ended."""
    shown, end = {}, time.time() + most
    while time.time() < end:
        shown = {name: app.call("GET", f"/api/cards/{card}")[1]["needs"] for name, card in ids.items()}
        if all(item["state"] in ("found", "zero", "refused", "failed") for item in shown.values()):
            break
        time.sleep(3)
    return shown


def drive(app: App, calls: Calls, quiet: float) -> dict:
    """Every Helper job asked through the app, in the order a user meets them; what the app answered."""
    seen: dict = {}
    _, kinds = app.call("GET", "/api/provider-list")
    place = next(kind["provider_id"] for kind in kinds["kinds"] if kind["kind"] == "chat")
    seen["image_kind"] = app.call("PUT", "/api/kinds/images", {"provider_id": place, "model": "cw-fake-image"})[0]
    cards = json.loads(CARDS.read_text(encoding="utf-8"))
    ids = {card["name"]: app.call("POST", "/api/cards", raw=card_file(card))[1]["card_id"] for card in cards}
    status, maren = app.call("POST", "/api/cards", raw=ccv4_card(MAREN))
    ids["Maren"] = maren["card_id"]
    app.call("POST", "/api/describe")
    needs = described(app, ids)
    if calls.waiting:  # A pass of --provider agent ends at the first round that waits for answers.
        return seen
    if any(item["state"] == "failed" for item in needs.values()):  # As the app's button does: the failed once more.
        seen["describe_failure"] = app.call("GET", "/api/describe")[1].get("failure")
        app.call("POST", "/api/describe")
        time.sleep(3)
        needs = described(app, ids)
    seen["needs"] = {card["name"]: {"aim": card["aim"], **needs[card["name"]]} for card in cards}
    settle(calls, quiet)
    _, card = app.call("GET", f"/api/cards/{ids['Maren']}")
    character = card["characters"][0]["id"]
    _, chat = app.call("POST", "/api/chats", {"characters": [{"version_id": maren["version_id"], "character": character}], "greeting": 0})
    chat_id = chat["chat"]["id"]
    seen["talk"] = []
    for said in TALK:
        sent = app.call("POST", f"/api/chats/{chat_id}/messages", {"content": said})[0]
        started = app.call("POST", f"/api/chats/{chat_id}/generate", {})[0]
        settle(calls, quiet)
        seen["talk"].append([sent, started])
        if calls.waiting:
            return seen
    _, view = app.call("GET", f"/api/chats/{chat_id}")
    seen["chat_title"] = (view.get("chat") or {}).get("title")
    seen["memories"] = app.call("GET", "/api/memories")
    seen["chat_picture"] = app.call("POST", f"/api/chats/{chat_id}/picture", {})[0]
    seen["card_picture_words"] = [app.call("POST", f"/api/cards/{ids[name]}/pictures/words")[0:2] for name in list(ids)[:4]]
    seen["lore_translation"] = app.call("POST", f"/api/cards/{ids['Maren']}/lore-translation", {"language": "de"})
    text = cards[0]["description"]
    asks = [("improve", None), ("fix", None), ("shorter", None), ("longer", None), ("translate", "French"), ("ask", "Make it warmer.")]
    seen["rewrite"] = [app.call("POST", "/api/rewrite", {"text": text, "tool": tool, "what": "Description", **({"given": given} if given else {})})
                       for tool, given in asks]
    entries = [{"text": card["description"], "keywords": [], "secondary_keywords": [], "reference": card["name"]} for card in cards[1:4]]
    seen["keywords"] = app.call("POST", "/api/rewrite/lore", {"tool": "keywords", "entries": entries})
    companion = {"card_id": ids["Maren"], "starts": False, "hidden_until": None}
    seen["companion_set"] = app.call("PATCH", "/api/settings", {"companion": companion})[0]
    plans = [{"occasion": "alone", "alone_s": 95}] * 3 + [{"occasion": "handled", "handled": ["held", "shaken"]}] * 2
    seen["companion"] = [app.call("POST", "/api/companion/plan", {"chat_id": None, "width": 1600, "height": 900, "x": 300, "y": 900,
                                                                   "state": "idle", **plan}) for plan in plans]
    settle(calls, quiet)
    return seen


def price_of(out: pathlib.Path, provider: str, model: str) -> tuple:
    """USD a million tokens in and out, from the lists kept under OUT."""
    if provider == "xai":
        for entry in json.loads((out / "xai.json").read_text(encoding="utf-8"))["models"]:
            if entry["id"] == model:
                return entry["prompt_text_token_price"] / 1e4, entry["completion_text_token_price"] / 1e4
    else:
        for entry in json.loads((out / "nano_all.json").read_text(encoding="utf-8"))["data"]:
            if entry["id"] == model:
                return entry["pricing"]["prompt"], entry["pricing"]["completion"]
    sys.exit(f"{model} is not in {provider}'s list")


def run(args):
    out = pathlib.Path(args.out)
    name = "fake" if args.fake else f"{args.provider}-{re.sub(r'[^a-z0-9.-]+', '_', args.model.lower())}"
    here = out / name
    agent = args.provider == "agent"
    if here.exists() and agent:  # A pass of the agents' run starts afresh; their answers stay in the queue.
        shutil.rmtree(here)
    if here.exists():
        sys.exit(f"{here} exists: a run is made once")
    here.mkdir(parents=True)
    upstream, key = (None, None) if args.fake or agent else (UPSTREAMS[args.provider][0], os.environ.get(UPSTREAMS[args.provider][1]))
    if not args.fake and not agent and not key:
        sys.exit(f"{UPSTREAMS[args.provider][1]} is not set")
    price = (0.0, 0.0) if args.fake or agent else price_of(out, args.provider, args.model)
    calls = Calls(here / "calls.jsonl", price, args.spend, args.provider)
    if agent:
        calls.queue = out / f"{name}-queue"
        for folder in ("asks", "answers"):
            (calls.queue / folder).mkdir(parents=True, exist_ok=True)
    proxy_port, app_port = free_port(), free_port()
    proxy = QuietServer(("127.0.0.1", proxy_port), proxy_class(calls, upstream, key))
    threading.Thread(target=proxy.serve_forever, daemon=True).start()
    with open(here / "server.log", "ab") as log:
        server = start_app(args.server, app_port, here / "data", log)
    app = App.local(app_port, timeout=600)
    try:
        app.wait(server, here / "server.log")
        provider = {"base_url": f"http://127.0.0.1:{proxy_port}/v1", "model": FAKE_CHAT, "api_key": "proxy",
                    "worker_model": "cw-fake-helper" if args.fake else args.model, "sampling": {"context_size": 200000}}
        status, said = app.call("PUT", "/api/provider", provider)
        if status != 200:
            sys.exit(f"the provider was refused: {said}")
        started = time.time()
        seen = drive(app, calls, 1.5 if args.fake else 4)
        seen["seconds"] = round(time.time() - started)
    finally:
        server.terminate()
        server.wait()
        proxy.shutdown()
    (here / "app.json").write_text(json.dumps(seen, ensure_ascii=False, indent=1), encoding="utf-8")
    rows = rows_of(here)
    if calls.waiting:
        missing = [ask for ask in (calls.queue / "asks").glob("*.txt") if not (calls.queue / "answers" / ask.name).exists()]
        (here / "app.json").unlink()  # Not a finished run: `figures` leaves it out.
        print(f"{name}: a pass ended waiting; {len(missing)} asks without an answer in {calls.queue / 'asks'}")
        return
    print(f"{name}: {len(rows)} Helper calls, {sum(row['usable'] for row in rows)} usable, ${calls.spent:.3f}, {seen['seconds']} s")


def rows_of(here: pathlib.Path) -> list:
    path = here / "calls.jsonl"
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()] if path.exists() else []


def by_need(seen: dict) -> tuple:
    """Cards whose aimed need the app counts, their aimed need's mean rank, and cards read at all."""
    found, ranks, read = 0, [], 0
    for item in seen.get("needs", {}).values():
        read += item["state"] in ("found", "zero", "refused")
        hit = [need["rank"] for need in item.get("needs") or [] if need["need"] == item["aim"]]
        if hit:
            found += 1
            ranks.append(hit[0])
    return found, (round(statistics.mean(ranks), 1) if ranks else None), read


def figures(args):
    out = pathlib.Path(args.out)
    runs = sorted(path for path in out.iterdir() if (path / "app.json").exists())
    lines, samples = [], []
    for here in runs:
        rows, seen = rows_of(here), json.loads((here / "app.json").read_text(encoding="utf-8"))
        found, rank, read = by_need(seen)
        cards = len(seen.get("needs", {}))
        lines.append(f"== {here.name}: ${sum(row['usd'] for row in rows):.3f}; By need: aimed need counted on {found} of {cards} cards "
                     f"(mean rank {rank}), {read} of {cards} read; calls not counted by the provider {sum(not row['counted'] for row in rows)}")
        lines.append(f"{'job':<24}{'calls':>6}{'usable':>8}{'median s':>10}{'in':>9}{'out':>8}{'usd':>9}")
        for job in sorted({row["job"] for row in rows}):
            mine = [row for row in rows if row["job"] == job]
            lines.append(f"{job:<24}{len(mine):>6}{sum(row['usable'] for row in mine):>8}{statistics.median(row['seconds'] for row in mine):>10.1f}"
                         f"{sum(row['in'] for row in mine):>9}{sum(written(row, here.name) for row in mine):>8}{sum(row['usd'] for row in mine):>9.4f}")
            samples += [f"[{here.name} {job}] {row['text'][:400]!r}" for row in mine[:2] if job not in ("classify", "needs")]
    (out / "figures.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (out / "samples.txt").write_text("\n".join(samples) + "\n", encoding="utf-8")
    print(f"{len(runs)} runs; tables in {out / 'figures.txt'}, samples in {out / 'samples.txt'}")


def estimate(args):
    """Each candidate's cost of a run like RUN: its input tokens as counted, its output by `OUT_GUESS`."""
    out = pathlib.Path(args.out)
    rows = rows_of(out / args.run)
    sent = sum(row["in"] for row in rows)
    made = sum(OUT_GUESS.get(row["job"], 100) for row in rows)
    lines, totals = [f"a run: {len(rows)} Helper calls, {sent} tokens in, about {made} out (guessed per job)"], {}
    for provider, model in CANDIDATES:
        price = price_of(out, provider, model)
        usd = (sent * price[0] + made * price[1]) / 1e6
        totals[provider] = [totals.get(provider, [0, 0.0])[0] + sent + made, totals.get(provider, [0, 0.0])[1] + usd]
        lines.append(f"{provider:<5}{model:<40}{price[0]:>7.3f}{price[1]:>7.2f}  ${usd:.3f}")
    lines += [f"total {provider}: {tokens} tokens, ${usd:.2f}" for provider, (tokens, usd) in totals.items()]
    (out / "estimate.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join([lines[0], *lines[-len(totals):]]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    verbs = parser.add_subparsers(dest="verb", required=True)
    one = verbs.add_parser("run")
    one.add_argument("out")
    one.add_argument("--provider", choices=sorted(UPSTREAMS) + ["agent"], default="nano")
    one.add_argument("--model", default="")
    one.add_argument("--spend", type=float, default=1.0)
    one.add_argument("--fake", action="store_true")
    one.add_argument("--server", default=str(ROOT / "target" / "debug" / "cardwave-server.exe"))
    one.set_defaults(act=run)
    one = verbs.add_parser("figures")
    one.add_argument("out")
    one.set_defaults(act=figures)
    one = verbs.add_parser("estimate")
    one.add_argument("out")
    one.add_argument("run")
    one.set_defaults(act=estimate)
    args = parser.parse_args()
    args.act(args)


if __name__ == "__main__":
    main()
