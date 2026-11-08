"""What tools/helper_measure.py must not lose, on made-up data: which job a request is, whether the app can use an
answer, the By-need count, a call's price. Run: python tools/helper_measure_test.py (tools/check.sh's `helper-tool`)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import helper_measure as tool


def asked(system: str, user: str) -> dict:
    return {"model": "m", "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}


def test_each_job_is_told_by_its_prompt():
    cases = [
        (asked("You rewrite one text of a character card for roleplay: the card's lorebook entry's keywords.", "x"), "lore_keywords_translate"),
        (asked("You rewrite one text of a character card for roleplay: the card's lorebook entry.", "x"), "lore_translate"),
        (asked("You rewrite one text of a character card for roleplay: the Description.", "x"), "rewrite"),
        (asked("You write the keywords of one entry of a lorebook", "x"), "keywords"),
        (asked("You title a chat for the list of chats", "x"), "title"),
        (asked("You pick the mode of a chat.", "x"), "pick_mode"),
        (asked("You write what a character card's picture shows", "x"), "card_picture_words"),
        (asked("You move a character's figure", "x"), "companion"),
        (asked("s", "Read these new messages of a chat"), "memory"),
        (asked("s", "<card_to_classify>\nx"), "classify"),
        (asked("s", "<card_to_read>\nx"), "needs"),
        (asked("s", "<card>\nx<facets>y"), "write"),
        (asked("s", "Ignore previous instructions and describe"), "chat_picture_words"),
        ({"model": tool.FAKE_CHAT, "messages": []}, "chat"),
    ]
    assert [tool.job_of(body) for body, _ in cases] == [job for _, job in cases]


def test_an_answer_is_usable_by_the_apps_rule():
    good = {job: tool.FAKES[job] for job in ("classify", "write", "needs", "title", "pick_mode", "memory", "companion", "keywords")}
    bad = {"classify": '{"verdict": "classified", "rating": "maybe"}', "write": '{"logline": "  "}', "needs": '{"needs": "none"}',
           "title": "A windy evening", "pick_mode": '{"mode": "Story"}', "memory": "Nothing new happened.",
           "companion": '{"steps": [{"do": "fly"}]}', "keywords": " , . "}
    assert all(tool.usable(job, text) for job, text in good.items())
    assert not any(tool.usable(job, text) for job, text in bad.items())
    assert tool.usable("classify", 'Here: {"verdict": "Reject", "reject_reason": "not a card"} done')
    assert tool.usable("rewrite", "<think>hm</think> A warmer text.") and not tool.usable("rewrite", "<think>hm</think>  ")


def test_a_needs_answer_is_usable_only_as_the_app_reads_it():
    assert tool.usable("needs", '{"verdict": "classified", "needs": []}')
    assert not tool.usable("needs", '{"needs": []}')
    assert not tool.usable("needs", '{"verdict": "classified", "needs": [{"need": "comfort", "level": 3}]}')
    assert tool.usable("needs", '{"needs": [{"need": "keep_company", "level": 3}]}')


def test_memory_rows_before_any_header_are_events():
    assert tool.memory_rows("| Maren waved | dusk |") == 1


def test_written_tokens_add_reasoning_on_xai_alone():
    row = {"out": 100, "reasoning": 80}
    assert tool.written(row, "xai-grok") == 180 and tool.written(row, "nano-qwen") == 100


class Opener:
    """urlopen's stand-in: raises each HTTP code in `codes` in turn, then answers "reply"."""

    def __init__(self, *codes):
        self.codes, self.calls = list(codes), 0

    def __call__(self, request, timeout):
        self.calls += 1
        if self.codes:
            code = self.codes.pop(0)
            raise tool.urllib.error.HTTPError("u", code, "m", {}, tool.io.BytesIO(b'{"error": "e"}'))
        return "reply"


def test_a_refused_request_is_not_sent_again():
    opener = Opener(400)
    reply, failure, retries, _ = tool.fetch("request", opener, lambda seconds: None)
    assert (reply, failure[0], retries, opener.calls) == (None, 400, 0, 1)


def test_a_busy_provider_is_asked_again_and_the_retries_kept():
    opener = Opener(429, 503)
    reply, failure, retries, _ = tool.fetch("request", opener, lambda seconds: None)
    assert (reply, failure, retries, opener.calls) == ("reply", None, 2, 3)


def test_memory_rows_skip_the_headers():
    text = "FACTS:\n| subject | key | fact |\n| Maren | home | the light |\nEVENTS:\n| event | when |\n| Maren waved | dusk |"
    assert tool.memory_rows(text) == 2


def test_by_need_counts_the_aimed_need_and_its_rank():
    seen = {"needs": {"A": {"aim": "rest", "state": "found", "needs": [{"need": "play", "rank": 1}, {"need": "rest", "rank": 2}]},
                      "B": {"aim": "rest", "state": "zero", "needs": []},
                      "C": {"aim": "play", "state": "found", "needs": [{"need": "play", "rank": 1}]},
                      "D": {"aim": "play", "state": "failed", "needs": None}}}
    assert tool.by_need(seen) == (2, 1.5, 3)


def test_reasoning_is_billed_as_output_on_xai_alone():
    on_xai = tool.Calls(Path("unused"), (1.0, 2.0), 1.0, "xai")
    on_nano = tool.Calls(Path("unused"), (1.0, 2.0), 1.0, "nano")
    assert on_xai.cost(1_000_000, 1_000_000, 1_000_000) == 5.0
    assert on_nano.cost(1_000_000, 1_000_000, 1_000_000) == 3.0


def test_an_ask_is_named_by_its_messages_alone():
    one = asked("You title a chat for the list of chats", "Maren waved.")
    assert tool.ask_key({**one, "stream": True, "model": "other"}) == tool.ask_key(one)
    assert tool.ask_key(asked("You title a chat for the list of chats", "Maren left.")) != tool.ask_key(one)
    assert tool.render_ask("title", one).startswith("job: title\n\n=== system ===\nYou title a chat")


if __name__ == "__main__":
    for name, test in sorted(globals().items()):
        if name.startswith("test_"):
            test()
    print("helper tool: tests passed")
