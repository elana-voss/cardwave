"""Measures the classifier of a card's needs on a live model against the needs the cards were written for (`aimed_at`, milestone 120), and how far its arms and a reader's hand labels agree. No reader is a truth: against one this tool prints agreement, no pass, mark, right or wrong.

All it writes goes to OUT, a folder outside the repo: cards there are private. It prints figures and ids only. In this order:

  set OUT [--from FOLDER]        the sibling project's cards, both folders' index.json (a missing index is zero cards); with --from, FOLDER's alone: a set that needs no label, its truth FOLDER's `aimed_at`, all one half
  split OUT                      a set with labels: its halves (a character's cards in one half; never redrawn)
  ask OUT [--model M] --half tune|held|all [--limit 1500000] [--workers 4] [--again]   the live model; resumes; stops at the limit
  sample OUT [--model M] --limit N [--again]   the fixed 30 cards of the tune half asked twice on the prompt in the crates: its shape, found and first ten, and how steady it is; to OUT/sample-<arm>.txt. Run again and its figures written beside the old ones whenever the prompt or the reading model changes
  served OUT --model M --data FOLDER   the first 20 of the sample through the running app (target/debug/cardwave-server.exe, FOLDER fresh and outside the repo, the Helper model M, a database key made for the run) and its figures beside the tool's two rounds of `sample`; arm `served-<prompt mark>@M`. The app reports no spend
  again-cost OUT [--cards 5]     a character's calls in "Describe all again" (classify, write, needs), figures only; after `set`
  posters OUT [--cards 20] [--model M] [--limit 300000] [--workers 4]   a poster's tagline and mood from the prompts in the crates: classify, then write, a refused card replaced by the next; resumes; answers to OUT/posters.jsonl, counts within the limits and of each mood printed, for a reader to judge; after `set`
  cost OUT                       what each arm cost and answered, nothing of what it found
  figures OUT --half tune        every arm, with "b order" and the agreement table; to OUT/figures-aimed-tune.txt
  figures OUT --half held|all --arm ARM   one arm alone, so no other answer on that half is read; an arm of a form in RANKED orders by level, then rank, then title

An arm is `app-` and the first 8 of the filled prompt's sha256, so a changed prompt is a new arm and never replays old answers; then `#round` where a card is asked twice, `@model` off MODEL, the model earlier tests used (the app names none: it runs on the one the user sets). Stored arms, read but no longer asked: `strength` the prompt of 120, `b` the same words before ranks were kept, `own` answers from before 120. `figures` without --arm leaves out arms with a round. Key from NANOGPT_API_KEY, never printed. A label is a line of OUT/labels.txt: `t-man-p05 sex3 desired2`, `n-x -` for no need, `n-y out` for a card left out.

First ten: the share of the aimed cards standing among the first 10 shown under their aimed need; a card with no aim is in no share, but shown and takes places. Traps: the prompts and the list come from the crates. `--limit` counts all of results.jsonl, in and out. A card's character is its folder's mark and the last part of its file name.

The app driver and the card file: tools/measure_common.py. The call is the app's request as first run leaves it: its prompt and reading, the card as `card_text` in describe.rs writes it (one spaced line, title first, a character's name first), streamed, no token limit, no sampling. The stream reports no usage on some models: then the tally is four characters a token. Arms before this were asked in other forms: `app-af966b5e` spaced on one line, the title first, not streamed, its mark only the prompt; `app-fba3466a` compact, streamed, which is how the app sent it until a compact card got compact answers, 10 of 49 of them broken JSON on glm-5.3; `app-f253d06d` and `app-443eed30` indented, keys sorted and title first, first ten 82 and 81 of 107.
"""

import argparse
import hashlib
import http.client
import json
import os
import random
import re
import subprocess
import sys
import threading
import time
import unicodedata
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from itertools import zip_longest
from pathlib import Path

from measure_common import App, start_app, v2_card

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "crates" / "cw-library" / "src"
SIBLING = ROOT.parent / "cardwave-next-cardgentest" / "out" / "usable"
ADDRESS = "https://nano-gpt.com/api/v1/chat/completions"
MODEL = "xiaomi/mimo-v2.6-flash"  # The model earlier tests used; an arm on it carries no @model.
SEED = 116
CUTS = (2, 3)
# The cards of the sample and the most of a need's first places read.
SAMPLE, FIRST = 30, 10
SERVED = 20
SERVER = ROOT / "target" / "debug" / "cardwave-server.exe"
PROVIDER = "https://nano-gpt.com/api/v1"


SENT = "\none line, in order, streamed"  # in an arm's mark: what the tool sends is part of what an arm measures


def needs_list() -> list[tuple[str, str]]:
    source = (LIBRARY / "needs.rs").read_text(encoding="utf-8")
    block = source[source.index("pub const LIST") : source.index("/// The most of a refusal")]
    found = re.findall(r'\("([a-z_]+)",\s*"([^"]+)"\)', block)
    assert len(found) == 31, len(found)
    return found


def filled(prompt: str) -> str:
    lines = [f"{name}: I need {words}" for name, words in needs_list()]
    return prompt.replace("{needs}", "\n".join(lines))


def own_prompt() -> str:
    return filled((LIBRARY / "describe" / "needs.txt").read_text(encoding="utf-8"))


