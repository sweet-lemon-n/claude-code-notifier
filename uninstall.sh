#!/usr/bin/env bash
# Claude Code 通知插件 - 卸载脚本
# 从 ~/.claude/settings.json 中移除 hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SH="$SCRIPT_DIR/notify.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "⚠️  settings.json 不存在,无需卸载"
    exit 0
fi

BACKUP="$SETTINGS_FILE.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS_FILE" "$BACKUP"
echo "📦 已备份: $BACKUP"

/usr/bin/python3 - "$SETTINGS_FILE" "$NOTIFY_SH" <<'PYEOF'
import json, sys

settings_file, notify_sh = sys.argv[1], sys.argv[2]

with open(settings_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

if not isinstance(data, dict):
    print("⚠️  settings.json 格式异常")
    sys.exit(0)

hooks = data.get('hooks', {})
removed = False

for event in ['Stop', 'Notification']:
    if event not in hooks:
        continue
    matchers = hooks[event]
    new_matchers = []
    for m in matchers:
        if not isinstance(m, dict):
            continue
        kept = []
        for h in m.get('hooks', []):
            if isinstance(h, dict) and notify_sh in (h.get('command') or ''):
                removed = True
                continue
            kept.append(h)
        if kept:
            m['hooks'] = kept
            new_matchers.append(m)
    if new_matchers:
        hooks[event] = new_matchers
    else:
        del hooks[event]

if hooks:
    data['hooks'] = hooks
elif 'hooks' in data:
    del data['hooks']

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

if removed:
    print("✅ 已移除 Claude Code 通知 hooks")
else:
    print("⚠️  未找到相关 hooks 配置")
PYEOF

echo ""
echo "卸载完成。重启 Claude Code 后生效。"
