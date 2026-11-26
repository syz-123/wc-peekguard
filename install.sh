#!/usr/bin/env bash
# WC PeekGuard — one-line installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/syz-123/wc-peekguard/main/install.sh | bash
#
# Installs to ~/Applications, strips the quarantine flag so Gatekeeper does not
# block the (ad-hoc signed, not notarised) build, then launches it.
set -euo pipefail

REPO="syz-123/wc-peekguard"
APP_NAME="WC PeekGuard.app"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/$APP_NAME"
URL="https://github.com/$REPO/releases/latest/download/WCPeekGuard.zip"

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "this installer only supports macOS"

if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
  fail "WC PeekGuard needs macOS 14 or newer (you have $(sw_vers -productVersion))"
fi

say ":: downloading the latest release"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Timeouts matter: without them a blocked connection hangs silently for minutes.
curl -fsSL --connect-timeout 15 --max-time 300 --retry 2 --retry-delay 2 \
  "$URL" -o "$TMP/WCPeekGuard.zip" \
  || fail "download failed. If this network cannot reach GitHub, download WCPeekGuard.zip
  from https://github.com/$REPO/releases and install it by hand."

say ":: unpacking"
ditto -x -k "$TMP/WCPeekGuard.zip" "$TMP/out" || fail "could not unpack the archive"
[[ -d "$TMP/out/$APP_NAME" ]] || fail "archive layout looks wrong, aborting"

# Verify before touching the destination: never install a bundle we cannot validate.
if command -v codesign >/dev/null 2>&1; then
  say ":: verifying signature"
  codesign --verify --deep --strict "$TMP/out/$APP_NAME" 2>/dev/null \
    || fail "the downloaded app failed signature verification. Delete it and try again."
fi

say ":: installing to $DEST"
killall WCPeekGuard 2>/dev/null || true
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
ditto "$TMP/out/$APP_NAME" "$DEST" || fail "could not write to $DEST_DIR — check disk space and permissions."

# The build is ad-hoc signed, so macOS would otherwise refuse to launch it.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

say ":: launching"
open "$DEST"

cat <<EOF

  Installed: $DEST

  A 🙈 should now be sitting in your menu bar.
  Cover it right away:      click 🙈 → "Cover 绿色泡泡 now"
  Turn it off completely:   click 🙈 → "Quit WC PeekGuard…"

  Tip: add it under System Settings → General → Login Items if you want it
  back after a reboot (it does not register itself, on purpose).

EOF