def messages_of(prompt: str, card: dict) -> list[dict]:
    text = json.dumps(card, ensure_ascii=False)
    return [{"role": "system", "content": prompt}, {"role": "user", "content": f"<card_to_read>\n{text}\n</card_to_read>"}]


def mark_of(prompt: str) -> str:
    return hashlib.sha256((prompt + SENT).encode()).hexdigest()[:8]


def arm_of(model: str, prompt: str, round_: int = 0) -> str:
    arm = f"app-{mark_of(prompt)}"
    if round_:
        arm += f"#{round_}"
    return arm if model == MODEL else f"{arm}@{model}"


def form_of(arm: str) -> str:
    return arm.split("@")[0].split("#")[0]


def ranked(arm: str) -> bool:
    """Whether the arm's stated order is what ranks a need within its card."""
    return form_of(arm) == "strength" or arm.startswith(("app-", "served-"))


def answered_object(text: str) -> dict | None:
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        return None
    try:
        value = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def valid_entry(entry, names: set) -> bool:
    """A need of the list at a level of 0 to 3, as the app's `read` takes it (a level `true` is none)."""
    if not isinstance(entry, dict) or not isinstance(entry.get("need"), str):
        return False
    return entry["need"] in names and type(entry.get("level")) is int and 0 <= entry["level"] <= 3


def readable(needs, names: set, verdict="classified") -> bool:
    """Whether the app would read an answer's `needs`; an empty list is an answer, of a card classified."""
    if not isinstance(needs, list):
        return False
    classified = str(verdict).strip().lower() == "classified"
    return (not needs and classified) or any(valid_entry(entry, names) for entry in needs)


def read_needs(answer: dict, names: set) -> dict:
    levels: dict = {}
    for entry in answer["needs"]:
        if valid_entry(entry, names):
            levels[entry["need"]] = max(levels.get(entry["need"], 0), entry["level"])
    return levels


def read_ranks(answer: dict, names: set) -> dict:
    """Each need above 0 by its place among such needs, in the answer's stated order; a need said twice keeps its first."""
    ranks: dict = {}
    for entry in answer["needs"]:
        if valid_entry(entry, names) and entry["level"] > 0:
            ranks.setdefault(entry["need"], len(ranks))
    return ranks


def as_card(raw: dict) -> dict | None:
    """A card as `card_json` in describe.rs gives it to the model; None for what is no character card."""
    data = raw["data"] if isinstance(raw.get("data"), dict) else raw
    text = lambda key: str(data.get(key) or "").strip()
    alternates = data.get("alternate_greetings")
    alternates = [str(g).strip() for g in alternates] if isinstance(alternates, list) else []
    if len(text("description") + text("personality") + text("first_mes")) < 200:
        return None
    tags = data.get("tags")
    return {
        "title": text("name"),
        "tags": [str(tag) for tag in tags] if isinstance(tags, list) else [],
        "characters": [
            {
                "name": text("name"),
                "description": text("description"),
                "personality": text("personality"),
                "scenario": text("scenario"),
                "first_mes": text("first_mes"),
                "alternate_greetings": alternates,
                "mes_example": text("mes_example"),
            }
        ],
    }


def character(mark: str, stem: str) -> str:
    """One character whichever way it was written: the folder's mark and the last part of the file's name."""
    return f"{mark}-{stem.rsplit('-', 1)[-1]}"


def set_cards(args) -> None:
    out = Path(args.out).resolve()
    if out.is_relative_to(ROOT):
        sys.exit("OUT stays outside the repo: cards are private")
    if (out / "split.json").exists():
        sys.exit("already split: the set stays as it is")
    cards, no_card, aimed = {}, 0, {}
    source = getattr(args, "source", None)
    folders = (("n", Path(source)),) if source else (("t", SIBLING / "test-cards"), ("n", SIBLING / "needs-set"))
    for mark, folder in folders:
        index = folder / "index.json"
        entries = json.loads(index.read_text(encoding="utf-8-sig")) if index.exists() else []
        for entry in entries:
            stem = Path(entry["file"]).stem
            card = as_card(json.loads((folder / entry["file"]).read_text(encoding="utf-8-sig")))
            if card is None:
                no_card += 1
            else:
                cards[f"{mark}-{stem}"] = {"card": card, "character": character(mark, stem)}
        if source:
            aimed = {card: need for card, need in aimed_from(entries).items() if card in cards}
    out.mkdir(parents=True, exist_ok=True)
    if source:
        (out / "aimed.json").write_text(json.dumps(aimed), encoding="utf-8")
    (out / "cards.json").write_text(json.dumps(cards, ensure_ascii=False), encoding="utf-8")
    print(f"cards {len(cards)}; characters {len({item['character'] for item in cards.values()})}; no card {no_card}")


def split(args) -> None:
    out = Path(args.out)
    if (out / "split.json").exists():
        sys.exit("already split: it is never redrawn")
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    labels = labels_of(out)
    if any(card not in labels for card in cards):
        sys.exit("labels are missing; label first")
    sizes = Counter(item["character"] for card, item in cards.items() if labels[card] != "out")
    characters = sorted({item["character"] for item in cards.values()})
    random.Random(SEED).shuffle(characters)
    halves, tune = {}, 0
    for one in characters:
        halves[one] = "tune" if tune < sum(sizes.values()) / 2 else "held"
        tune += sizes[one] if halves[one] == "tune" else 0
    (out / "split.json").write_text(json.dumps(halves), encoding="utf-8")
    print(f"tune {tune} cards; held {sum(sizes.values()) - tune} cards, of {len(characters)} characters")


