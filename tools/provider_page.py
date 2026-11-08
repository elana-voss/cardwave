"""Writes the landing site's list of providers (its page "providers.html") from the providers the app knows.

    python tools/provider_page.py <landing site folder>/src/providers.json

Run from this folder after crates/cw-provider/providers changed, then `python build.py` in the landing site.
The list is the app's own (crates/cw-provider/src/list.rs): own.toml and models.dev.toml, without the
"Pretend model", which is no service. A provider's link is its website from own.toml, else the documentation
page models.dev's list (models.dev.json.gz, shipped with the app) gives under the same name; a server on the
user's own computer (http://127.0.0.1) stands apart, linked from LOCAL_SITES (own.toml gives it no website, as
the app asks it for no key). Standard library only.
"""

import gzip
import json
import sys
import tomllib
from pathlib import Path

FOLDER = Path(__file__).resolve().parent.parent / "crates" / "cw-provider" / "providers"
NO_SERVICE = "https://pretend.cardwave.invalid/v1"
LOCAL_SITES = {
    "KoboldCpp": "https://github.com/LostRuins/koboldcpp",
    "LM Studio": "https://lmstudio.ai",
    "Ollama": "https://ollama.com",
}


def providers():
    own = tomllib.loads((FOLDER / "own.toml").read_text(encoding="utf-8"))["provider"]
    listed = tomllib.loads((FOLDER / "models.dev.toml").read_text(encoding="utf-8"))["provider"]
    models_dev = json.loads(gzip.decompress((FOLDER / "models.dev.json.gz").read_bytes()))
    docs = {entry.get("name"): entry.get("doc") for entry in models_dev.values()}
    out = []
    for entry in own:
        if entry["base_url"] == NO_SERVICE:
            continue
        local = entry["base_url"].startswith("http://127.0.0.1")
        url = f"https://{entry['website']}" if "website" in entry else LOCAL_SITES.get(entry["name"])
        out.append({"name": entry["name"], "url": url, "local": local})
    for entry in listed:
        url = docs.get(entry["name"])
        if not url:
            sys.exit(f"no link for {entry['name']} in models.dev.json.gz")
        out.append({"name": entry["name"], "url": url, "local": False})
    missing = [p["name"] for p in out if not p["url"]]
    if missing:
        sys.exit(f"no link for {missing}")
    return sorted(out, key=lambda p: p["name"].lower())


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    found = providers()
    Path(sys.argv[1]).write_text(json.dumps(found, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    online = sum(1 for p in found if not p["local"])
    print(f"{online} providers online, {len(found) - online} on the user's own computer")


if __name__ == "__main__":
    main()
