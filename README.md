# 🔔 Claude Notifier

[English](#english) | [中文](#中文)

> macOS 原生菜单栏 App，在 Claude Code 任务完成或需要确认时弹出系统通知 + 提示音。点击通知自动跳转到对应的 VSCode 窗口。

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128.png" width="128" alt="ClaudeNotifier icon">
</p>

---

## 中文

### ✨ 功能

- 🔔 **自动通知** — Claude Code 任务完成（Stop 事件）/ 需要确认（Notification 事件）时弹系统通知
- 🎵 **自定义音效** — 14 种系统音效可选，也支持自定义音频文件
- 🪟 **点击跳转** — 点通知自动跳到对应项目的 VSCode 窗口
- ⚙️ **图形化设置** — 完整的 macOS 原生设置面板
- 📋 **通知历史** — 菜单栏弹窗内查看最近通知
- 🔇 **一键静音** — 菜单栏图标一键开关

### 📦 安装

```bash
git clone https://github.com/sweet-lemon-n/claude-code-notifier.git
cd claude-code-notifier
make install
```

或者分步操作：

```bash
make build      # 编译
make package    # 打包 .app
make install    # 安装到 /Applications 并配置 hooks
```

安装后 **重启 Claude Code** 生效。

### 🖥️ 系统要求

- macOS 14.0+
- Claude Code
- VSCode（用于点击跳转，可选）

### 🔧 工作原理

```
Claude Code Hook (Stop/Notification)
  → scripts/notify.sh（桥梁脚本）
    → curl POST http://127.0.0.1:<port>/event
      → ClaudeNotifier.app（菜单栏常驻，本地 HTTP 服务）
        → 系统通知 + 音效
        → 点击通知 → VSCodeManager 激活项目窗口
```

### ⚙️ 配置

点击菜单栏图标 → **Settings** 打开设置面板：

| 标签页 | 可配置项 |
|--------|---------|
| **General** | 开机启动、通知预览、音效开关 |
| **Sounds** | Stop/Notification 事件各选不同音效，支持自定义音频文件 |
| **Messages** | 自定义通知标题、副标题和正文模板，支持 `{project}` 和 `{path}` 变量 |
| **About** | 版本信息、GitHub 链接 |

### 🗑️ 卸载

```bash
cd claude-code-notifier
./scripts/uninstall.sh
```

会自动：
- 停止 App 进程
- 从 `/Applications` 删除
- 从 `~/.claude/settings.json` 移除 hooks
- 清理端口文件

### 🛠️ 开发

```bash
# 编译
swift build -c release

# 打包 .app
bash scripts/package-app.sh

# 生成 Xcode 项目（可选）
brew install xcodegen
xcodegen generate --spec project.yml
```

### 📄 开源协议

MIT License

---

## English

### ✨ Features

- 🔔 **Auto-notifications** — System alerts when Claude Code completes a task or needs your confirmation
- 🎵 **Custom sounds** — 14 system sounds or your own audio file
- 🪟 **Click-to-jump** — Click notification → activates the matching VSCode project window
- ⚙️ **GUI settings** — Full native macOS preferences panel
- 📋 **History** — View recent notifications in the menu bar popover
- 🔇 **One-click mute** — Quick toggle from the menu bar

### 📦 Install

```bash
git clone https://github.com/sweet-lemon-n/claude-code-notifier.git
cd claude-code-notifier
make install
```

**Restart Claude Code** after installation.

### 🖥️ Requirements

- macOS 14.0+
- Claude Code
- VSCode (optional, for click-to-jump)

### 🔧 How It Works

Claude Code hooks trigger the bridge script, which POSTs to the app's local HTTP server. The app shows a system notification and plays a sound. Clicking the notification runs `code <project-path>` to activate the matching VSCode window.

### ⚙️ Settings

Click the menu bar icon → **Settings**:

| Tab | Options |
|-----|---------|
| **General** | Launch at login, notification preview, sound toggle |
| **Sounds** | Pick different alert sounds for Stop/Notification events, custom audio files |
| **Messages** | Custom notification title, subtitle, and body templates (`{project}`, `{path}`) |
| **About** | Version, GitHub link |

### 🗑️ Uninstall

```bash
./scripts/uninstall.sh
```

### 📄 License

MIT License
