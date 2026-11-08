"""Prints, and exits 1 on, an English sentence a crate or the server may hand the page; tools/check.sh's `sentences`.

Found: a field set to, or a list given (`.push(`), a literal or format! that starts with two words ("Searching the
web: {}"), or one set by let, a match arm or else that starts with a capital ("Before step {}"), in src/ outside test
code (a tests file, or from `#[cfg(test)] mod tests {` on). The page words what it shows from codes and fields. Allowed
(ALLOWED), as only a model, the log or an error's code reads them: the fields role, talks_low, talks_high, what (a
prompt's or the log's words), noun (NotFound's code), name (a thing's own name); a tool's answer to the model (cw-coding
tools.rs text) and the interview's private list for the writer (interview/private.rs); by let, arm or else, the prompts
(interview, rewrite.rs, cw-prompt builder.rs, cw-chat's reply, inputs, companion and memory, cw-coding's brief), a
tool's answer (app_tools.rs, cw-coding's by text) and MCP's (both mcp.rs). One word ("Untitled") it cannot tell from a code.

Usage, from the repo's root: python tools/sentences.py
"""

import re
import subprocess
import sys

TEST_CODE = re.compile(r"^#\[cfg\(test\)\]\s*mod \w+ \{.*", re.M | re.S)
FOUND = re.compile(
    r'(?:^[ \t]*(?P<field>[a-z_]+): |\.(?P<push>push)\(\s*)(?:format!\(\s*)?"(?P<two>[A-Za-z]+ [a-z]+[^"\n]*)"'
    r'|(?:\blet (?:mut )?(?P<let>[a-z_]+)(?::[^=;\n]+)? = |(?P<arm>=>) |(?P<else>else) \{\s*)'
    r'(?:format!\(\s*)?"(?P<capital>[A-Z][a-z]* [a-z]+[^"\n]*)"',
    re.M,
)
PROMPTS = (
    r"crates/cw-library/src/(interview|rewrite)|crates/cw-prompt/src/builder|server/src/api/(app_tools|mcp)"
    r"|crates/cw-store/src/mcp|crates/cw-chat/src/(companion|chats/reply|chats/inputs|memory)"
)
ALLOWED = re.compile(
    r"^[^ ]+: (role|talks_low|talks_high|what|noun|name): "
    r"|^crates/cw-coding/src/tools\.rs: text: "
    r"|^crates/cw-library/src/interview/private\.rs: push: "
    rf"|^({PROMPTS})[./][^:]*: (let |=>|else)"
    r"|^crates/cw-coding/src/[^:]+: (let brief|let said|=>): (The goal|Made the tool|Exit code|Stopped after)[ :]"
)


def sentences(path: str, text: str) -> list[str]:
    """The lines `path: how: words` for each sentence found in the file's text and not allowed."""
    out = []
    for m in FOUND.finditer(TEST_CODE.sub("", text)):
        how = m["field"] or m["push"] or (f"let {m['let']}" if m["let"] else None) or m["arm"] or m["else"]
        line = f"{path}: {how}: {m['two'] or m['capital']}"
        if not ALLOWED.search(line):
            out.append(line)
    return out


def main() -> int:
    files = subprocess.run(
        ["git", "ls-files", "crates/*/src/*.rs", "server/src/*.rs", "desktop/src/*.rs"],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    found = []
    for path in files:
        if not re.search(r"/tests?[_/.]", path):
            with open(path, encoding="utf-8") as f:
                found += sentences(path, f.read())
    print("\n".join(found), end="\n" if found else "")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
