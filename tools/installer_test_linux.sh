#!/usr/bin/env bash
# The installer test on Linux, twin of tools/installer_test.sh: installs the .deb as root, runs
# e2e/desktop/installed.test.ts on /usr/bin/cardwave (first run by the provider's address, a reply, the chat kept
# over a restart), removes the package and checks the program is gone; then the same test on the AppImage, which
# is not installed. Each program's log names the updater's feed entry it asks for, which must be its own in a feed
# release_feed.py writes (the AppImage `linux-x86_64-appimage`, the .deb `linux-x86_64-deb`).
#
# In WSL's Ubuntu after `tools/wsl.sh dist`, from ROOT in Git Bash, as root (installing needs it):
#   wsl -d Ubuntu -u root -- bash tools/installer_test_linux.sh [<.deb> <.AppImage>]
# It takes the bundles of the work's copy (`~/cardwave-next` of the user with id 1000, see tools/wsl.sh), or the two
# given (Linux paths, e.g. GitHub's build downloaded to /mnt/c/.../.checklists, copied to a scratch folder first; the
# copy's e2e and tools are still used, so `tools/wsl.sh sync` it first), and runs
# the window's test as that user on tools/linux.sh's virtual screen, so no window reaches the owner's screen; a picture of each program's first screen goes to ROOT's
# `.checklists/installed-first-run-<deb|AppImage>.png`. The updater's install itself is not shown here: an update is
# signed with the project's key, which only GitHub holds.
# Traps: root's XDG_RUNTIME_DIR must not reach the user; the AppImage runs extracted (APPIMAGE_EXTRACT_AND_RUN), as FUSE is missing in WSL; the tests'
# scratch folders are the user's own temp folder, and the release build reads none of the browser tests' stand-ins.
set -u
NAME="$(getent passwd 1000 | cut -d: -f1)"
USERHOME="$(getent passwd 1000 | cut -d: -f6)"
COPY="$USERHOME/cardwave-next"
BUNDLE="$COPY/target/release/bundle"
DEB="$(ls -t "$BUNDLE"/deb/Cardwave_*_amd64.deb 2>/dev/null | head -n 1)"
APPIMAGE="$(ls -t "$BUNDLE"/appimage/Cardwave_*_amd64.AppImage 2>/dev/null | head -n 1)"
[ "$(id -u)" = 0 ] || { echo "run as root: wsl -d Ubuntu -u root -- bash tools/installer_test_linux.sh"; exit 2; }
if [ $# = 2 ]; then
  [ -f "$1" ] && [ -f "$2" ] || { echo "no such bundles: $1 $2"; exit 2; }
  GIVEN="$(mktemp -d)"
  trap 'rm -rf "$GIVEN"' EXIT
  cp "$1" "$2" "$GIVEN/"
  chmod 755 "$GIVEN" "$GIVEN"/*
  DEB="$GIVEN/$(basename "$1")" APPIMAGE="$GIVEN/$(basename "$2")"
fi
[ -f "$DEB" ] && [ -f "$APPIMAGE" ] || { echo "no bundles: build them with tools/wsl.sh dist"; exit 2; }
pgrep -x cardwave >/dev/null && { echo "a cardwave runs: end it first"; exit 2; }
# The pictures of each program's first screen go to ROOT's .checklists (gitignored).
SHOTS="$(cd "$(dirname "$0")/.." && pwd)/.checklists"
mkdir -p "$SHOTS"
FEED="$(mktemp -d)"
chmod 755 "$FEED"
FAILED=0

# The feed of a release with both bundles (empty stand-ins, each with its .sig), as the release's build writes it.
touch "$FEED/x.AppImage" "$FEED/x.AppImage.sig" "$FEED/x.deb" "$FEED/x.deb.sig"
python3 "$COPY/tools/release_feed.py" "$FEED/latest.json" "$FEED/x.AppImage" https://feed/x.AppImage "$FEED/x.deb" https://feed/x.deb >/dev/null \
  || { echo "release_feed.py failed"; exit 1; }

# Runs the installed test on program $1 as the user, then checks that its log's feed entry leads to bundle $2.
tested() {
  local exe="$1" kind="$2" logs entry url
  logs="$(mktemp -d)"
  chown "$NAME" "$logs"
  # As tools/wsl.sh desktop-test: tools/linux.sh screen, which also adds Node to the PATH.
  runuser -u "$NAME" -- env -u XDG_RUNTIME_DIR PATH=/usr/bin:/bin HOME="$USERHOME" APPIMAGE_EXTRACT_AND_RUN=1 \
    CARDWAVE_EXE="$exe" CARDWAVE_KEEP_LOGS="$logs" CARDWAVE_SCREENSHOT="$logs/first-run.png" \
    bash "$COPY/tools/linux.sh" screen bash -c "cd '$COPY/e2e' && node --test desktop/installed.test.ts" || { echo "FAIL the test on the $kind"; FAILED=1; }
  cp "$logs/first-run.png" "$SHOTS/installed-first-run-$kind.png" 2>/dev/null || { echo "FAIL no picture of the $kind's first screen"; FAILED=1; }
  entry="$(grep -rhoE "feed's entry .*" "$logs" | grep -oE "linux-[a-z0-9_]+-[a-z]+" | head -n 1)"
  url="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['platforms'].get(sys.argv[2], {}).get('url', ''))" "$FEED/latest.json" "$entry")"
  if [ "$url" = "https://feed/x.$kind" ]; then echo "ok   the $kind asks for $entry, its own"; else echo "FAIL the $kind asks for '$entry', which leads to '$url'"; FAILED=1; fi
  rm -rf "$logs"
}

echo "installing $(basename "$DEB")"
DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$DEB" >/dev/null || { echo "the .deb did not install"; exit 1; }
[ -x /usr/bin/cardwave ] || { echo "the .deb left no /usr/bin/cardwave"; exit 1; }
tested /usr/bin/cardwave deb
echo "removing it"
DEBIAN_FRONTEND=noninteractive apt-get remove -y -q cardwave >/dev/null || { echo "the .deb did not uninstall"; exit 1; }
[ -e /usr/bin/cardwave ] && { echo "removed, but /usr/bin/cardwave is still there"; FAILED=1; }

tested "$APPIMAGE" AppImage
rm -rf "$FEED"
[ "$FAILED" = 0 ] && echo "installer test passed" || echo "installer test failed"
exit "$FAILED"
