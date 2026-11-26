#!/usr/bin/env python3
"""Consistency self-check for WC PeekGuard.

Every check here exists because something broke once. Run it before publishing:

    python3 tools/selfcheck.py

Exits non-zero if anything that must match does not match.
"""
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
failures: list[str] = []
passes = 0


def ok(msg: str) -> None:
    global passes
    passes += 1
    print(f"  \033[32m✓\033[0m {msg}")


def bad(msg: str) -> None:
    failures.append(msg)
    print(f"  \033[31m✗\033[0m {msg}")


def check(cond: bool, good: str, bad_msg: str) -> None:
    ok(good) if cond else bad(bad_msg)


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def section(title: str) -> None:
    print(f"\n== {title} ==")


# ---------------------------------------------------------------- 1. names
section("1. 名称一致性（这个错犯过三次）")
install_sh = read("install.sh")
build_sh = read("build.sh")

m = re.search(r'APP_NAME="([^"]+)"', install_sh)
app_name = m.group(1) if m else None
check(bool(app_name), f"install.sh 声明 APP_NAME = {app_name}", "install.sh 里找不到 APP_NAME")

m = re.search(r'APP="\$STAGE/([^"]+)"', build_sh)
build_app = m.group(1) if m else None
check(
    app_name == build_app,
    f"构建产物名与安装脚本一致（{build_app}）",
    f"构建产物名 '{build_app}' ≠ 安装脚本期望 '{app_name}' —— 陌生人会装不上",
)

m = re.search(r"'CFBundleExecutable': '([^']+)'", build_sh)
exe = m.group(1) if m else None
ok(f"可执行文件名 = {exe}")

# every `killall X` in docs/scripts must target that exact process name
for f in ["install.sh", "README.md", "docs/getting-started.md"]:
    if not (ROOT / f).exists():
        continue
    for hit in re.findall(r"killall\s+([A-Za-z]+)", read(f)):
        check(
            hit == exe,
            f"{f}: killall {hit} 与进程名一致",
            f"{f}: killall {hit} ≠ 实际进程名 {exe}（卸载命令会失效）",
        )

# any mention of the .app bundle must match byte for byte
for f in ["README.md", "docs/getting-started.md", "install.sh"]:
    if not (ROOT / f).exists():
        continue
    for hit in set(re.findall(r"[A-Za-z ]+\.app\b", read(f))):
        hit = hit.strip()
        if hit.startswith("/"):  # absolute paths are constructed, skip
            continue
        check(
            hit == app_name,
            f"{f}: 引用 {hit} 正确",
            f"{f}: 引用了 '{hit}'，实际是 '{app_name}'（多/少一个空格就会找错文件）",
        )

# ---------------------------------------------------------------- 2. repo
section("2. 仓库地址一致性")
repos = set()
for f in ["install.sh", "README.md", "publish.sh"]:
    if (ROOT / f).exists():
        repos |= set(re.findall(r"github\.com/([\w.-]+/[\w.-]+)", read(f)))
        repos |= set(re.findall(r"raw\.githubusercontent\.com/([\w.-]+/[\w.-]+)/", read(f)))
repos = {r.removesuffix(".git") for r in repos}
# cli/cli is the GitHub CLI download URL inside publish.sh, not our repo
expected = {r for r in repos if r not in {"cli/cli", "repos/cli"}}
check(
    len({r.split("/")[1] for r in expected}) == 1,
    f"所有链接指向同一个仓库（{', '.join(sorted(expected))}）",
    f"仓库名不一致：{sorted(expected)}",
)

# asset name the installer fetches must be the one CI uploads
m = re.search(r"releases/latest/download/([^\"\s]+)", install_sh)
asset = m.group(1) if m else None
release_yml = read(".github/workflows/release.yml")
check(
    bool(asset) and asset in release_yml,
    f"安装脚本下载的 asset '{asset}' 与 CI 上传的一致",
    f"安装脚本要 '{asset}'，但 release.yml 里没有这个名字",
)

# ---------------------------------------------------------------- 3. leaks
section("3. 不该出现在公开仓库里的东西")
STAGED = subprocess.run(
    ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True
).stdout.split()
# publish.sh is the tool that *performs* the substitution, so it legitimately contains the literal
leaks = [f for f in STAGED
         if f != "publish.sh" and "__OWNER__" in (ROOT / f).read_text(errors="ignore")]
