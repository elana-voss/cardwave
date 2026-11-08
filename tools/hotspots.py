"""Code hotspots: one table per product file from free metrics, ranked by complexity x changes x (1 - coverage).

Run from ROOT, each tool's output into one folder D (product code only: crates/*/src, server/src, desktop/src,
web/src without api/generated, no *.test.ts), then `python tools/hotspots.py D [rows]` prints the table:
  scc --by-file --format json crates/*/src server/src desktop/src web/src --exclude-dir generated > D/scc.json
  cargo clippy --workspace --message-format=json -- -W clippy::cognitive_complexity -W clippy::too_many_lines
    > D/clippy.txt
  npx jscpd --silent --reporters json --output D/jscpd --format rust,typescript --ignore "**/generated/**,**/*.test.ts"
    --pattern "{crates/*/src,server/src,desktop/src,web/src}/**/*.{rs,ts}" .   (from ROOT, so its paths are ROOT's)
  (in web) npx knip --reporter json --no-exit-code > D/knip.json;  cargo machete > D/machete.txt
  CARGO_LLVM_COV_TARGET_DIR=D/target cargo llvm-cov --workspace --exclude cardwave-desktop --ignore-run-fail
    --json --summary-only --output-path D/llvmcov.json   (then D/target removed)
  (in a copy of web with @vitest/coverage-v8) npx vitest run --coverage --coverage.reporter=json-summary --coverage.reportOnFailure,
    then its coverage/coverage-summary.json to D/;  git log --format= --name-only | sort | uniq -c > D/changes.txt
Columns: code lines, scc complexity, clippy's long/complex functions, lines in copies (jscpd), unused exports (knip),
line coverage %, commits touching the file. A missing input counts as zero; a file without coverage shows "-", ranked
as 0 % (cargo-llvm-cov: in 97a none for cardwave-server; in 102 every test program STATUS_NO_MEMORY, so skipped); a moved file's changes
count from the move; machete's unused crates go below.
"""
import json, os, re, sys
from collections import Counter

D, ROWS = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 40
def rel(p):  # any path (absolute, Windows, a copy of web) to ROOT-relative with "/"
    p = p.replace("\\", "/").removeprefix("./")
    return re.sub(r"^.*?/cardwave-next/", "", p) if "/cardwave-next/" in p else re.sub(r"^.*/web[^/]*/src/", "web/src/", p)
def load(name, default):
    path = os.path.join(D, name)
    return (json.load(open(path, encoding="utf8")) if name.endswith(".json") else open(path, encoding="utf8").read()) if os.path.exists(path) else default
files = {rel(f["Location"]): f for lang in load("scc.json", []) if lang["Name"] in ("Rust", "TypeScript") for f in lang["Files"]
         if not f["Location"].endswith(".test.ts")}
long_fns, copies, unused, cover = Counter(), Counter(), Counter(), {}
for line in load("clippy.txt", "").splitlines():  # cargo's JSON lines, so not read as one JSON file
    msg = json.loads(line).get("message") if line.startswith("{") else None
    if msg and (msg.get("code") or {}).get("code") in ("clippy::too_many_lines", "clippy::cognitive_complexity"):
        long_fns[rel(msg["spans"][0]["file_name"])] += 1
for dup in load("jscpd/jscpd-report.json", {}).get("duplicates", []):
    for side in ("firstFile", "secondFile"):
        copies[rel(dup[side]["name"])] += dup["lines"]
for issue in load("knip.json", {}).get("issues", []):
    unused["web/" + issue["file"]] += sum(len(v) for k, v in issue.items() if isinstance(v, list) and k != "files")
for f in (load("llvmcov.json", {}).get("data") or [{}])[0].get("files", []):
    cover[rel(f["filename"])] = f["summary"]["lines"]["percent"]
for name, s in load("coverage-summary.json", {}).items():
    if name != "total": cover[rel(name)] = s["lines"]["pct"]
changes = Counter({rel(m.group(2)): int(m.group(1)) for m in re.finditer(r"^\s*(\d+) (\S.*)$", load("changes.txt", ""), re.M)})
rows = []
for path, f in files.items():
    cov = cover.get(path)
    rows.append((f["Complexity"] * changes[path] * (1 - (cov or 0) / 100), path, f["Code"], f["Complexity"], long_fns[path], copies[path], unused[path], cov, changes[path]))
rows.sort(reverse=True)
print(f"{'score':>8} {'code':>5} {'cplx':>5} {'long':>4} {'copy':>4} {'unus':>4} {'cov%':>5} {'chg':>4}  file")
for r in rows[:ROWS]:
    print(f"{r[0]:8.0f} {r[2]:5} {r[3]:5} {r[4]:4} {r[5]:4} {r[6]:4} {'-' if r[7] is None else f'{r[7]:.1f}':>5} {r[8]:4}  {r[1]}")
print("\nUnused crates (cargo machete):\n" + "\n".join(l for l in load("machete.txt", "").splitlines() if l.startswith(("\t", " ", "cw-", "card")) or "--" in l))