def half(out: Path, which: str) -> set:
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    if which == "all":
        return set(cards)
    if not (out / "split.json").exists():
        sys.exit("not split yet")
    halves = json.loads((out / "split.json").read_text(encoding="utf-8"))
    return {card for card, item in cards.items() if halves[item["character"]] == which}


def sample_of(out: Path) -> list:
    """The fixed 30 of the tune half, in the order drawn: the first 20 are as random as all 30."""
    return random.Random(SEED).sample(sendable(out, half(out, "tune")), SAMPLE)


def to_send(labels: dict, ids: set) -> list:
    """Only what a reader has read and not left out."""
    return sorted(card for card in ids if isinstance(labels.get(card), dict))


def sendable(out: Path, ids: set) -> list:
    """What `ask` sends and the figures go over: all of a set from a folder, else what `to_send` leaves."""
    return sorted(ids) if (out / "aimed.json").exists() else to_send(labels_of(out), ids)


def reply_of_stream(lines) -> dict:
    """A stream's `data:` lines as one reply of the form a call without streaming returns."""
    text, finish, usage = "", None, None
    for line in lines:
        line = line.decode("utf-8").strip()
        if not line.startswith("data:") or line[5:].strip() == "[DONE]":
            continue
        piece = json.loads(line[5:])
        if "error" in piece:
            return {"failed": "stream error"}
        usage = piece.get("usage") or usage
        for choice in piece.get("choices") or []:
            text += (choice.get("delta") or {}).get("content") or ""
            finish = choice.get("finish_reason") or finish
    return {"choices": [{"finish_reason": finish, "message": {"content": text}}], "usage": usage}


def call(messages: list[dict], model: str, key: str, attempts: int = 4, usage: bool = False) -> dict:
    sent = {"model": model, "messages": messages, "stream": True} | ({"stream_options": {"include_usage": True}} if usage else {})
    body = json.dumps(sent).encode()
    for attempt in range(attempts):
        request = urllib.request.Request(
            ADDRESS,
            body,
            {"Authorization": f"Bearer {key}", "Content-Type": "application/json", "User-Agent": "Cardwave"},
        )
        try:
            with urllib.request.urlopen(request, timeout=600) as response:
                return reply_of_stream(response)
        except urllib.error.HTTPError as failure:
            if failure.code not in (408, 429, 500, 502, 503, 504) or attempt == attempts - 1:
                return {"failed": f"http {failure.code}"}
        except (OSError, ValueError, http.client.HTTPException) as failure:
            if attempt == attempts - 1:
                return {"failed": type(failure).__name__}
        time.sleep(15 * (attempt + 1))
    return {"failed": "gave up"}


def results_of(out: Path) -> list[dict]:
    path = out / "results.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def tokens(reply: dict, messages: list, answer: str) -> tuple[int, int]:
    """A call's tokens in and out as the provider reports them; without them, four characters a token, so the stop still holds."""
    usage = reply.get("usage") or {}
    if "prompt_tokens" in usage or "completion_tokens" in usage:
        return usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)
    return sum(len(message["content"]) for message in messages) // 4, len(answer) // 4


def classify_prompt() -> str:
    """`classify` in describe.rs: `classify.txt` with the vocabulary's groups in their places."""
    source = (LIBRARY / "describe.rs").read_text(encoding="utf-8")
    block = source[source.index("const VOCABULARY") : source.index("/// The classifier's prompt")]
    prompt = (LIBRARY / "describe" / "classify.txt").read_text(encoding="utf-8")
    for name, body in re.findall(r'\(\s*"([a-z_-]+)",\s*&\[(.*?)\],?\s*\)', block, re.S):
        entries = [entry.replace('\\"', '"') for entry in re.findall(r'"((?:[^"\\]|\\.)*)"', body)]
        prompt = prompt.replace("{" + name + "}", ("\n  " if any(":" in entry for entry in entries) else ", ").join(entries))
    assert not re.search(r"(?<!\{)\{[a-z_-]+\}(?!\})", prompt), "a group not filled"
    return prompt


