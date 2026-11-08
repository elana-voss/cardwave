#!/usr/bin/env python
"""Surveys the online providers' own documentation for a way to name the calling app (milestone 111).

    python -I tools/app_name_lookup.py <empty folder> [name substring ...]

For each provider of crates/cw-provider/providers/{own,models.dev}.toml (all but the four not online) it downloads,
with curl, the docs address models.dev names, the docs host's llms.txt, llms-full.txt and sitemap, and the pages
those name that look like they could say; each provider gets one folder. It prints per provider one block: what it
got and the lines that name a header or an app ranking. No provider's API is called, only its documentation sites.
A page is data: nothing downloaded is run. Traps: most docs are built by JavaScript, so a page without a hit is not
an answer until a text version (a page's `.md`, llms.txt) was seen; the printed `pages` count says which were text.
"""
import concurrent.futures as cf
import json
import pathlib
import re
import subprocess
import sys
import tomllib
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCAL = {"KoboldCpp", "LM Studio", "Ollama", "Pretend model"}
HIT = re.compile(
    r"HTTP-Referer|X-Title|X-OpenRouter|\bX-[A-Za-z-]*(?:App|Client|Source|Title|Referer|Application|Integration|Partner|Origin|Project)\b[A-Za-z-]*"
    r"|User-Agent|app[ -]attribution|leaderboard|top apps|\bapp[_-]?(?:id|name|code)\b|application name|name your app|identify your app"
    r"|attribution|rankings?\b",
    re.I,
)
WANT = re.compile(r"attribut|header|quick-?start|getting-?started|authenti|openai|chat-?completion|integrat|app|rank|overview", re.I)
CURL_OK = {"text/plain", "text/markdown", "text/html", "application/json", "application/xml", "text/xml"}


def providers():
    out = []
    for f in ("own.toml", "models.dev.toml"):
        data = tomllib.loads((ROOT / "crates/cw-provider/providers" / f).read_text(encoding="utf-8"))
        out += [p for p in data["provider"] if p["name"] not in LOCAL]
    return out


def fetch(url, dest):
    """Downloads a page to `dest`; returns its text, empty when it failed or is not text."""
    r = subprocess.run(
        ["curl", "-sL", "-m", "25", "--max-filesize", "12000000", "-A", "Mozilla/5.0", "-o", str(dest), "-w", "%{http_code} %{content_type}", url],
        capture_output=True, text=True,
    )
    code, _, ctype = r.stdout.partition(" ")
    if code != "200" or ctype.split(";")[0].strip().lower() not in CURL_OK or not dest.exists():
        dest.unlink(missing_ok=True)
        return ""
    return dest.read_text(encoding="utf-8", errors="replace")


def hosts_of(p, doc):
    """The registrable domain's docs hosts to try."""
    seen = []
    for u in filter(None, (doc, "https://" + p["website"] if p.get("website") else "", p["base_url"])):
        host = urllib.parse.urlparse(u).netloc
        parts = host.split(".")
        base = ".".join(parts[-3:] if len(parts) > 2 and len(parts[-2]) <= 3 else parts[-2:])
        for h in (host if u == doc else "", "docs." + base, base, "www." + base):
            if h and h not in seen:
                seen.append(h)
    return seen


def text_of(raw):
    """Plain text of a page, scripts kept: a site's JSON payload often holds the words."""
    return re.sub(r"<(style)[^>]*>.*?</\1>", " ", raw, flags=re.S | re.I)


def survey(p, doc, folder):
    folder.mkdir(parents=True, exist_ok=True)
    pages, n = {}, 0

    def get(url):
        nonlocal n
        n += 1
        t = fetch(url, folder / f"{n}.txt")
        if t:
            pages[url] = t
        return t

    links = []
    if doc:
        get(doc)
    for h in hosts_of(p, doc)[:6]:
        for path in ("/llms-full.txt", "/llms.txt", "/docs/llms-full.txt", "/docs/llms.txt", "/sitemap.xml"):
            t = get(f"https://{h}{path}")
            if t and path.endswith("llms.txt"):
                links += re.findall(r"https?://[^\s)\]\"'<>]+", t)
            if t and path.endswith("xml"):
                links += re.findall(r"<loc>\s*([^<\s]+)", t)
    for url in pages.copy():
        if not url.endswith((".txt", ".xml")):
            links += [urllib.parse.urljoin(url, h) for h in re.findall(r'href="([^"#]+)"', pages[url])]
    picked = []
    for u in links:
        if WANT.search(urllib.parse.urlparse(u).path) and u not in pages and u not in picked and not re.search(r"\.(png|jpg|svg|css|js)$", u):
            picked.append(u)
    picked.sort(key=lambda u: (not re.search(r"attribut|header|rank", u, re.I), len(u)))
    for u in picked[:12]:
        get(u)

    hits = {}
    for url, raw in pages.items():
        t = text_of(raw)
        for m in HIT.finditer(t):
            line = re.sub(r"\s+", " ", t[max(0, m.start() - 60): m.end() + 90])
            line = re.sub(r"<[^>]{0,80}>", " ", line)
            key = m.group(0).lower()
            hits.setdefault(key, []).append((url, line))
    return {"name": p["name"], "base": p["base_url"], "doc": doc, "pages": list(pages), "bytes": sum(map(len, pages.values())), "hits": hits}


def main():
    out = pathlib.Path(sys.argv[1])
    only = [a.lower() for a in sys.argv[2:]]
    md = {}
    api = out / "models.dev.json"
    if not api.exists():
        subprocess.run(["curl", "-sL", "-m", "60", "https://models.dev/api.json", "-o", str(api)], check=True)
    for e in json.loads(api.read_text(encoding="utf-8")).values():
        if e.get("api"):
            md[e["api"].rstrip("/")] = e.get("doc", "")
    todo = [p for p in providers() if not only or any(o in p["name"].lower() for o in only)]
    with cf.ThreadPoolExecutor(8) as pool:
        res = list(pool.map(
            lambda p: survey(p, md.get(p["base_url"].rstrip("/"), ""), out / re.sub(r"\W+", "_", p["name"])), todo))
    (out / "survey.json").write_text(json.dumps(res, indent=0), encoding="utf-8")
    for r in res:
        print(f"## {r['name']} | pages {len(r['pages'])} | {r['bytes'] // 1000} KB | doc {r['doc']}")
        for key, found in sorted(r["hits"].items()):
            url, line = found[0]
            print(f"  {key} x{len(found)}: {line[:170]} <{url}>")


if __name__ == "__main__":
    main()
