#!/bin/sh
# Runs the checks of CLAUDE.md's "Running things" one after another: per check run its name and seconds, per check
# failed the end of its output (cargo's: only the failure lines), then "All N checks passed" or "Failed: …"; exit 1 on any.
# Run from anywhere in Git Bash: sh tools/check.sh; given names, only those checks (sh tools/check.sh layers), which
# tools/precommit.sh runs before each commit (the global git pre-commit hook).
#
# What runs is chosen from the changed files (CHANGED): the uncommitted work, plus `git diff --name-only $SINCE` when
# SINCE=<commit> is set, less code built only on Linux (LINUX_ONLY: WSL's check, tools/wsl.sh, covers it); ALL=1 runs everything but the desktop window's tests. Always: the layer rules (`layers`), the sentences to the page
# (tools/sentences.py), the crates' order (`crates`: tools/deps.py), the web interface's areas (tools/web_layers.py)
# and the small tools' tests (tools/run_tests.py runs every tools/*_test.py). fmt, server-tests, clippy and audit when crates/, server/ or Cargo* changed (SERVER_PATHS);
# ui-types, stylesheet, ui-tests and browser-tests when web/, e2e/ or what SERVER_PATHS covers did (UI_PATHS: the
# server writes the page's API types, the browser tests run the whole server), less the server's tests (TEST_PATHS). The desktop window's tests open windows on the owner's screen: only with DESKTOP=1 (or named), never by ALL=1 or a
# changed file. The run-throughs (RUN_THROUGHS=1) run when what they cover changed (RUN_THROUGH_PATHS); a figure seen (SEEN) never. Strawberry Perl
# goes first on PATH for SQLCipher's OpenSSL. `fmt` only checks: `cargo fmt --all` lays the code out.
# Each check runs under a time limit (tools/limited.sh), from its measured seconds with room for a cold build: 1800 s
# server-tests, clippy and browser-tests, 900 s audit, run-throughs and desktop-tests, 300 s the rest; CHECK_LIMIT=<s>
# sets one for all. Past it the check fails as "timed out after N s" with the tests running over 60 s, and the
# programs it left under target\ are stopped.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# env.sh names where this machine has the build's tools; a clone without it sets the readme's variables.
[ ! -f "$ROOT/tools/env.sh" ] || . "$ROOT/tools/env.sh"
. "$ROOT/tools/limited.sh"
TARGET="$ROOT/target"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
failed=""
count=0
WANTED="$*"
CHANGED=$(git -C "$ROOT" -c core.quotePath=false status --porcelain | cut -c4-)
[ -z "$SINCE" ] || CHANGED=$(printf '%s\n%s' "$CHANGED" "$(git -C "$ROOT" -c core.quotePath=false diff --name-only "$SINCE")")
LINUX_ONLY='(^|/)linux(/|\.rs$)|_linux\.rs$|^tools/(linux|wsl)\.sh$'
CHANGED=$(printf '%s\n' "$CHANGED" | grep -vE "$LINUX_ONLY")
TEST_PATHS='^(server/tests/|crates/[^/]+/tests/)'
SERVER_PATHS='^(crates/|server/|desktop/|Cargo)'
UI_PATHS='^(web/|e2e/|crates/|server/|Cargo)'
RUN_THROUGH_PATHS='^(e2e/(tests/9[0-9]-run-through|fake-provider|fake-search|stored|test\.ts|server\.mjs|playwright)|web/src/(views/(setup|providers|settings|chats?|library|character|interview|lorebooks?|personas|trash|profile|prompt-preset|voices|advanced|memories|documents|coding-task|coding-team|written-tools|about)\.ts|interview/|setup/|settings/|chat/|card/|library/|lorebook/|companion/|voice/|shell/|api/client|main\.ts|dom\.ts|in-place|edit-form)|server/src/api/(provider|kinds|cards|chats|generate|find|trash|settings|interview|lorebooks|personas|prompt_presets|presets|accounts|password|voices?|memory|documents|coding|written|companion|app_tools)|crates/cw-(ccv4|provider|prompt|chat|library|find|store|coding|accounts|voice|search)/)'

# check NAME DIR COMMAND…: runs COMMAND in DIR, unless names were given and NAME is not among them; prints NAME and
# its seconds, on failure the end of what it said (of cargo's tests and clippy only the failure, not the target list).
check() {
  name=$1 dir=$2
  shift 2
  [ -z "$WANTED" ] || case " $WANTED " in *" $name "*) ran="$ran $name" ;; *) return 0 ;; esac
  count=$((count + 1))
  start=$(date +%s)
  limit=${CHECK_LIMIT:-$(limit_of "$name")}
  (cd "$ROOT/$dir" && limited "$limit" "$@") >"$LOG" 2>&1
  status=$?
  if [ "$status" = 124 ]; then
    failed="$failed $name"
    echo "== $name failed"
    timed_out "$limit" "$LOG"
  elif [ "$status" != 0 ]; then
    failed="$failed $name"
    echo "== $name failed"
    case $name in
      server-tests | clippy) grep -E 'FAILED|panicked|^error|failures:|^test .*FAILED|^\s+--> ' "$LOG" | tail -n 40 ;;
      *) grep -vE "^\s+ok |^test .* \.\.\. ok$|^\s*$|^\s+(Compiling|Checking|Running|Finished|Fresh|Downloaded)" "$LOG" | tail -n 40 ;;
    esac
  fi
  echo "$name $(($(date +%s) - start)) s"
}

