"""Every text of the interview's source against the product's: python tools/interview_texts.py <IMPLEMENTATION.md>.

Reads each UPPER constant whose value is plain text or lists of it from the source's python blocks, flattens it,
and compares it with the string literals of the same `const` in crates/cw-library/src/interview/texts.rs; prints
each difference and fails on any but those in OURS and REWORDED, where the product means to differ. NEEDS is compared with the second column of needs.rs's LIST. Run by hand when the
source changes; the check `interview-texts` runs it where the source's folder lies beside this repo.
"""

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "crates" / "cw-library" / "src"
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"', re.S)

# The source's texts for its rewrite and its gender check, calls the product does not make (milestone 117).
DROPPED = {"USER_GENDER_CHECK", "CHECK_WHOLE", "CHECK_TREAT", "CHECK_CHARACTER", "SIDE_WHY"}
# The product's own words after a source's text, by constant: (what the source ends with, what the product adds).
OURS = {"INTERVIEWER": ("else none.", " Each choice is an answer the user could give, never a question.")}
# The source's texts the product words otherwise for the user (131), whole strings: {source: product}.
REWORDED = {
    "What would you like it to be to you, and what was missing before, with people or with characters you tried? Say it in your own words.": "What would you like the character to be to you?",
    "What would a friend say you'd enjoy in this?": "What would a friend say you'd enjoy in a character like this?",
    "What do you need then? I need...": "What would you want then?",
    "Should it treat you as a man or a woman?": "How should the character see you: as a man, as a woman, or neither?",
    "Anyone, no gender": "Neither",
    "You choose": "Let Cardwave choose",
    "Who are you to it, and who leads?": "Who are you to the character, and which of you takes the lead?",
    "Which you is this: you as you are, you in the future, or the you you want to be?": "Which you is it: you as you are now, you in the future, or who you want to be?",
    "you as you are": "you as you are now",
    "the you you want to be": "who you want to be",
    "At what?": "Get better at what?",
    "Over what?": "In control of what?",
    "In what way?": "Lose control in what way?",
    "What kind of thing?": "What would you do that you're not allowed to?",
    "Where?": "Where would you like to be?",
    "To whom?": "Say it to whom?",
    "What would it be for?": "What would your purpose be?",
    "to be pushed": "to be pushed to do more",
    "being told": "being told I'm wanted",
    "rough": "rough play",
    "being taken in hand": "someone else taking charge of me",
    "a hard talk": "a difficult conversation",
    "break character": "step out of the role",
    "A partner": "A life partner",
    'You said: "{}". Why does that matter to you right now?': 'You said "{}". Why does that matter to you right now?',
}


def unescape(body):
    body = re.sub(r"\\\r?\n\s*", "", body)
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m[1], m[1]), body, flags=re.S)


def flat(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for k, v in value.items() for s in flat(k) + flat(v)]
    if isinstance(value, (list, tuple)):
        return [s for v in value for s in flat(v)]
    return []


def source(md):
    found = {}
    for block in re.findall(r"```python\n(.*?)```", md, re.S):
        for node in ast.parse(block).body:
            if not isinstance(node, ast.Assign) or not isinstance(node.targets[0], ast.Name):
                continue
            name = node.targets[0].id
            if not name.isupper() or name.startswith("_"):
                continue
            try:
                strings = flat(ast.literal_eval(node.value))
            except ValueError:
                continue
            if strings:
                found[name] = strings
    return found


def product():
    texts = (LIB / "interview" / "texts.rs").read_text(encoding="utf-8").replace("\r\n", "\n")
    found = {}
    for name, body in re.findall(r"^pub const (\w+):[^=]*=(.*?);\n(?=\S|\Z)", texts, re.S | re.M):
        found[name] = [unescape(s) for s in LITERAL.findall(body)]
    needs = (LIB / "needs.rs").read_text(encoding="utf-8")
    table = re.search(r"pub const LIST:.*?\n\];", needs, re.S)[0]
    found["NEEDS"] = [unescape(s) for s in re.findall(r'\("[^"]*",\s*"((?:[^"\\]|\\.)*)"\)', table)]
    return found


def main():
    theirs, ours, bad = source(Path(sys.argv[1]).read_text(encoding="utf-8")), product(), 0
    for name, strings in theirs.items():
        if name in DROPPED:
            continue
        if name not in ours:
            print(f"{name}: not in the product")
            bad += 1
            continue
        strings = [REWORDED.get(s, s) for s in strings]
        if name in OURS and strings[-1].endswith(OURS[name][0]):
            strings = [*strings[:-1], strings[-1] + OURS[name][1]]
        if ours[name] != strings:
            pairs = zip(strings, ours[name])
            at = next((i for i, (a, b) in enumerate(pairs) if a != b), min(len(strings), len(ours[name])))
            print(f"{name}: differs at {at}: {strings[at:at + 1]!r} / {ours[name][at:at + 1]!r}")
            bad += 1
    print(f"{len(theirs)} constants, {bad} differ")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
