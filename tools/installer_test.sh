#!/bin/sh
# The installer test, before a release: installs the built installer silently, runs e2e/desktop/installed.test.ts
# on the installed program (its window, on a scratch folder: first run by the provider's address, a reply, the chat
# kept over a restart), then uninstalls it silently and checks that the program is gone.
#
# Run from Git Bash (it opens a window and replaces the installed Cardwave), on the release draft's downloaded exe
# (the skill cardwave-release, step 4), or after `npm run dist` in desktop/:
#   sh tools/installer_test.sh [<path to Cardwave_<version>_x64-setup.exe>]
# Without a path it takes the newest installer in target/release/bundle/nsis/. Needs what `npm run test:desktop`
# needs (head of e2e/desktop/driver.ts: tauri-driver, a matching msedgedriver).
#
# Traps: it replaces the Cardwave installed on this computer (per user, %LOCALAPPDATA%\Cardwave) and removes it at
# the end; the user's data (%APPDATA%\cc.cardwave.app) is kept, as a silent uninstall does not delete it. It refuses
# to start while a cardwave.exe runs. A `/S` from Git Bash becomes a path unless MSYS_NO_PATHCONV=1. NSIS's
# uninstaller copies itself and returns at once, so its end is waited for by the program's file going.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="${1:-$(ls -t "$ROOT"/target/release/bundle/nsis/Cardwave_*_x64-setup.exe 2>/dev/null | head -n 1)}"
DIR="$(cygpath -u "$LOCALAPPDATA")/Cardwave"
EXE="$DIR/cardwave.exe"

[ -f "$SETUP" ] || { echo "no installer: build one with npm run dist in desktop/, or name it"; exit 2; }
if tasklist //FI "IMAGENAME eq cardwave.exe" | grep -qi "cardwave.exe"; then
  echo "a cardwave.exe is running: close Cardwave first"; exit 2
fi

echo "installing $(basename "$SETUP")"
MSYS_NO_PATHCONV=1 "$SETUP" /S || { echo "the installer failed ($?)"; exit 1; }
[ -f "$EXE" ] || { echo "the installer left no $EXE"; exit 1; }

(cd "$ROOT/e2e" && CARDWAVE_EXE="$(cygpath -w "$EXE")" node --test desktop/installed.test.ts)
tested=$?

echo "uninstalling"
MSYS_NO_PATHCONV=1 "$DIR/uninstall.exe" /S || { echo "the uninstaller failed ($?)"; exit 1; }
for _ in $(seq 60); do
  [ -f "$EXE" ] || break
  sleep 1
done
[ -f "$EXE" ] && { echo "uninstalled, but $EXE is still there after 60 s"; exit 1; }

[ "$tested" -eq 0 ] && echo "installer test passed" || echo "installer test failed"
exit "$tested"
