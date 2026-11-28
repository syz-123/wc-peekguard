<div align="center">

<img src="docs/hero.png" width="820" alt="WC PeekGuard: 绿色泡泡 covered by a 🙈 panel with a Touch ID prompt">

# WC PeekGuard

**你走开的时候，它替你挡着。**

手离开键盘 15 秒，绿色泡泡自己盖上一层 🙈。回来按一下指纹，原样还你。

<img src="https://img.shields.io/badge/macOS-14%2B-1f2328?logo=apple&logoColor=white" alt="macOS 14+">
<img src="https://img.shields.io/badge/Swift-5-f05138?logo=swift&logoColor=white" alt="Swift">
<img src="https://img.shields.io/badge/license-MIT-3b82f6" alt="MIT">
<img src="https://img.shields.io/badge/network-none-16a34a" alt="No network">
<img src="https://img.shields.io/badge/permissions-none-16a34a" alt="No permissions">
<img src="https://github.com/syz-123/wc-peekguard/actions/workflows/build.yml/badge.svg" alt="Build">

[装它](#装它) · [它不是手机解锁](#它不是手机远程解锁) · [隐私账本](#隐私账本它到底要什么权限) · [它做不到什么](#它做不到什么)

</div>

> **English** — A ~400-line macOS menu-bar helper for the green-bubble chat app. Leave your Mac for 15 seconds and your chat windows get covered; come back and Touch ID reveals them. It draws a panel over the windows instead of touching the app itself: no injection, no screen recording, no accessibility access, no network. Free, MIT, macOS 14+ (Apple Silicon & Intel).
>
> **Install** — `curl -fsSL https://raw.githubusercontent.com/syz-123/wc-peekguard/main/install.sh | bash`
> If that download fails (common behind a rule-based VPN), grab both `WCPeekGuard.zip` and `install.sh` from [Releases](https://github.com/syz-123/wc-peekguard/releases/latest) and run `bash ~/Downloads/install.sh --from ~/Downloads/WCPeekGuard.zip`. No terminal at all: unzip, drag to Applications, right-click → Open.

---

## 那三十秒

你起身去接杯水。电脑不会自己锁屏，聊天窗口大剌剌摊在桌上，最后一条消息还停在最上面。

三十秒后你回来，发现有人正站在你工位边上，两个人都假装没看见那条消息。

也可能不是水。是你扭过头去跟同事说话，是会议开始前切屏幕的那一下，是地铁上一个急刹车让你抬头了两秒。**这些时刻的共同点是：你并不是不重视隐私，你只是没想到那一眼来得这么快，而你的手永远比它慢半拍。**

按 `⌘H` 要记得，锁屏要记得，把窗口拖到边上也要记得——所有要"记得"的方案，都会在你真正忘记的那一次失效。

WC PeekGuard 补的就是这一次：

**手离开键盘鼠标 15 秒，绿色泡泡自己盖上。不用你记得任何事。**

回来，指纹一按，它把窗口原样还给你，连输入焦点都没动过。

> 你不需要多学一个操作，你只需要少想一件事。

## 它只认绿色泡泡

这不是一个"万能窗口遮挡器"。

它只盯一个应用，只对这一个应用生效。别的 App 开着聊天窗口、别的窗口露在屏幕上，它一概不管——**它不是一个通用隐私工具，它是给绿色泡泡做的专用件。**

这个刻意的限制换来的是另一件事：它可以做到**什么权限都不要**。因为它不需要"看懂"你的屏幕，它只需要知道"那个窗口在哪、现在是不是它"。

## 它不是「手机远程解锁」

绿色泡泡自带一个「用手机解锁电脑端」的功能。刚听说 WC PeekGuard 的人第一反应通常是：**这不是已经有了吗？**

不是。这两个功能长得很像，解决的问题完全不同。

| | 手机远程解锁（官方自带） | WC PeekGuard |
| --- | --- | --- |
| 它服务的那句话 | "我要用手机，操作电脑上这台绿色泡泡" | "我不在电脑前，也不想别人在电脑前" |
| 触发方式 | **你主动**：掏出手机 → 解锁手机 → 打开绿色泡泡 → 点按钮 | **自动**：你什么都不做，15 秒后自己盖上 |
| 手机得在身边、得有电 | 是 | 不需要 |
| 你扭头跟人说话的那一瞬间 | 帮不上。你得先暂停对话，去操作手机 | 已经替你盖好了 |
| 想要的结果 | 远程接力，甚至把会话交给别人继续 | 只是不想被看见，就这么简单 |
| 适合的场景 | 人在沙发上、床上，想接着聊 | 工位、会议室、地铁、共享办公区 |

**最本质的差别在触发权。**

官方那个功能，开关在你手里——所以它要求你**记得**。而真正会出事的那一刻，恰恰是你**忘了**、**走开了**、**注意力在别处**的那一刻。一个需要你主动启动的保护，在最需要它的时候通常不会被启动。

WC PeekGuard 的触发条件就是"你不管了"。它不跟你抢操作，它接的正是你松手之后那段时间。

一句话：**一个是远程接力，一个是就地遮挡。** 官方那个让你在手机上继续干活，我们这个让你安心把电脑留在原地。

## 装它

两种方式，挑一种。**都不需要懂编程。**

### 方式一：一行命令（推荐，约 1 分钟）

整个操作就三步：开一个窗口、粘一行字、按回车。

1. 按 `⌘空格`，输入 `Terminal`，回车。跳出来的那个窗口叫「终端」，不用怕它。
2. 复制下面这一整行（要完整，不能换行）：

```bash
curl -fsSL https://raw.githubusercontent.com/syz-123/wc-peekguard/main/install.sh | bash
```

3. 回到终端，`⌘V` 粘进去，回车。几秒钟后看到 `Installed: ...`，菜单栏右上角出现 🙈，就成了。

不需要 sudo、不需要密码、不需要装 Xcode，装完自动启动。

它做的事就四件：**下载 → 解压 → 放进 `~/Applications` → 去掉 macOS 的隔离标记 → 打开。** 不放心可以先读 [install.sh](install.sh)，约 180 行，没有别的动作。

### 方式二：下载安装包（不想碰终端就走这条）

1. 到 [Releases](https://github.com/syz-123/wc-peekguard/releases/latest) 下载 `WCPeekGuard.zip`
2. 双击解压，把 `WC PeekGuard.app` 拖进「应用程序」
3. **右键点它 → 打开**（第一次必须右键，双击一定会被拦住）

> **为什么会被拦**：这个 App 没有 Apple 的付费签名，macOS 对从网上下载的这类应用默认拒绝，会提示"无法验证开发者"。**这是正常的，不是病毒。** 右键打开一次之后，系统就记住了。

右键之后仍然打不开：系统设置 → 隐私与安全性 → 往下滚 → 点「仍要打开」。

### 装不上？

| 你看到的 | 怎么办 |
| --- | --- |
| 终端卡住不动超过 1 分钟 | 连不上 GitHub，按 `Control + C` 停掉，改用方式二 |
| `curl: (55)` / `curl: (56)` 下载失败 | 浏览器的代理常和终端不一致。用浏览器下载 zip，再走下面的"离线安装" |
| 提示 `command not found` | 复制时漏了字符，重新整行复制 |
| 双击提示"已损坏" | 下载不完整，删掉重新下载 |
| 右键菜单里「打开」是灰的 | 公司电脑的安全策略，这台机器装不了 |

### 离线安装（网络连不上 Release 时用这条）

浏览器能打开 GitHub、但终端下载失败——这在"代理只走规则模式"时非常常见，因为安装包和脚本走的域名和网页不是同一个。

1. 在浏览器打开 [Releases](https://github.com/syz-123/wc-peekguard/releases/latest)
2. 从这个页面**同时下载两个文件**：`WCPeekGuard.zip` 和 `install.sh`
3. 打开终端，跑这一行：

```bash
bash ~/Downloads/install.sh --from ~/Downloads/WCPeekGuard.zip
```

如果 Safari 已经自动把 zip 解开了，直接指向那个 `.app` 也可以：

```bash
bash ~/Downloads/install.sh --from ~/Downloads/"WC PeekGuard.app"
```

它做的事和一行命令完全相同：验签、装进 `~/Applications`、去掉隔离标记、自动启动。因为你没走浏览器双击，也就完全绕开了 Gatekeeper 的拦截提示。

> 如果连 Releases 页面都打不开，那就只剩"浏览器下载 + 右键打开"这一条路了，见上面的方式二。

### 完全没用过终端？

有一份写得非常细的说明，每一步都写到了该点什么：[新手安装与使用指南](docs/getting-started.md)——包括**怎么确认它真的在工作**的 5 个小测试。

## 它怎么工作

| 你做的事 | 它的反应 |
| --- | --- |
| 打开 App | 菜单栏出现 🙈，绿色泡泡照常用，什么都不变 |
| 手离开键盘鼠标 15 秒 | 窗口被盖成一张 🙈 封面 |
| 你切到别的 App | 绿色泡泡的窗口被**一起收起**，不会留一块奶色板子孤零零飘在别人屏幕上 |
| 你回到绿色泡泡 | 封面还在，同时自动弹出 Touch ID |
| 指纹通过 | 封面撤掉，窗口原样回来，焦点还在原地 |
| 指纹失败 / 取消 | 封面留着，但**不会每隔几秒再骚扰你一次** |

三个实现上的选择，决定了它用起来"不硌人"：

**1. 覆盖，而不是注入。** 它用一层不透明的面板精确贴在你的窗口上，尺寸跟着窗口走。绿色泡泡的进程完全不知道它的存在——不修改、不 hook、不读它的任何数据。这也是它能做到零权限的根本原因。

**2. 非激活面板。** 盖上封面的时候，绿色泡泡**仍然是前台应用**，键盘焦点也没被抢走。你按指纹，不会看到窗口闪一下、Dock 图标跳一下。

**3. 系统原生 Touch ID。** 指纹控件是 macOS 自己的，指纹在 Secure Enclave 里比对，App 只拿到一个"成功 / 失败"的布尔值。它看不到你的指纹，也无法伪造。

## 隐私账本：它到底要什么权限

一个用来保护隐私的工具，最不该做的就是顺手把隐私拿走。

| 它**不**要的 | 说明 |
| --- | --- |
| ❌ 屏幕录制 | 完全不截屏，只取窗口的位置、大小、编号 |
| ❌ 辅助功能 / 输入监控 | 不读键码、不读剪贴板、不读窗口内容 |
| ❌ 网络访问 | 二进制里没有任何联网代码，活动监视器里可自行验证 |
| ❌ 聊天内容 | 它连"窗口里有什么"都不知道 |
| ❌ 账号、登录、任何配置 | 不写任何偏好文件，删掉即干净 |

它**只读**三样东西，全部只在本机内存里用一下：

1. 当前前台 App 的 bundle id（判断"现在是不是它"）
2. 系统最后一次键盘/鼠标事件的时间戳（判断"你 15 秒没动了"——只有时间，没有内容）
3. 窗口的位置和大小（用来把封面贴准）

判断逻辑全是纯函数，可以用 `--self-test` 自己跑一遍验证。

## 它做不到什么

诚实比营销重要：

- **不防通知。** 系统通知横幅、通知中心里的消息预览，它管不着——那是弹在封面之外的东西。
- **不防截屏 / 录屏 / 投屏 / 远程控制。** 屏幕另一头看到的就是你屏幕上的一切。
- **可以被强杀绕过。** 它是个普通进程，`killall` 一下就没了。所以它防的是"随手一眼"，不是"有备而来"。
- **不加密本地数据。** 聊天记录在磁盘上是什么样，还是什么样。
- **只认绿色泡泡。** 别的 App 它不管，也不想管。
- **平台有限。** macOS 14 及以上；Windows 和手机端没有。

## FAQ

**它会不会害我被封号？**
它不注入、不修改、不模拟任何操作、不发任何网络请求，只是在你自己的桌面上画一层窗口。从应用的角度，它不存在。不过我不是官方，无法给出绝对保证——这一点请你自己权衡。

**那和手机解锁到底差在哪？**
见上面[那一节](#它不是手机远程解锁)。一句话：那个需要你记得去按，这个在你忘记的时候生效。

**能改成 10 秒 / 30 秒吗？**
目前写死 15 秒。克隆下来改 [`Sources/WCPeekGuard.swift:18`](Sources/WCPeekGuard.swift#L18) 里的 `>= 15`，再跑 `./build.sh`。做配置界面会引入偏好存储，暂时不想为这个破坏"删掉即干净"的性质。

**会不会很占资源？**
每 0.15 秒查一次窗口列表，不截屏、不轮询像素。实测常驻内存约 13 MB（`footprint` 读数）。

**以后怎么升级？**
把安装命令再跑一遍就行，会覆盖旧版本（先自动退出正在运行的那个）。不用先卸载。

**电脑上没装绿色泡泡会怎样？**
菜单栏照样有 🙈，但它什么都不会做——它只对那一个应用生效。装上之后不用做任何设置。

**重启之后还要手动打开吗？**
要。它没有注册开机自启（故意的，避免在你不知情时常驻）。想让它开机就在，把它加到「系统设置 → 通用 → 登录项」。

**怎么彻底关掉？**

```bash
killall WCPeekGuard
rm -rf ~/Applications/"WC PeekGuard.app"
```

第一行如果提示 `No matching process`，说明它本来就没在运行，直接跑第二行就行，不是出错。

它不写任何配置文件，删掉就是干净删掉。

## 从源码构建

```bash
git clone https://github.com/syz-123/wc-peekguard.git
cd wc-peekguard
./build.sh            # 1.1.0 (build 11)
./build.sh 1.2.0 12   # 自定义版本号 / 构建号
```

产物在 `dist/`。脚本会编译 arm64 与 x86_64 两个切片、`lipo` 合并成通用二进制、ad-hoc 签名、跑一遍 `--self-test`。

自测覆盖：15 秒超时规则、前台/后台/认证中的覆盖策略、每次访问只自动弹一次指纹（取消后不会无限弹）。

## 许可证与声明

[MIT](LICENSE)。随便用、随便改、随便分发。

**关于名字**：项目名和代码里都不含任何官方商标。"绿色泡泡"是中文用户对那个绿色图标聊天软件的俗称，本文用它，只是为了不用注册商标也能让你一眼知道说的是谁。

本项目与腾讯公司没有任何关系，不是官方产品，也未获其授权。它只在本机运行，不连接任何服务器。

---

<div align="center">

如果它帮你避免了一次"我刚才在干嘛"的尴尬，给个 ⭐ 就好。

</div>
