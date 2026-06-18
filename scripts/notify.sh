#!/usr/bin/env bash
# Claude Notifier bridge script
# Called by Claude Code hooks (Stop / Notification).
# Forwards event data to the running ClaudeNotifier.app via local HTTP.
# Falls back to osascript if the app is not running.
set -u

EVENT="${1:-stop}"
PORT_FILE="$HOME/.claude/claude-notifier-port"

# ---- read hook JSON from stdin ------------------------------------------------
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat 2>/dev/null || true)
fi

# ---- extract cwd -------------------------------------------------------------
CWD=""
if [ -n "$PAYLOAD" ]; then
    CWD=$(/usr/bin/python3 -c "
import sys,json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('cwd',''))
except Exception:
    pass
" <<< "$PAYLOAD" 2>/dev/null || true)
fi
[ -z "$CWD" ] && CWD="${PWD:-}"

# ---- extract message for Notification events ---------------------------------
MSG=""
if [ -n "$PAYLOAD" ] && [ "$EVENT" = "notification" ]; then
    MSG=$(/usr/bin/python3 -c "
import sys,json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('message',''))
except Exception:
    pass
" <<< "$PAYLOAD" 2>/dev/null || true)
fi

# ---- try to reach the running app --------------------------------------------
if [ -f "$PORT_FILE" ]; then
    PORT=$(cat "$PORT_FILE" 2>/dev/null || true)
    if [ -n "$PORT" ]; then
        SEND_JSON=$(/usr/bin/python3 -c "
import json
out = {'event':'$EVENT','cwd':'$CWD'}
if '$MSG': out['message'] = '$MSG'
print(json.dumps(out))
" 2>/dev/null || true)

        if [ -n "$SEND_JSON" ]; then
            curl -s -X POST "http://127.0.0.1:${PORT}/event" \
                -H "Content-Type: application/json" \
                -d "$SEND_JSON" \
                --max-time 2 >/dev/null 2>&1 && exit 0
        fi
    fi
fi

# ---- fallback: app not running → launch it and retry -------------------------
APP="/Applications/ClaudeNotifier.app"
if [ -d "$APP" ]; then
    open -a "$APP" --hide 2>/dev/null || true
    # Give the app a moment to bind its server
    for i in 1 2 3 4 5; do
        sleep 0.5
        if [ -f "$PORT_FILE" ]; then
            PORT=$(cat "$PORT_FILE" 2>/dev/null || true)
            if [ -n "$PORT" ]; then
                curl -s -X POST "http://127.0.0.1:${PORT}/event" \
                    -H "Content-Type: application/json" \
                    -d "$SEND_JSON" \
                    --max-time 2 >/dev/null 2>&1 && exit 0
            fi
        fi
    done
fi

# If we still can't reach the app, play only a sound as last resort
/usr/bin/afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &

exit 0