def again_cost(args) -> None:
    """Milestone 123: what a character costs "Describe all again": classify, write, needs; usage as reported; figures only."""
    key = os.environ.get("NANOGPT_API_KEY")
    if not key:
        sys.exit("NANOGPT_API_KEY is not set")
    out = Path(args.out).resolve()
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    chosen = random.Random(SEED).sample(sorted(cards), args.cards)
    spent, rows = 0, []
    for card in chosen:
        if spent >= args.limit:
            print("stopped at the limit")
            break
        text = json.dumps(cards[card]["card"], ensure_ascii=False)
        row = {"card_chars": len(text), "reported": True, "in": 0, "out": 0, "failed": []}

        def asked_one(name: str, system: str, user: str) -> str:
            messages = [{"role": "system", "content": system}, {"role": "user", "content": user}]
            reply = call(messages, args.model, key, 2, usage=True)
            if "failed" in reply:
                row["failed"].append(name)
                return ""
            answer = (reply["choices"][0].get("message") or {}).get("content") or ""
            row["reported"] = row["reported"] and bool(reply.get("usage"))
            used = tokens(reply, messages, answer)
            row[name] = used
            row["in"] += used[0]
            row["out"] += used[1]
            return answer

        facets = asked_one("classify", classify_prompt(), f"<card_to_classify>\n{text}\n</card_to_classify>")
        read = answered_object(facets) or {}
        row["refused"] = str(read.get("verdict", "")).strip().lower().startswith("reject")
        if read and not row["refused"]:
            asked_one("write", (LIBRARY / "describe" / "write.txt").read_text(encoding="utf-8"), f"<card>\n{text}\n</card>\n<facets>\n{json.dumps(read, ensure_ascii=False)}\n</facets>")
        asked_one("needs", own_prompt(), f"<card_to_read>\n{text}\n</card_to_read>")
        spent += row["in"] + row["out"]
        rows.append(row)
        (out / "again-cost.json").write_text(json.dumps(rows), encoding="utf-8")
        print({name: row.get(name) for name in ("card_chars", "classify", "write", "needs", "reported", "refused", "failed")}, "total", row["in"] + row["out"])
    print(f"spent {spent}; characters {len(rows)}")


def posters(args) -> None:
    """Milestone 124a: tagline and mood as "Describe all again" asks them; the app's own limits (`describe/poster.rs`)."""
    key = os.environ.get("NANOGPT_API_KEY")
    if not key:
        sys.exit("NANOGPT_API_KEY is not set")
    out = Path(args.out).resolve()
    path = out / "posters.jsonl"
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    labels = labels_of(out)
    order = [card for card in random.Random(SEED).sample(sorted(cards), len(cards)) if labels.get(card) != "out"]
    rows = {row["id"]: row for row in map(json.loads, path.read_text(encoding="utf-8").splitlines())} if path.exists() else {}
    write_prompt = (LIBRARY / "describe" / "write.txt").read_text(encoding="utf-8")
    lock = threading.Lock()

    def one(card: str) -> None:
        text = json.dumps(cards[card]["card"], ensure_ascii=False)
        row: dict = {"id": card, "in": 0, "out": 0}

        def ask(system: str, user: str) -> str:
            messages = [{"role": "system", "content": system}, {"role": "user", "content": user}]
            reply = call(messages, args.model, key, 3, usage=True)
            if "failed" in reply:
                row["failed"] = reply["failed"]
                return ""
            answer = (reply["choices"][0].get("message") or {}).get("content") or ""
            used = tokens(reply, messages, answer)
            row["in"] += used[0]
            row["out"] += used[1]
            return answer

        facets = answered_object(ask(classify_prompt(), f"<card_to_classify>\n{text}\n</card_to_classify>")) or {}
        row["refused"] = str(facets.get("verdict", "")).strip().lower().startswith("reject")
        if facets and not row["refused"]:
            written = answered_object(ask(write_prompt, f"<card>\n{text}\n</card>\n<facets>\n{json.dumps(facets, ensure_ascii=False)}\n</facets>")) or {}
            row |= {"tagline": written.get("tagline"), "mood": written.get("mood"), "logline": written.get("logline")}
        with lock:
            rows[card] = row
            with path.open("a", encoding="utf-8") as stored:
                stored.write(json.dumps(row, ensure_ascii=False) + "\n")

    def answered() -> int:
        return sum(not rows[card].get("refused") for card in order if card in rows)

    def spent() -> int:
        return sum(row["in"] + row["out"] for row in rows.values())

    while answered() < args.cards and spent() < args.limit:
        batch = [card for card in order if card not in rows][: args.cards - answered()]
        if not batch:
            break
        with ThreadPoolExecutor(args.workers) as pool:
            list(pool.map(one, batch))
    done = [row for row in rows.values() if not row.get("refused")]
    moods = ("horror", "romance", "drama", "action", "sci_fi", "comedy", "fantasy")

    def fits(row: dict) -> bool:
        line = " ".join(str(row.get("tagline") or "").split()).strip('"\u201c\u201d ')
        return bool(line) and len(line.split(" ")) <= 8 and len(line) <= 42

    said = Counter(str(row.get("mood") or "").strip().lower().replace("-", "_").replace(" ", "_") for row in done)
    print(f"cards {len(done)}; refused {len(rows) - len(done)}; failed {sum('failed' in row for row in done)}; within the limits {sum(map(fits, done))}; spent {spent()}")
    print("moods", {mood: said[mood] for mood in moods}, "other", sum(count for mood, count in said.items() if mood not in moods))


