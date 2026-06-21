# Code Notifier

[English](#english) | [中文](#中文)

Native macOS notifications for Claude Code and Codex. Get fast Claude Code confirmation alerts, Claude completion alerts, and Codex completion alerts.

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128.png" width="128" alt="Code Notifier icon">
</p>

---

## 中文

### 功能

- 实时确认提醒：通过 `PermissionRequest` hook 在权限请求出现时通知，而不是等待较慢的 `Notification` 事件。
- 操作详情：确认通知会尽量显示工具名、描述、命令或文件路径，例如 `Bash: Delete 123.txt - rm ...`。
- 完成提醒：通过 `Stop` hook 在任务结束时发送通知，并从 transcript 中提取最近操作和结果摘要。
- Codex 完成提醒：通过 Codex `notify` 配置在 turn ended 时发送通知。
- 可自定义通知类型：可以分别开启或关闭 Claude 确认、Claude 完成、Codex 完成。
- 前台 App + 后台服务：启动后有正常窗口和 Dock 图标；关闭窗口后仍在菜单栏后台运行。
- 不同图标：确认通知和完成通知使用不同的通知附件图标。
- 菜单栏历史：菜单栏弹窗和主窗口都能查看最近通知。
- 音效设置：确认和完成可以使用不同系统音效。

### 安装

```bash
git clone https://github.com/sweet-lemon-n/claude-code-notifier.git
cd claude-code-notifier
make install
```

安装后重启 Claude Code，使 hooks 生效。

### 系统要求

- macOS 14.0+
- Claude Code
- Codex
- Xcode Command Line Tools
- Visual Studio Code 可选，用于点击通知后跳转项目窗口

### 工作原理

```text
Claude Code hooks
  PermissionRequest / Stop / idle Notification
    -> scripts/notify.sh
      -> http://127.0.0.1:<port>/event
        -> CodeNotifier.app
          -> macOS notification + sound + recent history

Codex notify
  turn-ended
    -> scripts/codex-notify.sh
      -> scripts/notify.sh codex_stop
```

安装脚本会写入 `~/.claude/settings.json`，并配置 `~/.codex/config.toml` 的 `notify`：

- `PermissionRequest` -> 实时确认通知
- `Stop` -> 完成通知
- `Notification` with matcher `idle_prompt` -> 空闲等待提醒

### 开发

```bash
swift build -c release
bash scripts/package-app.sh
make install
```

### 卸载

```bash
./scripts/uninstall.sh
```

卸载会停止 App、删除 `/Applications/CodeNotifier.app`、移除 Claude Code hooks，并尽量恢复 Codex 原来的 `notify` 配置。

### 说明

Claude Code 目前没有公开的外部 API 允许 macOS 通知按钮直接批准或拒绝一次权限请求。本 App 的确认按钮会把你带回项目窗口完成确认。

### License

MIT

---

## English

### Features

- Fast permission alerts via Claude Code's `PermissionRequest` hook.
- Action details in confirmation notifications, such as tool name, command, description, or file path.
- Completion alerts via the `Stop` hook, with recent action and result summaries extracted from the transcript when available.
- Codex completion alerts via Codex `notify` on turn ended.
- Per-type notification toggles for Claude confirmations, Claude completions, and Codex completions.
- Foreground macOS app plus background menu-bar service. Closing the main window keeps the notifier running.
- Separate confirmation and completion notification artwork.
- Recent notification history in the menu-bar popover and main window.
- Configurable sounds for confirmations and completions.

### Install

```bash
git clone https://github.com/sweet-lemon-n/claude-code-notifier.git
cd claude-code-notifier
make install
```

Restart Claude Code after installation so hooks are reloaded.

### Requirements

- macOS 14.0+
- Claude Code
- Codex
- Xcode Command Line Tools
- Visual Studio Code optional, for click-to-open-project behavior

### How It Works

```text
Claude Code hooks
  PermissionRequest / Stop / idle Notification
    -> scripts/notify.sh
      -> http://127.0.0.1:<port>/event
        -> CodeNotifier.app
          -> macOS notification + sound + recent history

Codex notify
  turn-ended
    -> scripts/codex-notify.sh
      -> scripts/notify.sh codex_stop
```

The installer updates `~/.claude/settings.json` and configures Codex `notify` in `~/.codex/config.toml`.

- `PermissionRequest` for fast confirmation alerts
- `Stop` for completion alerts
- `Notification` with matcher `idle_prompt` for idle waiting alerts

### Development

```bash
swift build -c release
bash scripts/package-app.sh
make install
```

### Uninstall

```bash
./scripts/uninstall.sh
```

### Note

Claude Code does not currently expose a public external API for a macOS notification action button to approve or reject a pending permission request. The confirmation action opens the project so you can respond in Claude Code.

### License

MIT
