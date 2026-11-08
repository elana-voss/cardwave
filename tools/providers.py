"""Writes crates/cw-provider/providers/models.dev.toml: the providers of models.dev's list that the app can offer by name.

    python tools/providers.py <api.json>

<api.json> is https://models.dev/api.json, fetched beforehand. Taken is a provider that

    - speaks OpenAI's chat API by the list's own word (npm "@ai-sdk/openai-compatible"),
    - has one fixed https address (none with a "${...}" the user would have to fill in),
    - is not sold for coding tools only (a name with "Coding Plan", "Token Plan", "Step Plan", "For Coding" or "...Pass"),
    - is not on a host that crates/cw-provider/providers/own.toml has an entry for, nor at an address taken already,
    - and answers there as an API does: GET <address>/models without a key gives a list of models, or 401 or 403
      that is no HTML. No key is sent anywhere.

It asks every address once (a second time where the first try reached nothing) and says what it left out and why. That takes about a minute.
The file is written anew as a whole; own.toml is kept by hand and never touched.
"""

import json
import os
import re
import sys
import tomllib
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "crates", "cw-provider", "providers")
FOR_CODING = re.compile(r"\b(Coding|Token|Step) Plan\b|\bFor Coding\b|Pass\b")

HEAD = """\
# Providers taken from models.dev's list (https://models.dev/api.json), written by tools/providers.py, whose head
# says which are taken. Not kept by hand: a change made here is lost when the file is written anew. An entry is a
# provider's name and the address of its API up to the version part; own.toml says how the app uses them.
#
# models.dev is under the MIT License:
#
# Copyright (c) 2025 models.dev
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
"""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_more):
        return None


def answers(base):
    """Whether <base>/models answers as an API does without a key; None when nothing was reached."""
    ask = urllib.request.Request(base + "/models", headers={"User-Agent": "cardwave", "Accept": "application/json"})
    try:
        with urllib.request.build_opener(NoRedirect).open(ask, timeout=20) as got:
            status, kind, body = got.status, got.headers.get("content-type", ""), got.read(8_000_000)
    except urllib.error.HTTPError as refused:
        status, kind, body = refused.code, refused.headers.get("content-type", ""), refused.read(2000)
    except Exception:  # noqa: BLE001 - no answer, whatever the reason
        return None
    text = body.decode("utf-8", "replace")
    if "html" in kind or text.lstrip().startswith("<"):
        return False
    if status in (401, 403):
        return True
    try:
        said = json.loads(text)
    except ValueError:
        return False
    return status == 200 and (isinstance(said, list) or (isinstance(said, dict) and isinstance(said.get("data"), list)))


def quoted(text):
    return json.dumps(text, ensure_ascii=False)


def main():
    listed = json.load(open(sys.argv[1], encoding="utf-8"))
    own = tomllib.load(open(os.path.join(FOLDER, "own.toml"), "rb"))["provider"]
    hosts = {urlparse(entry["base_url"]).hostname for entry in own}
    names = {entry["name"].lower() for entry in own}
    left = {}
    wanted = []
    for provider in sorted(listed.values(), key=lambda provider: provider["name"].lower()):
        name, base = provider["name"].strip(), (provider.get("api") or "").rstrip("/")
        if provider.get("npm") != "@ai-sdk/openai-compatible":
            why = "not OpenAI's API"
        elif not base.startswith("https://") or "${" in base:
            why = "no fixed https address"
        elif FOR_CODING.search(name):
            why = "sold for coding tools"
        elif urlparse(base).hostname in hosts:
            why = "own.toml has its host"
        elif name.lower() in names or base in (taken for _, taken in wanted):
            why = "its name or address is taken"
        else:
            names.add(name.lower())
            wanted.append((name, base))
            continue
        left.setdefault(why, []).append(name)
    with ThreadPoolExecutor(8) as pool:
        found = list(pool.map(lambda entry: answers(entry[1]), wanted))
    # What reached nothing is asked once more, one after the other.
    found = [answers(base) if was is None else was for (_, base), was in zip(wanted, found)]
    kept = [entry for entry, is_api in zip(wanted, found) if is_api]
    left["does not answer as an API"] = [name for (name, _), is_api in zip(wanted, found) if not is_api]
    with open(os.path.join(FOLDER, "models.dev.toml"), "w", encoding="utf-8", newline="\n") as out:
        out.write(HEAD)
        for name, base in kept:
            out.write(f"\n[[provider]]\nname = {quoted(name)}\nbase_url = {quoted(base)}\n")
    print(f"{len(kept)} written.")
    for why, which in left.items():
        print(f"Left out, {why}: {len(which)} ({', '.join(which)})")


if __name__ == "__main__":
    main()
