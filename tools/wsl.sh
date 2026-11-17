#!/usr/bin/env bash
# Linux in WSL's Ubuntu: its setup once, and the work's copy in Linux's own disk (`~/cardwave-next` there, a clone
# fetching from this folder; never built on /mnt/c, whose files are slow and Windows'). Run from ROOT in Git Bash
# (an argument that is a Linux path needs MSYS_NO_PATHCONV=1 before `wsl`), one call at a time (a lock):
#   wsl -d Ubuntu -u root -- bash tools/wsl.sh root   tools/linux.sh's packages, mold and Node 24 (the owner's yes, 2026-11-17)
#   wsl -d Ubuntu -- bash tools/wsl.sh user           Rust, the clone, the npm folders, Playwright's WebKit, tauri-driver; what is there stays
#   wsl -d Ubuntu -- bash tools/wsl.sh sync           the copy made equal to this folder, uncommitted files too
#   wsl -d Ubuntu -- bash tools/wsl.sh check          sync, then fmt, the workspace's tests (under tools/linux.sh keyring), clippy, web's tests
#   wsl -d Ubuntu -- bash tools/wsl.sh webkit [<spec>]  sync, then the browser tests in Playwright's WebKit (`e2e`'s WEBKIT=1)
#   wsl -d Ubuntu -- bash tools/wsl.sh dist           sync, then the AppImage and the .deb (tools/linux.sh bundle)
#   wsl -d Ubuntu -- bash tools/wsl.sh desktop-test   sync, then e2e/desktop's window tests (tools/linux.sh screen)
#   wsl -d Ubuntu -- bash tools/wsl.sh run <command>  sync, then <command> in the copy
# Each prints a line per step or the result; the whole output goes to the copy's `.checklists/wsl-<command>.out`,
# copied to this folder's (the hooks refuse reading the copy's). The installer
# test: tools/installer_test_linux.sh. Traps: the hooks refuse `~` and `$HOME` in a Bash call's text, so they stand
# only in here; WSL is capped at 10 GB and 6 processors by the owner's `.wslconfig` (2026-11-17): 4 build jobs, and
# the test binaries' links 2 (4 took Windows' memory to 90-96 %, 151).
set -euo pipefail
WIN="$(cd "$(dirname "$0")/.." && pwd)"
# A git worktree's `.git` is a file naming its git folder by a Windows path, which Linux's git cannot follow:
# its git folder is then named to git directly (GIT_DIR), its /mnt path made from the Windows one.
GITDIR="$WIN/.git"
if [ -f "$GITDIR" ]; then
  GITDIR="$(sed -n 's|^gitdir: \([A-Za-z]\):|/mnt/\L\1\E|p' "$WIN/.git")"
fi
wingit() { GIT_DIR="$GITDIR" GIT_WORK_TREE="$WIN" git "$@"; }
COPY="$HOME/cardwave-next"
# packages, keyring, on_screen, bundle and the PATH to Rust and Node.
source "$WIN/tools/linux.sh"
export CARGO_BUILD_JOBS=4
# mold links in a fraction of ld's time (the owner's yes, 2026-11-17); `mold -run` swaps the linker without a
# change of flags, which would rebuild every crate.
if command -v mold >/dev/null && [ -z "${MOLD_PATH:-}" ]; then exec mold -run bash "$0" "$@"; fi
exec 9>"/tmp/cardwave-wsl.lock"
flock 9

root() {
  packages
  apt-get install -y -qq mold >/dev/null
  local dist=https://nodejs.org/dist/latest-v24.x
  local name
  name="$(curl -fsSL "$dist/SHASUMS256.txt" | awk '/linux-x64.tar.xz$/ {print $2}')"
  if [ ! -x /usr/local/node/bin/node ] || [ "$(/usr/local/node/bin/node --version)" != "$(echo "$name" | cut -d- -f2)" ]; then
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL "$dist/$name" -o "$tmp/$name"
    (cd "$tmp" && curl -fsSL "$dist/SHASUMS256.txt" | grep " $name\$" | sha256sum -c -)
    rm -rf /usr/local/node && mkdir -p /usr/local/node
    tar -xJf "$tmp/$name" -C /usr/local/node --strip-components=1
    rm -rf "$tmp"
  fi
  /usr/local/node/bin/node --version
}

# `npm ci` in the copy's folder $1 where its node_modules is missing or older than its lock file (npm's own record).
npm_folder() {
  local dir="$COPY/$1"
  if [ ! -f "$dir/node_modules/.package-lock.json" ] || [ "$dir/package-lock.json" -nt "$dir/node_modules/.package-lock.json" ]; then
    (cd "$dir" && npm ci --no-audit --no-fund >/dev/null)
  fi
}

