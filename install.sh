#!/usr/bin/env bash
# WC PeekGuard — installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/syz-123/wc-peekguard/main/install.sh | bash
#
# When the network cannot reach the release CDN (common behind a rule-based VPN),
# download WCPeekGuard.zip with a browser and install from the local file:
#
#   bash install.sh --from ~/Downloads/WCPeekGuard.zip
#   bash install.sh --from ~/Downloads/"WC PeekGuard.app"     # Safari already unzipped it
#
# Installs to ~/Applications, strips the quarantine flag so Gatekeeper does not
# block the (ad-hoc signed, not notarised) build, then launches it. Re-running
# the same command upgrades an existing install.
set -euo pipefail

REPO="syz-123/wc-peekguard"
APP_NAME="WC PeekGuard.app"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/$APP_NAME"
URL="https://github.com/$REPO/releases/latest/download/WCPeekGuard.zip"

say()  { printf '%s\n' "$*"; }
warn() { printf '   %s\n' "$*"; }
fail() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: install.sh [--from /path/to/WCPeekGuard.zip or "/path/to/WC PeekGuard.app"]

  no arguments   download the latest release and install it
  --from PATH    install from a file you already downloaded
EOF
}

FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="${2:-}"; [[ -n "$FROM" ]] || fail "--from needs a path"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1 (try --help)" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || fail "this installer only supports macOS"

if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
  fail "WC PeekGuard needs macOS 14 or newer (you have $(sw_vers -productVersion))"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- source
APP_SRC=""
if [[ -n "$FROM" ]]; then
  FROM="${FROM/#\~/$HOME}"
  [[ -e "$FROM" ]] || fail "no such file: $FROM"
  if [[ -d "$FROM" ]]; then
    [[ "$FROM" == *.app ]] || fail "expected a .zip or .app, got a directory: $FROM"
    say ":: installing from local app: $FROM"
    APP_SRC="$FROM"
  else
    say ":: installing from local file: $FROM"
    SRC_ZIP="$FROM"
  fi
fi

# Detection of the system proxy. curl ignores macOS proxy settings, which is the
# single most common reason a user's browser reaches GitHub but this script does not.
system_proxy() {
  local host port
  if scutil --proxy 2>/dev/null | grep -q "HTTPSEnable : 1"; then
    host="$(scutil --proxy | awk '/HTTPSProxy/ {print $3; exit}')"
    port="$(scutil --proxy | awk '/HTTPSPort/ {print $3; exit}')"
    [[ -n "$host" && -n "$port" ]] && { printf 'http://%s:%s' "$host" "$port"; return 0; }
  fi
  if scutil --proxy 2>/dev/null | grep -q "SOCKSEnable : 1"; then
    host="$(scutil --proxy | awk '/SOCKSProxy/ {print $3; exit}')"
    port="$(scutil --proxy | awk '/SOCKSPort/ {print $3; exit}')"
    [[ -n "$host" && -n "$port" ]] && { printf 'socks5h://%s:%s' "$host" "$port"; return 0; }
  fi
  return 1
}

download() {
  local proxy="$1" err="$2"
  local args=(-fsSL --connect-timeout 15 --max-time 300 --retry 3 --retry-delay 2)
  curl --help 2>/dev/null | grep -q -- '--retry-all-errors' && args+=(--retry-all-errors)
  [[ -n "$proxy" ]] && args+=(--proxy "$proxy")
  curl "${args[@]}" "$URL" -o "$SRC_ZIP" 2>"$err"
}

if [[ -z "$APP_SRC" && -z "${SRC_ZIP:-}" ]]; then
  say ":: downloading the latest release"
  SRC_ZIP="$TMP/WCPeekGuard.zip"
  if ! download "" "$TMP/e1"; then
    PROXY="$(system_proxy || true)"
    if [[ -n "$PROXY" ]]; then
      say ":: direct download failed, retrying through your system proxy"
      warn "$PROXY"
      download "$PROXY" "$TMP/e2" || {
        sed 's/^/   /' "$TMP/e2" 2>/dev/null || true
        fail "download failed even through the system proxy.

  Use a browser instead — it is the one thing that already works for you:

    1. open https://github.com/$REPO/releases
    2. download both WCPeekGuard.zip and install.sh from that page
    3. in Terminal, run:
         bash ~/Downloads/install.sh --from ~/Downloads/WCPeekGuard.zip

  No terminal at all? Download WCPeekGuard.zip, double-click it, drag
  WC PeekGuard.app to Applications, then right-click it and choose Open."
      }
    else
      sed 's/^/   /' "$TMP/e1" 2>/dev/null || true
      fail "download failed, and no system proxy is configured.

  Use a browser instead:

    1. open https://github.com/$REPO/releases
    2. download both WCPeekGuard.zip and install.sh from that page
    3. in Terminal, run:
         bash ~/Downloads/install.sh --from ~/Downloads/WCPeekGuard.zip

  No terminal at all? Download WCPeekGuard.zip, double-click it, drag
  WC PeekGuard.app to Applications, then right-click it and choose Open."
    fi
  fi
fi

# ---------------------------------------------------------------- unpack
if [[ -z "$APP_SRC" ]]; then
  say ":: unpacking"
  ditto -x -k "$SRC_ZIP" "$TMP/out" || fail "could not unpack $SRC_ZIP — the download may be incomplete. Try again."
  APP_SRC="$TMP/out/$APP_NAME"
fi

[[ -d "$APP_SRC" ]] || fail "that archive does not contain $APP_NAME.

  If you downloaded from the Releases page, make sure you picked WCPeekGuard.zip."

[[ "$(basename "$APP_SRC")" == "$APP_NAME" ]] || fail "expected $APP_NAME, found $(basename "$APP_SRC")"

# ---------------------------------------------------------------- verify
# Verify before touching the destination: never install a bundle we cannot validate.
if command -v codesign >/dev/null 2>&1; then
  say ":: verifying signature"
  codesign --verify --deep --strict "$APP_SRC" 2>/dev/null \
    || fail "signature verification failed — the download is damaged or was modified. Download it again."
fi

# ---------------------------------------------------------------- install
say ":: installing to $DEST"
killall WCPeekGuard 2>/dev/null || true
mkdir -p "$DEST_DIR" 2>/dev/null || fail "cannot create $DEST_DIR"
rm -rf "$DEST"
ditto "$APP_SRC" "$DEST" || fail "could not write to $DEST_DIR — check disk space and permissions."

# The build is ad-hoc signed, so macOS would otherwise refuse to launch it.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

say ":: launching"
# A failed `open` must not turn a successful install into a reported failure.
open "$DEST" 2>/dev/null || warn "(installed, but could not launch it — open it from $DEST_DIR)"

cat <<EOF

  Installed: $DEST

  A 🙈 should now be sitting in your menu bar.
  Cover it right away:  click 🙈 → "Cover 绿色泡泡 now"
  Turn protection off:  click 🙈 → "Quit WC PeekGuard…"

  To upgrade later, just run this same command again.
  To remove it completely:
    killall WCPeekGuard
    rm -rf "$DEST"

EOF
