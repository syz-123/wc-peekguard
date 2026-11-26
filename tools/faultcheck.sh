#!/usr/bin/env bash
# Fault injection for install.sh. Answers one question per case:
# "when this goes wrong, does it fail cleanly and leave nothing behind?"
#
#   ./tools/faultcheck.sh
#
# Needs a built artifact: run ./build.sh first.
set -uo pipefail
cd "$(dirname "$0")/.."

ZIP="$(ls dist/WCPeekGuard-*.zip 2>/dev/null | head -1)"
[[ -n "$ZIP" ]] || { echo "先跑 ./build.sh 生成 dist/ 里的 zip"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; chmod -R u+w "$WORK" 2>/dev/null' EXIT
mkdir -p "$WORK/stub"
printf '#!/bin/bash\necho "[stub] open $*"\n' > "$WORK/stub/open"
printf '#!/bin/bash\necho "[stub] killall $*"\n' > "$WORK/stub/killall"
chmod +x "$WORK/stub/open" "$WORK/stub/killall"

cp "$ZIP" "$WORK/good.zip"
mkdir -p "$WORK/wrong/Wrong.app/Contents" && echo x > "$WORK/wrong/Wrong.app/Contents/Info.plist"
(cd "$WORK/wrong" && zip -qr "$WORK/bad-layout.zip" .)
head -c 4000 /dev/urandom > "$WORK/corrupt.zip"

PASS=0
FAIL=0

# run_case <name> <url> <expected: fail|ok> [extra PATH prefix]
run_case() {
  local name="$1" url="$2" expect="$3" pathprefix="${4:-$WORK/stub}"
  sed "s|^URL=.*|URL=\"$url\"|" install.sh > "$WORK/t.sh"
  rm -rf "$WORK/home"; mkdir -p "$WORK/home"
  HOME="$WORK/home" PATH="$pathprefix:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$WORK/t.sh" > "$WORK/out.txt" 2>&1
  local rc=$?
  local residue="none"
  [[ -e "$WORK/home/Applications" ]] && residue="$(find "$WORK/home/Applications" -mindepth 1 | wc -l | tr -d ' ') files"

  local verdict="PASS"
  if [[ "$expect" == "fail" && $rc -eq 0 ]]; then verdict="FAIL"; fi
  if [[ "$expect" == "ok"   && $rc -ne 0 ]]; then verdict="FAIL"; fi
  if [[ "$expect" == "fail" && "$residue" != "none" ]]; then verdict="FAIL"; fi

  if [[ "$verdict" == "PASS" ]]; then
    PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %-34s exit=%s residue=%s\n' "$name" "$rc" "$residue"
  else
    FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %-34s exit=%s residue=%s\n' "$name" "$rc" "$residue"
    tail -3 "$WORK/out.txt" | sed 's/^/      /'
  fi
}

echo "== 安装脚本故障注入 =="
run_case "404 仓库不存在"        "https://github.com/x/nope/releases/latest/download/WCPeekGuard.zip" fail
run_case "压缩包结构不对"        "file://$WORK/bad-layout.zip" fail
run_case "文件损坏"              "file://$WORK/corrupt.zip"    fail
run_case "正常安装"              "file://$WORK/good.zip"       ok

# 目标目录不可写
sed "s|^URL=.*|URL=\"file://$WORK/good.zip\"|" install.sh > "$WORK/t.sh"
rm -rf "$WORK/home"; mkdir -p "$WORK/home/Applications"; chmod 500 "$WORK/home/Applications"
HOME="$WORK/home" PATH="$WORK/stub:/usr/bin:/bin:/usr/sbin:/sbin" bash "$WORK/t.sh" > "$WORK/out.txt" 2>&1
rc=$?
chmod 700 "$WORK/home/Applications"
if [[ $rc -ne 0 ]] && grep -q "could not write" "$WORK/out.txt"; then
  PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %-34s exit=%s\n' "目标目录不可写" "$rc"
else
  FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %-34s exit=%s\n' "目标目录不可写" "$rc"
fi

# 没有 codesign 命令时仍应装成功
mkdir -p "$WORK/nocodesign"
for t in open killall curl ditto unzip mktemp rm mkdir sw_vers cut cat grep sed; do
  p="$(command -v $t 2>/dev/null)" && ln -sf "$p" "$WORK/nocodesign/$t"
done
run_case "环境里没有 codesign"    "file://$WORK/good.zip" ok "$WORK/nocodesign"

# open 失败（无图形会话）时，不应把成功当成失败
mkdir -p "$WORK/badopen"
for t in killall curl ditto unzip mktemp rm mkdir sw_vers cut cat grep sed codesign; do
  p="$(command -v $t 2>/dev/null)" && ln -sf "$p" "$WORK/badopen/$t"
done
printf '#!/bin/bash\nexit 1\n' > "$WORK/badopen/open"; chmod +x "$WORK/badopen/open"
run_case "open 失败（无图形会话）" "file://$WORK/good.zip" ok "$WORK/badopen"

# 低版本系统必须拒绝
mkdir -p "$WORK/oldmac"
for t in open killall curl ditto unzip mktemp rm mkdir cut cat grep sed codesign; do
  p="$(command -v $t 2>/dev/null)" && ln -sf "$p" "$WORK/oldmac/$t"
done
printf '#!/bin/bash\ncase "$1" in -productVersion) echo 13.6;; *) echo 13.6;; esac\n' > "$WORK/oldmac/sw_vers"
chmod +x "$WORK/oldmac/sw_vers"
run_case "macOS 13 应被拒绝"      "file://$WORK/good.zip" fail "$WORK/oldmac"

# 重复安装
rm -rf "$WORK/home"; mkdir -p "$WORK/home"
sed "s|^URL=.*|URL=\"file://$WORK/good.zip\"|" install.sh > "$WORK/t.sh"
ok_twice=1
for i in 1 2; do
  HOME="$WORK/home" PATH="$WORK/stub:/usr/bin:/bin:/usr/sbin:/sbin" bash "$WORK/t.sh" > /dev/null 2>&1 || ok_twice=0
done
if [[ $ok_twice -eq 1 ]]; then
  PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %-34s %s\n' "连续安装两次" "ok"
else
  FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %-34s %s\n' "连续安装两次" "failed"
fi

echo
echo "== 构建脚本 =="
if (cd /tmp && "$OLDPWD/build.sh" 0.0.0 0 >/dev/null 2>&1); then
  PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %-34s %s\n' "从任意目录调用 build.sh" "ok"
else
  FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %-34s %s\n' "从任意目录调用 build.sh" "failed"
fi

echo
if [[ $FAIL -gt 0 ]]; then
  printf '\033[31m%d 项失败 / %d 项通过\033[0m\n' "$FAIL" "$PASS"
  exit 1
fi
printf '\033[32m全部通过（%d 项）\033[0m\n' "$PASS"