check(not leaks, "没有残留的 __OWNER__ 占位符", f"占位符未替换：{leaks}")

personal = []
for f in STAGED:
    p = ROOT / f
    if p.suffix in {".png", ".icns"} or not p.exists():
        continue
    if re.search(r"/Users/[a-zA-Z]", p.read_text(errors="ignore")):
        personal.append(f)
check(not personal, "待发布文件里没有本机绝对路径", f"含本机路径的文件：{personal}")

# ---------------------------------------------------------------- 4. files
section("4. 文件模式与语法")
modes = subprocess.run(
    ["git", "ls-files", "-s"], cwd=ROOT, capture_output=True, text=True
).stdout
for script in ["build.sh", "install.sh"]:
    line = next((l for l in modes.splitlines() if l.endswith(script)), "")
    check(
        "100755" in line,
        f"{script} 有可执行权限",
        f"{script} 缺少可执行权限（clone 下来 ./{script} 会 permission denied）",
    )

for script, shell in [("build.sh", "zsh"), ("install.sh", "bash"), ("publish.sh", "bash")]:
    if not (ROOT / script).exists():
        continue
    r = subprocess.run([shell, "-n", str(ROOT / script)], capture_output=True, text=True)
    check(r.returncode == 0, f"{script} 语法通过", f"{script} 语法错误：{r.stderr.strip()}")

for wf in sorted((ROOT / ".github/workflows").glob("*.yml")):
    try:
        import yaml

        yaml.safe_load(wf.read_text())
        ok(f"{wf.name} YAML 合法")
    except Exception as e:  # noqa: BLE001
        bad(f"{wf.name} YAML 解析失败：{e}")

# ---------------------------------------------------------------- 5. docs
section("5. 文档链接")
for md in [ROOT / "README.md", ROOT / "docs/getting-started.md"]:
    if not md.exists():
        continue
    text = md.read_text()
    for target in set(re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", text)):
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        resolved = (md.parent / target).resolve()
        check(
            resolved.exists(),
            f"{md.name} → {target}",
            f"{md.name} 里的相对链接 {target} 指向不存在的文件",
        )

# ---------------------------------------------------------------- 6. build
section("6. 构建产物（如果本地有 dist/）")
zips = sorted((ROOT / "dist").glob("*.zip")) if (ROOT / "dist").exists() else []
if not zips:
    print("  –  没有 dist/，跳过（发布前请先跑 ./build.sh）")
else:
    z = zips[0]
    with zipfile.ZipFile(z) as zf:
        top = {n.split("/")[0] for n in zf.namelist() if n}
    check(
        top == {app_name},
        f"{z.name} 内顶层目录 = {app_name}",
        f"{z.name} 内顶层目录是 {top}，安装脚本期望 {app_name}",
    )
    with tempfile.TemporaryDirectory() as td:
        with zipfile.ZipFile(z) as zf:
            zf.extractall(td)
        plist = Path(td) / app_name / "Contents/Info.plist"
        if plist.exists():
            info = plistlib.loads(plist.read_bytes())
            check(
                info.get("CFBundleExecutable") == exe,
                f"Info.plist 可执行文件名 = {exe}",
                f"Info.plist CFBundleExecutable={info.get('CFBundleExecutable')} ≠ {exe}",
            )
            check(
                info.get("LSUIElement") is True,
                "LSUIElement = true（不占 Dock）",
                "LSUIElement 不是 true，会出现 Dock 图标",
            )
            check(
                float(str(info.get("LSMinimumSystemVersion", "0"))) >= 14,
                f"最低系统 = {info.get('LSMinimumSystemVersion')}",
                "LSMinimumSystemVersion 缺失或不合理",
            )
        else:
            bad(f"{z.name} 里找不到 Info.plist")

# ---------------------------------------------------------------- report
print()
if failures:
    print(f"\033[31m{len(failures)} 项未通过\033[0m:")
    for f in failures:
        print(f"  · {f}")
    sys.exit(1)
print(f"\033[32m全部通过（{passes} 项）\033[0m")