def asked(out: Path, args, arm: str, jobs: list, prompt: str) -> None:
    """Asks `arm` of the cards `jobs` not yet answered, stopping at the limit; `--again` also those failed or unread."""
    key = os.environ.get("NANOGPT_API_KEY")
    if not key:
        sys.exit("NANOGPT_API_KEY is not set")
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    results = results_of(out)
    done = {(row["id"], row["arm"]) for row in results if "failed" not in row}
    if args.again:
        done -= ask_again(out)
    spent = sum(row.get("in", 0) + row.get("out", 0) for row in results)
    jobs = [card for card in jobs if (card, arm) not in done]
    lock = threading.Lock()
    tally = {"spent": spent, "stopped": False}

    def one(card) -> None:
        with lock:
            if tally["spent"] >= args.limit:
                tally["stopped"] = True
                return
        started = time.time()
        messages = messages_of(prompt, cards[card]["card"])
        reply = call(messages, args.model, key, args.attempts)
        row: dict = {"id": card, "arm": arm, "seconds": round(time.time() - started, 1)}
        if "failed" in reply:
            row["failed"] = reply["failed"]
        else:
            choice = (reply.get("choices") or [{}])[0]
            row["finish"] = choice.get("finish_reason")
            row["answer"] = (choice.get("message") or {}).get("content") or ""
            row["in"], row["out"] = tokens(reply, messages, row["answer"])
        with lock:
            tally["spent"] += row.get("in", 0) + row.get("out", 0)
            with (out / "results.jsonl").open("a", encoding="utf-8") as file:
                file.write(json.dumps(row, ensure_ascii=False) + "\n")

    with ThreadPoolExecutor(args.workers) as pool:
        list(pool.map(one, jobs))
    print(f"{arm}: asked {len(jobs)} jobs; tokens so far {tally['spent']}; stopped at the limit: {tally['stopped']}")


def ask(args) -> None:
    out = Path(args.out)
    prompt = own_prompt()
    wanted = half(out, args.half)
    unread = 0 if (out / "aimed.json").exists() else sum(card not in labels_of(out) for card in wanted)
    if unread:
        print(f"{unread} cards not sent: no reader has read them")
    asked(out, args, arm_of(args.model, prompt), sendable(out, wanted), prompt)


def latest(out: Path) -> dict:
    """Each (card, arm)'s last answer, read: its state, and the levels of one that was asked."""
    names = {name for name, _ in needs_list()}
    found: dict = {}
    for row in results_of(out):
        if "failed" in row:
            found.setdefault((row["id"], row["arm"]), {"state": "failed", **row})
            continue
        answer = answered_object(row["answer"])
        item = {**row, "object": answer}
        if answer is None:
            item["state"] = "unread"
        elif str(answer.get("verdict", "")).strip().lower().startswith("reject"):
            item["state"] = "refused"
        elif not readable(answer.get("needs"), names, answer.get("verdict")):
            item["state"] = "unread"
        else:
            item["state"] = "asked"
            item["levels"] = read_needs(answer, names)
            item["ranks"] = read_ranks(answer, names)
        found[(row["id"], row["arm"])] = item
    return found


def cost(args) -> None:
    out = Path(args.out)
    rows = results_of(out)
    print("spent", sum(r.get("in", 0) + r.get("out", 0) for r in rows))
    answers = latest(out)
    for arm in sorted({key[1] for key in answers}):
        mine = [item for key, item in answers.items() if key[1] == arm]
        count = {s: sum(1 for i in mine if i["state"] == s) for s in ("asked", "refused", "unread", "failed")}
        fine = [i for i in mine if i["state"] != "failed"]
        n = max(1, len(fine))
        print(
            f"{arm}: {count}; in {sum(i.get('in', 0) for i in fine) // n}, out {sum(i.get('out', 0) for i in fine) // n}"
            f", seconds {sum(i['seconds'] for i in fine) / n:.0f} a card; cut off {sum(i.get('finish') == 'length' for i in fine)}"
        )


def labels_of(out: Path) -> dict:
    path = out / "labels.txt"
    labels: dict = {}
    names = {name for name, _ in needs_list()}
    if not path.exists():
        return labels
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        if parts[1] == "out":
            labels[parts[0]] = "out"
            continue
        levels = {}
        for part in parts[1:]:
            if part == "-":
                continue
            match = re.fullmatch(r"([a-z_]+)([123])", part)
            assert match and match[1] in names, line
            levels[match[1]] = int(match[2])
        labels[parts[0]] = levels
    return labels


def name_order(title: str) -> str:
    """As `name_order` in cards.rs: no combining marks, lower case."""
    return "".join(c.lower() for c in unicodedata.normalize("NFD", title) if not unicodedata.category(c).startswith("M"))


def in_order(rows: list[dict], need: str, cut: int, by_rank: bool = False) -> list[dict]:
    """The rows shown under a need at a cut-off, as By need orders them: by level, then (where asked) the need's rank in the card, then title."""
    shown = [row for row in rows if row["levels"].get(need, 0) >= cut]

    def key(row: dict) -> tuple:
        rank = row["ranks"].get(need, 0) if by_rank else 0
        return -row["levels"][need], rank, name_order(row["title"]), row["id"]

    return sorted(shown, key=key)


def aimed_from(entries: list[dict]) -> dict:
    """A card of the needs-set's index by its id, with the name of the need it was written for; words off the list are an error."""
    by_words = {words: name for name, words in needs_list()}
    return {f"n-{Path(entry['file']).stem}": by_words[entry["aimed_at"]] for entry in entries}


def aimed_cards() -> dict:
    index = SIBLING / "needs-set" / "index.json"
    return aimed_from(json.loads(index.read_text(encoding="utf-8-sig")))


