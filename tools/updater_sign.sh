#!/usr/bin/env bash
# Signs each installer for the app's updater (`<installer>.sig` beside it, which tools/release_feed.py reads), in
# .github/workflows/installer.yml. Run from desktop/ (its Tauri CLI): bash ../tools/updater_sign.sh <installer>...
# The key is the repository secret TAURI_SIGNING_PRIVATE_KEY (with TAURI_SIGNING_PRIVATE_KEY_PASSWORD); a build of
# the public repo (GITHUB_REPOSITORY elana-voss/cardwave, which fills a release) without it fails. A build on any
# other repo (the private one has no secret) signs with a throwaway key made here, so the signing and the feed run
# there too; that key matches no app, so such a build's .sig updates nothing.
# Trap: an empty key makes `tauri signer sign` fail with "incorrect updater private key password".
set -euo pipefail
if [ -z "${TAURI_SIGNING_PRIVATE_KEY:-}" ]; then
  [ "${GITHUB_REPOSITORY:-}" != elana-voss/cardwave ] || { echo "a release needs the secret TAURI_SIGNING_PRIVATE_KEY" >&2; exit 1; }
  echo "no signing key: a throwaway key signs this build"
  keys="$(mktemp -d)"
  trap 'rm -rf "$keys"' EXIT
  npx tauri signer generate --ci -p throwaway -w "$keys/key" >/dev/null
  TAURI_SIGNING_PRIVATE_KEY="$(cat "$keys/key")"
  TAURI_SIGNING_PRIVATE_KEY_PASSWORD=throwaway
  export TAURI_SIGNING_PRIVATE_KEY TAURI_SIGNING_PRIVATE_KEY_PASSWORD
fi
for installer in "$@"; do
  npx tauri signer sign "$installer" >/dev/null
  [ -s "$installer.sig" ] || { echo "$installer: no .sig written" >&2; exit 1; }
  echo "signed $(basename "$installer")"
done
