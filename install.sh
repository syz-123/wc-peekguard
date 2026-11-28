#!/usr/bin/env bash
# WC PeekGuard — one-line installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/syz-123/wc-peekguard/main/install.sh | bash
#
# Or, when the network cannot reach the release CDN, download the zip in a
# browser and install from the local file:
#
#   curl -fsSL https://raw.githubusercontent.com/syz-123/wc-peekguard/main/install.sh -o /tmp/wcpeekguard.sh
#   bash /tmp/wcpeekguard.sh --from ~/Downloads/WCPeekGuard.zip
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

FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="${2:-}"; [[ -n "$FROM" ]] || fail "--from needs a path"; shift 2 ;;
    -h|--help) say "usage: install.sh [--from /path/to/WCPeekGuard.zip]"; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || fail "this installer only supports macOS"

if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
  fail "WC PeekGuard needs macOS 14 or newer (you have $(sw_vers -productVersion))"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ -n "$FROM" ]]; then
  [[ -f "$FROM" ]] || fail "no such file: $FROM"
  say ":: installing from local file: $FROM"
  SRC_ZIP="$FROM"
else
  say ":: downloading the latest release"
  # Timeouts matter: without them a blocked connection hangs silently for minutes.
  # --retry-all-errors also retries transfer errors (55/56), not just timeouts.
  SRC_ZIP="$TMP/WCPeekGuard.zip"
  curl -fsSL --connect-timeout 15 --max-time 300 \
    --retry 5 --retry-delay 2 --retry-all-errors \
    "$URL" -o "$SRC_ZIP" 2>"$TMP/curl.err" || {
      sed 's/^/  /' "$TMP/curl.err" >&2 || true
      fail "download failed.

  GitHub's release download host is often unreachable even when github.com
  loads in your browser (common with rule-based VPNs). This works every time:

    1. open https://github.com/$REPO/releases
    2. download WCPeekGuard.zip with your browser
    3. then run:
         curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh -o /tmp/wcpeekguard.sh
         bash /tmp/wcpeekguard.sh --from ~/Downloads/WCPeekGuard.zip"
    }
fi

say ":: unpacking"
ditto -x -k "$SRC_ZIP" "$TMP/out" || fail "could not unpack the archive"
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
# A failed `open` must not turn a successful install into a reported failure.
open "$DEST" 2>/dev/null || say "   (installed, but could not launch it — open it from $DEST_DIR)"

cat <<EOF

  Installed: $DEST

  A 🙈 should now be sitting in your menu bar.
  Cover it right away:      click 🙈 → "Cover 绿色泡泡 now"
  Turn it off completely:   click 🙈 → "Quit WC PeekGuard…"

  Tip: add it under System Settings → General → Login Items if you want it
  back after a reboot (it does not register itself, on purpose).

EOF
