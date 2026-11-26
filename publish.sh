#!/usr/bin/env bash
# Publishes WC PeekGuard to your GitHub account, end to end, in one command.
#
#   ./publish.sh                  # repo name: wechat-privacy
#   REPO_NAME=my-name ./publish.sh
#
# It will, in order:
#   1. make sure the GitHub CLI is available (downloads it to a temp dir if not)
#   2. log you in through the browser (only the first time)
#   3. fill your username into README.md / install.sh
#   4. build the universal app + zip
#   5. create the public repo, commit, push
#   6. publish v1.0.0 with the zip attached, so the one-line installer works
set -euo pipefail
cd "$(dirname "$0")"

REPO_NAME="${REPO_NAME:-wc-peekguard}"
VERSION="${VERSION:-1.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-11}"
DESCRIPTION="给绿色泡泡加一层隐私罩：静置 15 秒自动盖住，回来按 Touch ID 才让开。No screen recording, no permissions, no network."

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }
die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. GH CLI
say "1/6  GitHub CLI"
TOOLS="${TMPDIR:-/tmp}/wechat-privacy-tools"
if command -v gh >/dev/null 2>&1; then
  GH="$(command -v gh)"
  note "using installed gh $(gh --version | head -1 | awk '{print $3}')"
elif [[ -x "$TOOLS/gh-bin" ]]; then
  GH="$TOOLS/gh-bin"
  note "using cached portable gh"
else
  note "gh not found, downloading a portable copy..."
  mkdir -p "$TOOLS"
  TAG="$(curl -fsSL --retry 3 https://api.github.com/repos/cli/cli/releases/latest \
         | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)"
  [[ -n "$TAG" ]] || die "could not reach api.github.com — check your network / proxy"
  ARCH="$(uname -m)"; [[ "$ARCH" == "arm64" ]] || ARCH="amd64"
  curl -fsSL --retry 3 \
    "https://github.com/cli/cli/releases/download/v${TAG}/gh_${TAG}_macOS_${ARCH}.zip" \
    -o "$TOOLS/gh.zip" || die "could not download the GitHub CLI"
  rm -rf "$TOOLS/gh-unpack"
  ditto -x -k "$TOOLS/gh.zip" "$TOOLS/gh-unpack"
  FOUND="$(find "$TOOLS/gh-unpack" -type f -name gh -perm +111 | head -1)"
  [[ -n "$FOUND" ]] || die "GitHub CLI unpack failed"
  cp "$FOUND" "$TOOLS/gh-bin"; chmod +x "$TOOLS/gh-bin"
  GH="$TOOLS/gh-bin"
  note "portable gh ready"
fi

# ---------------------------------------------------------------- 2. login
say "2/6  GitHub login"
if ! "$GH" auth status >/dev/null 2>&1; then
  note "a one-time code and a browser page will appear; paste the code, then click Authorize"
  "$GH" auth login --hostname github.com --git-protocol https --web --scopes repo,workflow
fi
OWNER="$("$GH" api user --jq .login)"
note "signed in as $OWNER"

# ---------------------------------------------------------------- 3. facts
say "3/6  filling your username into README.md and install.sh"
for f in README.md install.sh; do
  [[ -f "$f" ]] || continue
  grep -q '__OWNER__' "$f" && sed -i '' "s/__OWNER__/${OWNER}/g" "$f" && note "updated $f"
done
grep -rn '__OWNER__' . --include='*.md' --include='*.sh' 2>/dev/null | head -3 || true

# ---------------------------------------------------------------- 4. build
say "4/6  building"
chmod +x build.sh install.sh
./build.sh "$VERSION" "$BUILD_NUMBER" >/dev/null
note "built dist/WCPeekGuard-$VERSION.zip"

# ---------------------------------------------------------------- 5. commit
say "5/6  creating the repository and pushing"
git rev-parse --git-dir >/dev/null 2>&1 || git init -q
git config user.name "$OWNER"
git config user.email "${OWNER}@users.noreply.github.com"
git add -A
git diff --cached --quiet || git commit -q -m "WC PeekGuard ${VERSION}: cover the green bubble after 15s, reveal with Touch ID"
git branch -M main

if "$GH" repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  note "repo $OWNER/$REPO_NAME already exists, reusing it"
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
  git push -u origin main
else
  "$GH" repo create "$REPO_NAME" --public --source=. --remote=origin \
    --push --description "$DESCRIPTION"
fi
git remote set-head origin -a >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 6. release
say "6/6  publishing v$VERSION"
if "$GH" release view "v$VERSION" >/dev/null 2>&1; then
  "$GH" release upload "v$VERSION" "dist/WCPeekGuard-$VERSION.zip" \
    "dist/WCPeekGuard.zip" --clobber
else
  cp "dist/WCPeekGuard-$VERSION.zip" dist/WCPeekGuard.zip
  "$GH" release create "v$VERSION" \
    "dist/WCPeekGuard.zip" \
    --title "v$VERSION" \
    --notes "首个公开版本。

- 绿色泡泡静置 15 秒自动盖住，回来自动弹 Touch ID
- 切到别的 App 时把绿色泡泡窗口一起收起，不在别人屏幕上留白板
- 不申请屏幕录制 / 辅助功能 / 输入监控，不联网
- 通用二进制（Apple 芯片 + Intel），macOS 14+"
fi

cat <<EOF

$(printf '\033[1m%s\033[0m' "完成")
  仓库     https://github.com/$OWNER/$REPO_NAME
  发布页   https://github.com/$OWNER/$REPO_NAME/releases/latest
  一行安装 curl -fsSL https://raw.githubusercontent.com/$OWNER/$REPO_NAME/main/install.sh | bash

  接下来建议：
    · 在仓库 Settings 里加 Topics：macos, swift, wechat, privacy, menu-bar
    · 在 Settings → General → Social preview 上传 docs/hero.png
EOF
