#!/usr/bin/env bash
# Claude Code 通知脚本
# 通过 Claude Code 的 Stop / Notification hook 调用
# 用法: notify.sh stop | notify.sh notification

set -u

EVENT="${1:-stop}"

# 读取 hook 传入的 JSON payload(若有)
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat || true)
fi

# 用户可通过环境变量覆盖默认音效
SOUND_STOP="${CLAUDE_NOTIFY_SOUND_STOP:-Glass}"
SOUND_NOTIFY="${CLAUDE_NOTIFY_SOUND_NOTIFY:-Ping}"

TITLE="Claude Code"

case "$EVENT" in
    stop)
        SUBTITLE="任务已完成"
        MESSAGE="Claude 已写完,等你确认下一步"
        SOUND="$SOUND_STOP"
        ;;
    notification)
        SUBTITLE="需要你的确认"
        MESSAGE="Claude 正在等待你的输入"
        # 尝试从 payload 中解析 message 字段,显示更具体的提示
        if [ -n "$PAYLOAD" ]; then
            PARSED=$(/usr/bin/python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    msg = d.get('message') or ''
    print(msg)
except Exception:
    pass
" <<< "$PAYLOAD" 2>/dev/null || true)
            if [ -n "$PARSED" ]; then
                MESSAGE="$PARSED"
            fi
        fi
        SOUND="$SOUND_NOTIFY"
        ;;
    *)
        SUBTITLE="提示"
        MESSAGE="Claude 有新动态"
        SOUND="$SOUND_STOP"
        ;;
esac

# 转义双引号,避免 osascript 注入问题
escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
TITLE_E=$(escape "$TITLE")
SUBTITLE_E=$(escape "$SUBTITLE")
MESSAGE_E=$(escape "$MESSAGE")
SOUND_E=$(escape "$SOUND")

# 后台播放音效,不阻塞 hook
SOUND_FILE="/System/Library/Sounds/${SOUND}.aiff"
if [ -f "$SOUND_FILE" ]; then
    /usr/bin/afplay "$SOUND_FILE" >/dev/null 2>&1 &
fi

# 弹出系统通知(同时带系统提示音)
/usr/bin/osascript -e "display notification \"${MESSAGE_E}\" with title \"${TITLE_E}\" subtitle \"${SUBTITLE_E}\" sound name \"${SOUND_E}\"" >/dev/null 2>&1 || true

# hook 必须正常退出,否则会阻塞 Claude Code
exit 0