user() {
  if ! command -v cargo >/dev/null; then
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal -c rustfmt,clippy
  fi
  git config --global --get-all safe.directory | grep -qxF "$WIN" || git config --global --add safe.directory "$WIN"
  # From the git folder shared by every worktree: a worktree's own `.git` is a file Linux's git cannot follow.
  [ -d "$COPY/.git" ] || git clone -q "$(wingit rev-parse --path-format=absolute --git-common-dir)" "$COPY"
  sync_copy
  npm_folder web
  npm_folder desktop
  npm_folder e2e
  # Downloads only what is missing; its system packages are tools/linux.sh's.
  (cd "$COPY/e2e" && npx playwright install webkit >/dev/null)
  command -v tauri-driver >/dev/null || cargo install tauri-driver --locked
  cargo --version
}

# Equal to this folder: its commit, then each changed or new file not ignored, and its deleted files gone.
sync_copy() {
  cd "$COPY"
  git fetch -q "$GITDIR" HEAD
  git reset -q --hard FETCH_HEAD
  git clean -q -fd
  # A worktree's node_modules and desktop/llama are links to the main folder's, which git does not take as ignored folders.
  wingit ls-files -m -o --exclude-standard -z | rsync -a --ignore-missing-args --exclude=node_modules --exclude=/desktop/llama \
    --from0 --files-from=- "$WIN/" "$COPY/"
  wingit ls-files -d -z | xargs -0 -r rm -f
}

# Whether web/dist is missing or older than a file it is built from.
ui_stale() {
  local built="$COPY/web/dist/index.html"
  [ ! -f "$built" ] || [ -n "$(find "$COPY/web/src" "$COPY/web/public" "$COPY/web"/*.html -newer "$built" -print -quit)" ]
}

step() {
  local name="$1"
  shift
  if "$@" >>"$OUT" 2>&1; then echo "ok   $name"; else echo "FAIL $name"; FAILED=1; fi
}

check() {
  sync_copy
  mkdir -p "$COPY/.checklists" && : >"$OUT"
  FAILED=0
  export RUST_TEST_THREADS=2
  step fmt cargo fmt --all --check
  # The desktop crate's build (clippy's) needs its resources: llama-server and the UI's build.
  step llama python3 "$COPY/tools/llama.py"
  if ui_stale; then step ui bash -c "cd '$COPY/web' && npm run build"; fi
  # The whole workspace, the desktop crate's own tests among them (its build needs the two above).
  step test bash -c "cd '$COPY' && CARGO_BUILD_JOBS=2 dbus-run-session -- bash tools/linux.sh keyring cargo test --no-fail-fast --workspace"
  grep -E "^test result: FAILED|panicked" "$OUT" | head -n 8 || true
  step clippy cargo clippy --workspace --all-targets -- -D warnings
  step web bash -c "cd '$COPY/web' && npm test"
  return "$FAILED"
}

# Runs a command with its output in $OUT; on failure prints its last 10 lines.
quiet() {
  if "$@" >>"$OUT" 2>&1; then return 0; fi
  tail -n 10 "$OUT"
  return 1
}

# Prints where the AppImage and the .deb are.
dist() {
  sync_copy
  mkdir -p "$COPY/.checklists" && : >"$OUT"
  npm_folder desktop
  npm_folder web
  quiet bash "$COPY/tools/linux.sh" bundle
  ls -l "$COPY"/target/release/bundle/appimage/*.AppImage "$COPY"/target/release/bundle/deb/*.deb
}

# Its stored pictures are not compared (playwright.config.ts).
webkit() {
  sync_copy
  mkdir -p "$COPY/.checklists" && : >"$OUT"
  cd "$COPY/e2e"
  quiet env WEBKIT=1 npx playwright test --reporter=line "$@"
  grep -E "^ +[0-9]+ (passed|failed|flaky|skipped)" "$OUT" || true
}

desktop-test() {
  sync_copy
  mkdir -p "$COPY/.checklists" && : >"$OUT"
  cd "$COPY/e2e"
  quiet bash "$COPY/tools/linux.sh" screen npm run test:desktop
  grep -aE "^. (tests|pass|fail|skipped) [0-9]" "$OUT" || true
}

CMD="${1:-}"
OUT="$COPY/.checklists/wsl-$CMD.out"
# The whole output, for reading from Windows.
trap '[ ! -f "$OUT" ] || { mkdir -p "$WIN/.checklists" && cp "$OUT" "$WIN/.checklists/wsl-$CMD.out"; }' EXIT
case "$CMD" in
  root) root ;;
  user) user ;;
  sync) sync_copy ;;
  check) check ;;
  webkit) shift; webkit "$@" ;;
  dist) dist ;;
  desktop-test) desktop-test ;;
  run) shift; sync_copy; cd "$COPY"; "$@" ;;
  *) echo "usage: tools/wsl.sh root|user|sync|check|webkit [<spec>]|dist|desktop-test|run <command>" >&2; exit 2 ;;
esac