# limit_of NAME: the check's time limit in seconds.
limit_of() {
  case $1 in
    server-tests | clippy | browser-tests) echo 1800 ;;
    audit | run-throughs | desktop-tests) echo 900 ;;
    *) echo 300 ;;
  esac
}

# wants PATHS [SKIP]: true when names were given (check() then picks), ALL=1, or a changed file not matching SKIP
# matches PATHS.
wants() {
  [ -n "$WANTED" ] || [ "$ALL" = 1 ] || printf '%s\n' "$CHANGED" | grep -vE "${2:-^$}" | grep -qE "$1"
}

# layers: prints and fails on what breaks the global layer rules (a library named outside the crate that wraps
# it is the check `crates`'): a handler in server/src/api calling the database itself (`db.x(`), not its area; an
# error in server/src/api made of a bare sentence, not a code (`cw_core::Fail`); a screen in
# web/src/views importing another; fetch, WebSocket or EventSource used in web/src outside web/src/api/client.ts;
# a file in docs/ other than CLAUDE.md's four documents, the tickets of docs/tickets/ and the readme's screenshots; a call in crates/ made keyed and sent past cw_provider's `send` in one go (a `let` between hides it), which
# puts Cardwave's name on it.
# stylesheet: stylelint on each CSS file, then on app.css and app/*.css as one, as the duplicate-selector rule sees one
# file at a time (an exact selector ruled in two files fails; one inside a selector list is not a duplicate to it).
stylesheet() {
  npx stylelint "src/**/*.css" && cat src/app.css src/app/*.css | npx stylelint --stdin-filename src/app-all.css
}

layers() {
  found=$( {
    git ls-files --cached --others --exclude-standard docs | grep -vxE 'docs/(cardwave-rewrite|design|design-history|worklog)\.md|docs/screenshots/[a-z-]+\.png|docs/similar-apps/.+|docs/tickets/([0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+|TEMPLATE|INDEX)\.md'
    grep -rnE '\bdb\.[a-z_]+\(|\.db\(\)\.[a-z_]+\(' server/src/api
    grep -rlPz '(anyhow!|bail!|\.context)\(\s*"|ensure!\([^;]*?,\s*"[^"]*"\s*,?\s*\);' server/src/api
    grep -rlPz '\bkeyed\([^;]*?\.send\(\)' crates --include=*.rs
    grep -nE "from ['\"](\./|\.\./views/)" web/src/views/*.ts | grep -v '\.test\.ts:'
    grep -rnE '\bfetch\(|\bWebSocket\b|\bEventSource\b' web/src --include=*.ts | grep -v '^web/src/api/client\.ts:'
  } )
  [ -z "$found" ] || { echo "$found"; return 1; }
}

# The interview's texts against their source, which lies outside this repo: only where it is there.
interview_texts() {
  source=../cardwave-next-cardgentest/IMPLEMENTATION.md
  [ -f "$source" ] || return 0
  python tools/interview_texts.py "$source"
}
check layers . layers
check sentences . python tools/sentences.py
check tools-tests . python tools/run_tests.py
check crates . python tools/deps.py --check
check webimports . python tools/web_layers.py
if [ ! -d docs/tickets ]; then
  ran="$ran tickets"  # asked for by name (precommit.sh), it holds nothing to check here
  echo "(the tickets' check skipped: no docs/tickets here, as in tools/clean_repo.py's public tree)"
elif wants '^(docs/tickets/|tools/tickets|tools/selfcheck|docs/cardwave-rewrite\.md)'; then
  check tickets . sh -c 'python tools/tickets.py check && python tools/selfcheck.py'
else
  echo "(the tickets' check skipped: they did not change)"
fi
check interview-texts . interview_texts
if wants "$SERVER_PATHS"; then
  check fmt . cargo fmt --all --check
  # The whole workspace, the desktop crate's own tests among them (its build needs desktop/llama and web/dist).
  check server-tests . cargo test --workspace --no-fail-fast
  check clippy . cargo clippy --workspace --all-targets -- -D warnings
  check audit . cargo audit
else
  echo "(fmt, server tests, clippy and audit skipped: nothing they cover changed)"
fi
if wants "$UI_PATHS" "$TEST_PATHS"; then
  check ui-types web npx tsc --noEmit
  check stylesheet web stylesheet
  check ui-tests web npm test
  check browser-tests e2e env -u SEEN RUN_THROUGHS=0 npm test
else
  echo "(UI types, stylesheet, UI and browser tests skipped: nothing they cover changed)"
fi
if [ "$DESKTOP" = 1 ]; then
  check desktop-tests e2e npm run test:desktop
else
  echo "(desktop window's tests skipped: they open windows, only with DESKTOP=1)"
fi
if [ "$RUN_THROUGHS" = 1 ] || wants "$RUN_THROUGH_PATHS" "$TEST_PATHS"; then
  check run-throughs e2e env -u SEEN RUN_THROUGHS=1 npx playwright test run-through
else
  echo "(run-throughs skipped: nothing they cover changed)"
fi

for name in $WANTED; do
  case " $ran " in *" $name "*) ;; *) failed="$failed $name(no such check)" ;; esac
done
if [ -n "$failed" ]; then
  echo "Failed:$failed"
  exit 1
fi
echo "All $count checks passed"
