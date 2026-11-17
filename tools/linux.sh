#!/usr/bin/env bash
# What a Linux build needs on any Ubuntu, shared by WSL's copy (tools/wsl.sh) and GitHub's Linux job
# (.github/workflows/installer.yml):
#   sudo bash tools/linux.sh packages                       the Ubuntu packages to build, test and bundle, as root
#   dbus-run-session -- bash tools/linux.sh keyring <cmd>   <cmd> with an unlocked Secret Service (the key's tests)
#   bash tools/linux.sh screen <cmd>                        <cmd> on a virtual screen (the window's tests)
#   bash tools/linux.sh bundle                              the AppImage and the .deb (`npm run dist` in desktop/)
# Sourced (tools/wsl.sh), it defines these and the PATH to WSL's Rust and Node, and runs nothing.
# Traps: package names differ by release (WebKitGTK's driver, FUSE 2), so each is chosen by what apt knows; Ubuntu
# 22.04 has no glslc (GitHub's build takes the Vulkan SDK's). For the
# keyring, an empty password creates no collection (no "default" alias: keyring's NoStorageAccess, and the key goes
# to the file), and gnome-keyring's prompter opens a window on the owner's screen unless no display is named.
set -euo pipefail
# Where tools/wsl.sh puts rustup's Rust and Node; on GitHub they are not there and change nothing.
export PATH="$HOME/.cargo/bin:/usr/local/node/bin:$PATH"
# WSLg's sound is the owner's microphone and speakers on Windows (also through $XDG_RUNTIME_DIR/pulse/native, so
# unsetting PULSE_SERVER is not enough): every program here is sent to a server that does not exist, its microphone silent.
export PULSE_SERVER=unix:/nonexistent/pulse

# The first of the names apt can install (none: nothing). `apt-cache show` succeeds also for a name another package
# only refers to (22.04's webkitgtk-webdriver), so the candidate is asked for.
known() {
  local name
  for name in "$@"; do
    if apt-cache policy "$name" 2>/dev/null | grep -q 'Candidate: [^(]'; then echo "$name"; return; fi
  done
}

packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  # Tauri v2's list for Debian and Ubuntu; whisper.cpp's Vulkan build (cmake, glslc) and bindings (libclang);
  # the bundles (patchelf, file, FUSE 2 for linuxdeploy); the window's tests (WebKitGTK's WebDriver, xvfb,
  # xdotool, openbox); the Secret Service; what Playwright's own WebKit needs beyond these (the browser tests in
  # WebKit, `e2e`'s WEBKIT=1).
  apt-get install -y -q build-essential curl wget file rsync git pkg-config cmake libssl-dev libxdo-dev \
    libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev patchelf \
    libvulkan-dev $(known glslc) vulkan-tools mesa-vulkan-drivers libclang-dev clang \
    "$(known webkitgtk-webdriver webkit2gtk-driver)" xvfb gnome-keyring dbus dbus-x11 libdbus-1-dev libsecret-tools \
    python-is-python3 "$(known libfuse2t64 libfuse2)" xdotool x11-apps openbox $(known libevent-2.1-7t64 libevent-2.1-7) $(known libavif16t64 libavif16) libmanette-0.2-0
}

# Inside dbus-run-session: a throwaway login collection in a scratch folder, then the command; its status.
keyring() {
  unset DISPLAY WAYLAND_DISPLAY
  local keyrings status=0
  keyrings="$(mktemp -d)"
  echo -n "cardwave-test" | XDG_DATA_HOME="$keyrings" gnome-keyring-daemon --unlock --components=secrets >/dev/null
  "$@" || status=$?
  rm -rf "$keyrings"
  return "$status"
}

# <cmd> on a virtual screen of its own (Xvfb, never WSLg's, which is the owner's), with Openbox (maximizing, the
# work area and the frames need a window manager) and a D-Bus session of its own; its status.
on_screen() {
  # GTK takes WSLg's Wayland (wayland-0) even with WAYLAND_DISPLAY unset: only x11 keeps it in Xvfb.
  unset WAYLAND_DISPLAY DISPLAY
  export GDK_BACKEND=x11
  dbus-run-session -- xvfb-run -a -s "-screen 0 1920x1080x24" bash -c 'openbox & sleep 1; "$@"' screen "$@"
}

# linuxdeploy would put the build computer's libvulkan.so.1 into the AppImage: the user's own system's must be
# found, as it leads to their graphics drivers. linuxdeploy runs extracted, needing no FUSE.
bundle() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../desktop"
  LINUXDEPLOY_EXCLUDED_LIBRARIES='libvulkan.so*' APPIMAGE_EXTRACT_AND_RUN=1 npm run dist
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    packages) packages ;;
    keyring) shift; keyring "$@" ;;
    screen) shift; on_screen "$@" ;;
    bundle) bundle ;;
    *) echo "usage: tools/linux.sh packages|keyring <command>|screen <command>|bundle" >&2; exit 2 ;;
  esac
fi