def aimed_of(out: Path) -> dict:
    """The truth of a set: a set from a folder holds its own, the older set is the needs-set's."""
    path = out / "aimed.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else aimed_cards()


def truth_figures(rows: list[dict], aimed: dict, names: list[str], cut: int, by_rank: bool) -> dict:
    """Against the aimed needs, over the rows' aimed cards: found, first ten, each pooled; shown per need as a share of all the rows; per need (aimed, found, in first ten)."""
    lists = {need: in_order(rows, need, cut, by_rank) for need in names}
    firsts = {need: {row["id"] for row in shown[:10]} for need, shown in lists.items()}
    mine = [row for row in rows if row["id"] in aimed]
    per_need = dict.fromkeys(names, (0, 0, 0))
    for row in mine:
        need = aimed[row["id"]]
        count, found, first = per_need[need]
        per_need[need] = (count + 1, found + (row["levels"].get(need, 0) >= cut), first + (row["id"] in firsts[need]))
    total = max(1, len(mine))
    return {
        "cards": len(mine),
        "found": sum(figures[1] for figures in per_need.values()) / total,
        "first_ten": sum(figures[2] for figures in per_need.values()) / total,
        "shown": {need: len(shown) / max(1, len(rows)) for need, shown in lists.items()},
        "per_need": per_need,
    }


def agreement(one: list[dict], two: list[dict], cut: int) -> float:
    """What two readers both show of what either shows, over (card, need). No truth: neither is right."""

    def pairs(rows: list[dict]) -> set:
        return {(row["id"], need) for row in rows for need, level in row["levels"].items() if level >= cut}

    first, second = pairs(one), pairs(two)
    return len(first & second) / len(first | second) if first | second else 0.0


def answered_rows(cards: dict, answers: dict, arm: str, ids: list) -> tuple[list[dict], Counter]:
    """The half's rows as an arm answered them; a card it did not answer shows under no need."""
    rows, states = [], Counter()
    for card in ids:
        item = answers.get((card, arm), {})
        states[item.get("state", "not asked")] += 1
        rows.append({"id": card, "title": cards[card]["card"]["title"], "levels": item.get("levels", {}), "ranks": item.get("ranks", {}), "answered": item.get("state") == "asked"})
    return rows, states


