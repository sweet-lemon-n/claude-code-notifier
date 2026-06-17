#!/usr/bin/env bash
# Claude Code 通知插件 - 一键安装脚本
# 把 Stop / Notification hook 写入 ~/.claude/settings.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SH="$SCRIPT_DIR/notify.sh"
SETTINGS_DIR="$HOME/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# 检查依赖
if [ "$(uname)" != "Darwin" ]; then
    echo "❌ 这个脚本只支持 macOS,当前系统: $(uname)"
    exit 1
fi

if ! command -v osascript >/dev/null 2>&1; then
    echo "❌ 找不到 osascript,无法弹通知"
    exit 1
fi

if [ ! -f "$NOTIFY_SH" ]; then
    echo "❌ 找不到 notify.sh: $NOTIFY_SH"
    exit 1
fi

chmod +x "$NOTIFY_SH"

mkdir -p "$SETTINGS_DIR"

# 备份现有 settings
if [ -f "$SETTINGS_FILE" ]; then
    BACKUP="$SETTINGS_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$BACKUP"
    echo "📦 已备份原 settings.json -> $BACKUP"
else
    echo '{}' > "$SETTINGS_FILE"
fi

# 用 python 安全地合并 hooks 配置
/usr/bin/python3 - "$SETTINGS_FILE" "$NOTIFY_SH" <<'PYEOF'
import json, sys, os

settings_file, notify_sh = sys.argv[1], sys.argv[2]

try:
    with open(settings_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    data = {}

if not isinstance(data, dict):
    data = {}

hooks = data.setdefault('hooks', {})

def upsert(event, arg):
    cmd = f'"{notify_sh}" {arg}'
    matchers = hooks.setdefault(event, [])
    # 移除已有的同名脚本配置,避免重复
    new_matchers = []
    for m in matchers:
        if not isinstance(m, dict):
            continue
        kept = []
        for h in m.get('hooks', []):
            if isinstance(h, dict) and notify_sh in (h.get('command') or ''):
                continue
            kept.append(h)
        if kept:
            m['hooks'] = kept
            new_matchers.append(m)
    new_matchers.append({
        'hooks': [{'type': 'command', 'command': cmd}]
    })
    hooks[event] = new_matchers

upsert('Stop', 'stop')
upsert('Notification', 'notification')

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("✅ 已写入 hooks:", settings_file)
PYEOF

echo ""
echo "🎉 安装完成!"
echo ""
echo "下次启动 Claude Code 时:"
echo "  • 任务结束    → 弹通知 + Glass 音效"
echo "  • 需要你确认  → 弹通知 + Ping 音效"
echo ""
echo "如果系统通知不出现,请在 系统设置 → 通知 中允许『脚本编辑器』发送通知。"
echo "卸载: 运行 ./uninstall.sh"
