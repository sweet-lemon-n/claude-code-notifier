# Claude Code 通知插件 / Claude Code Notifier

[English](#english) | [中文](#中文)

---

## 中文

### 问题
使用 Claude Code 编程时，Claude 在后台运行，你切到别的窗口干活，经常忘记回来看。等你想起来时，Claude 早就写完了代码在那等你确认。

### 解决方案
这个插件通过 Claude Code 的 **Hooks 机制**，在以下时机自动弹出 macOS 系统通知 + 提示音：
- **任务完成**：Claude 写完代码，等待你的下一步指令
- **需要确认**：Claude 需要你输入、选择或批准某个操作

### 特性
- ✅ **零依赖**：纯 Bash 脚本 + macOS 自带工具（`osascript` / `afplay`）
- ✅ **即装即用**：一行命令安装，自动写入 `~/.claude/settings.json`
- ✅ **自定义音效**：通过环境变量修改提示音
- ✅ **安全卸载**：自动备份配置，支持一键卸载

### 安装

```bash
git clone https://github.com/你的用户名/claude-code-notifier.git
cd claude-code-notifier
chmod +x install.sh
./install.sh
```

**重启 Claude Code** 后生效。

### 使用

装好后无需任何操作，Claude Code 会自动在合适的时机触发通知：

| 场景 | 提示音 | 通知内容 |
|------|--------|----------|
| 任务完成 | Glass | "Claude 已写完，等你确认下一步" |
| 需要确认 | Ping | "Claude 正在等待你的输入" |

### 自定义音效

通过环境变量覆盖默认音效（需要在启动 Claude Code 前设置）：

```bash
export CLAUDE_NOTIFY_SOUND_STOP="Blow"      # 任务完成音效
export CLAUDE_NOTIFY_SOUND_NOTIFY="Hero"   # 需要确认音效
```

可用音效列表（位于 `/System/Library/Sounds/`）：
- Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

### 卸载

```bash
./uninstall.sh
```

会自动备份 `settings.json` 并移除 hooks 配置。

### 原理

插件在 `~/.claude/settings.json` 中注册了两个 hooks：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"/path/to/notify.sh\" stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"/path/to/notify.sh\" notification"
          }
        ]
      }
    ]
  }
}
```

当 Claude Code 触发这些事件时，会调用 `notify.sh` 脚本弹出系统通知。

### 系统要求
- macOS 10.14+
- Claude Code (任意版本)
- 确保在 **系统设置 → 通知** 中允许 **脚本编辑器** 发送通知

### 开源协议
MIT License

---

## English

### Problem
When using Claude Code, Claude runs in the background while you switch to other windows. You often forget to check back, only to find Claude finished the code long ago and is waiting for your confirmation.

### Solution
This plugin uses Claude Code's **Hooks mechanism** to automatically trigger macOS system notifications with sound alerts when:
- **Task completed**: Claude finished writing code and awaits your next instruction
- **Confirmation needed**: Claude requires your input, selection, or approval

### Features
- ✅ **Zero dependencies**: Pure Bash script + macOS built-in tools (`osascript` / `afplay`)
- ✅ **Install & go**: One-line installation, auto-configures `~/.claude/settings.json`
- ✅ **Custom sounds**: Override default sounds via environment variables
- ✅ **Safe uninstall**: Auto-backup config, one-click removal

### Installation

```bash
git clone https://github.com/your-username/claude-code-notifier.git
cd claude-code-notifier
chmod +x install.sh
./install.sh
```

**Restart Claude Code** to activate.

### Usage

No manual action required after installation. Claude Code will automatically trigger notifications at appropriate moments:

| Scenario | Sound | Notification Message |
|----------|-------|---------------------|
| Task completed | Glass | "Claude 已写完，等你确认下一步" |
| Confirmation needed | Ping | "Claude 正在等待你的输入" |

### Custom Sounds

Override default sounds via environment variables (set before launching Claude Code):

```bash
export CLAUDE_NOTIFY_SOUND_STOP="Blow"      # Task completion sound
export CLAUDE_NOTIFY_SOUND_NOTIFY="Hero"   # Confirmation needed sound
```

Available sounds (located in `/System/Library/Sounds/`):
- Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

### Uninstall

```bash
./uninstall.sh
```

Automatically backs up `settings.json` and removes hooks configuration.

### How It Works

The plugin registers two hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"/path/to/notify.sh\" stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"/path/to/notify.sh\" notification"
          }
        ]
      }
    ]
  }
}
```

When Claude Code triggers these events, it invokes the `notify.sh` script to display system notifications.

### System Requirements
- macOS 10.14+
- Claude Code (any version)
- Ensure **Script Editor** is allowed to send notifications in **System Settings → Notifications**

### License
MIT License