def shape(rows: list[dict], cut: int = 2) -> dict:
    """How the answered rows' counted needs fall: per card, at the cap of 5, at the top level, cards with one or two at the top."""
    levels = [[level for level in row["levels"].values() if level >= cut] for row in rows if row["answered"]]
    counts = sorted(len(card) for card in levels)
    tops = [card.count(3) for card in levels]
    return {
        "cards": len(levels),
        "mean": sum(counts) / max(1, len(counts)),
        "median": counts[len(counts) // 2] if counts else 0,
        "at_five": sum(count >= 5 for count in counts),
        "top_share": sum(tops) / max(1, sum(counts)),
        "one_or_two_top": sum(top in (1, 2) for top in tops),
    }


def shape_line(rows: list[dict]) -> str:
    made = shape(rows)
    return f"needs a card {made['mean']:.2f} (median {made['median']}), at 5 {made['at_five']} of {made['cards']}, at top {made['top_share']:.3f}, one or two at top {made['one_or_two_top']}"


def steadiness(one: list[dict], two: list[dict], names: list[str], cut: int = 2) -> dict:
    """Two askings of the same cards, in the same order, against each other: cards whose counted needs are identical (one not read in either is not), and of each need's first places those holding another card or none."""

    def counted(row: dict) -> set:
        return {need for need, level in row["levels"].items() if level >= cut}

    same = sum(a["answered"] and b["answered"] and counted(a) == counted(b) for a, b in zip(one, two))
    moved = filled = 0
    for need in names:
        for a, b in zip_longest(in_order(one, need, cut, True)[:FIRST], in_order(two, need, cut, True)[:FIRST]):
            filled += 1
            moved += not (a and b and a["id"] == b["id"])
    return {"cards": len(one), "identical": same, "moved": moved, "filled": filled}


def truth_table(name: str, rows: list[dict], aimed: dict, names: list[str], by_rank: bool, lines: list[str]) -> str:
    """One arm's figures into `lines`, with two readings beside (cards answered only; test-cards in no list); its summary line back."""
    answered = [row for row in rows if row["answered"]]
    no_test = [row for row in rows if row["id"] in aimed]
    summary = f"{name:24} {shape_line(rows)};"
    lines.append(f"{name}: {shape_line(rows)}")
    for cut in CUTS:
        result = truth_figures(rows, aimed, names, cut, by_rank)
        shown = sorted(result["shown"].values())
        summary += f" cut {cut} found {result['found']:.3f} first ten {result['first_ten']:.3f};"
        lines.append(f"{name} cut {cut}: found {result['found']:.3f}, first ten {result['first_ten']:.3f}, shown median {shown[len(shown) // 2]:.3f} of the half, over {result['cards']} aimed")
        for reading, those in (("answered only", answered), ("test-cards in no list", no_test), ("both", [row for row in no_test if row["answered"]])):
            other = truth_figures(those, aimed, names, cut, by_rank)
            lines.append(f"  {reading}: found {other['found']:.3f}, first ten {other['first_ten']:.3f}, over {other['cards']} aimed")
        lines.append("  need                 aimed found first-ten shown")
        for need in names:
            count, found, first = result["per_need"][need]
            lines.append(f"  {need:20} {count:5} {found:5} {first:9} {result['shown'][need]:5.3f}")
    return summary


def figures(args) -> None:
    out = Path(args.out)
    if args.half != "tune" and not args.arm:
        sys.exit("off the tune half, name the one arm: no other answer on that half is read")
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    names = [name for name, _ in needs_list()]
    answers, aimed, labels = latest(out), aimed_of(out), labels_of(out)
    ids = sendable(out, half(out, args.half))
    wanted = [args.arm] if args.arm else sorted({arm for card, arm in answers if card in ids and "#" not in arm and not arm.startswith("served-")})
    lines, summary, read = [], [], {}
    for arm in wanted:
        read[arm], states = answered_rows(cards, answers, arm, ids)
        lines.append(f"{arm}: states over {len(ids)} cards {dict(states)}; of the aimed, without any need {sum(not row['levels'] and row['id'] in aimed for row in read[arm])}")
        unread = sum(not row["answered"] for row in read[arm])
        summary.append(truth_table(arm, read[arm], aimed, names, ranked(arm), lines) + f" not read {unread}")
    if not args.arm:
        for arm in (arm for arm in wanted if form_of(arm) == "b"):
            summary.append(truth_table(arm.replace("b", "b order", 1), read[arm], aimed, names, True, lines))
        read["reader"] = [{"id": card, "levels": labels[card]} for card in ids]
        lines.append("agreement, shared of either shown over (card, need); no reader is the truth")
        for cut in CUTS:
            for first, second in ((a, b) for at, a in enumerate(read) for b in list(read)[at + 1 :]):
                lines.append(f"  cut {cut} {first:24} {second:24} {agreement(read[first], read[second], cut):.3f}")
            reader = [row for row in read["reader"] if row["id"] in aimed]
            on_reader = sum(row["levels"].get(aimed[row["id"]], 0) >= cut for row in reader)
            line = f"reader finds the aimed need at cut {cut}: {on_reader} of {len(reader)} ({on_reader / max(1, len(reader)):.3f}); an agreement figure"
            lines.append(line)
            summary.append(line)
    tail = "-" + args.arm.replace("/", "_").replace("@", "_") if args.arm else ""
    path = out / f"figures-aimed-{args.half}{tail}.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(summary))
    print(f"tables: {path}")


def sample(args) -> None:
    out = Path(args.out)
    prompt, ids = own_prompt(), sample_of(out)
    arms = [arm_of(args.model, prompt, round_) for round_ in (1, 2)]
    for arm in arms:
        asked(out, args, arm, ids, prompt)
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    answers, aimed, names = latest(out), aimed_of(out), [name for name, _ in needs_list()]
    one, two = (answered_rows(cards, answers, arm, ids)[0] for arm in arms)
    lines: list[str] = []
    print(truth_table(arms[0], one, aimed, names, True, lines) + f" not read {sum(not row['answered'] for row in one)}")
    print(truth_table(arms[1], two, aimed, names, True, lines) + f" not read {sum(not row['answered'] for row in two)}")
    steady = steadiness(one, two, names)
    line = f"steady: {steady['identical']} of {steady['cards']} cards with identical counted needs; {steady['moved']} of {steady['filled']} first-ten places moved"
    print(line)
    path = out / f"sample-{arms[0].replace('/', '_').replace('@', '_').replace('#', '_')}.txt"
    path.write_text("\n".join(lines + [line]) + "\n", encoding="utf-8")
    print(f"tables: {path}")


def served_row(card: str, arm: str, shown: dict) -> dict:
    """A results row of what the app's `/api/cards/{id}` shows of a card's needs: those that count, the strongest first."""
    if shown["state"] == "failed":
        return {"id": card, "arm": arm, "seconds": 0, "failed": "the app's reading failed"}
    verdict = "reject" if shown["state"] == "refused" else "classified"
    needs = sorted(shown["needs"], key=lambda need: need["rank"])
    answer = {"verdict": verdict, "needs": [{"need": need["need"], "level": need["level"]} for need in needs]}
    return {"id": card, "arm": arm, "seconds": 0, "answer": json.dumps(answer), "in": 0, "out": 0}


def card_png(card: dict) -> bytes:
    """The smallest card file the app imports: one pixel and a SillyTavern V2 card of the card's first character."""
    return v2_card({**card["characters"][0], "tags": card["tags"]})


def app_read(app: App, cards: dict, ids: list, key: str, model: str) -> dict:
    """Sets the app's Helper model, imports the cards, has them described and read, and answers what it shows of each once all are ended."""
    app.must("PUT", "/api/provider", {"base_url": PROVIDER, "api_key": key, "model": model, "sampling": {}})
    place = next(kind["provider_id"] for kind in app.must("GET", "/api/provider-list")["kinds"] if kind["kind"] == "chat")
    app.must("PUT", "/api/kinds/background", {"provider_id": place, "model": model})
    made = {card: app.must("POST", "/api/cards", raw=card_png(cards[card]["card"]))["card_id"] for card in ids}
    app.must("POST", "/api/describe")

    def ended() -> dict:
        shown: dict = {}
        for _ in range(720):  # An hour at the most.
            shown = {card: app.must("GET", f"/api/cards/{made[card]}")["needs"] for card in ids}
            if all(item["state"] in ("found", "zero", "refused", "failed") for item in shown.values()):
                break
            time.sleep(5)
        return shown

    shown = ended()
    failed = sum(item["state"] == "failed" for item in shown.values())
    if failed:  # As the app's button does: the failed are asked once more, and before and after told.
        print(f"failed through the app: {failed}; why the last: {app.must('GET', '/api/describe').get('failure')}")
        app.must("POST", "/api/describe")
        time.sleep(5)
        shown = ended()
        print(f"after once more: {sum(item['state'] == 'failed' for item in shown.values())}")
    return shown


def served(args) -> None:
    out, data = Path(args.out), Path(args.data)
    key = os.environ.get("NANOGPT_API_KEY")
    if not key:
        sys.exit("NANOGPT_API_KEY is not set")
    if data.exists():
        sys.exit("the data folder must be fresh")
    data.mkdir(parents=True)
    prompt, ids = own_prompt(), sample_of(out)[:SERVED]
    cards = json.loads((out / "cards.json").read_text(encoding="utf-8"))
    arm = f"served-{mark_of(prompt)}@{args.model}"
    server = start_app(SERVER, args.port, data, subprocess.DEVNULL)
    app = App.local(args.port)
    try:
        app.wait(server, "nothing: the server's output is not kept")
        started = time.time()
        shown = app_read(app, cards, ids, key, args.model)
    finally:
        server.terminate()
        server.wait()
    seconds = round((time.time() - started) / len(ids), 1)
    with (out / "results.jsonl").open("a", encoding="utf-8") as file:
        for card in ids:
            file.write(json.dumps({**served_row(card, arm, shown[card]), "seconds": seconds}) + "\n")
    answers, aimed, names = latest(out), aimed_of(out), [name for name, _ in needs_list()]
    # The tool's arm of this form, and of the same line not streamed.
    tool_arms = [arm_of(args.model, prompt), f"app-af966b5e@{args.model}"]
    app, one, two = (answered_rows(cards, answers, name, ids)[0] for name in (arm, *tool_arms))
    lines: list[str] = []
    for name, rows in ((arm, app), (tool_arms[0], one), (tool_arms[1], two)):
        print(truth_table(name, rows, aimed, names, True, lines) + f" not read {sum(not row['answered'] for row in rows)}")
    for name, first, second in (("app against the tool's first", app, one), ("the tool's first against its unstreamed", one, two)):
        steady = steadiness(first, second, names)
        line = f"{name}: {steady['identical']} of {steady['cards']} cards with identical counted needs; {steady['moved']} of {steady['filled']} first-ten places moved"
        lines.append(line)
        print(line)
    path = out / f"served-{mark_of(prompt)}.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"seconds a card through the app, describing with it: {seconds}; tables: {path}")


def ask_again(out: Path) -> set:
    """The calls whose last answer failed or could not be read."""
    return {key for key, item in latest(out).items() if item["state"] in ("failed", "unread")}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    one = commands.add_parser("set")
    one.add_argument("out")
    one.add_argument("--from", dest="source")
    one.set_defaults(run=set_cards)
    one = commands.add_parser("split")
    one.add_argument("out")
    one.set_defaults(run=split)
    one = commands.add_parser("ask")
    one.add_argument("out")
    one.add_argument("--again", action="store_true")
    one.add_argument("--attempts", type=int, default=4)
    one.add_argument("--half", choices=("tune", "held", "all"), required=True)
    one.add_argument("--limit", type=int, default=1_500_000)
    one.add_argument("--model", default=MODEL)
    one.add_argument("--workers", type=int, default=4)
    one.set_defaults(run=ask)
    one = commands.add_parser("sample")
    one.add_argument("out")
    one.add_argument("--again", action="store_true")
    one.add_argument("--attempts", type=int, default=4)
    one.add_argument("--limit", type=int, required=True)
    one.add_argument("--model", default=MODEL)
    one.add_argument("--workers", type=int, default=4)
    one.set_defaults(run=sample)
    one = commands.add_parser("served")
    one.add_argument("out")
    one.add_argument("--data", required=True)
    one.add_argument("--model", required=True)
    one.add_argument("--port", type=int, default=8951)
    one.set_defaults(run=served)
    one = commands.add_parser("again-cost")
    one.add_argument("out")
    one.add_argument("--cards", type=int, default=5)
    one.add_argument("--limit", type=int, default=100_000)
    one.add_argument("--model", default="z-ai/glm-5.3")
    one.set_defaults(run=again_cost)
    one = commands.add_parser("posters")
    one.add_argument("out")
    one.add_argument("--cards", type=int, default=20)
    one.add_argument("--limit", type=int, default=300_000)
    one.add_argument("--model", default="z-ai/glm-5.3")
    one.add_argument("--workers", type=int, default=4)
    one.set_defaults(run=posters)
    one = commands.add_parser("cost")
    one.add_argument("out")
    one.set_defaults(run=cost)
    one = commands.add_parser("figures")
    one.add_argument("out")
    one.add_argument("--arm")
    one.add_argument("--half", choices=("tune", "held", "all"), required=True)
    one.set_defaults(run=figures)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
