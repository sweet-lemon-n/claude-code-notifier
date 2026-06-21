#!/usr/bin/env bash
# Claude Notifier bridge script
# Called by Claude Code hooks (Stop / Notification).
# Forwards event data to the running ClaudeNotifier.app via local HTTP.
# Falls back to osascript if the app is not running.
set -u

EVENT="${1:-stop}"
PORT_FILE="$HOME/.claude/claude-notifier-port"
LOG_FILE="$HOME/.claude/claude-notifier-latency.log"
CURL_CONNECT_TIMEOUT="0.1"
CURL_MAX_TIME="0.35"

# ---- read hook JSON from stdin ------------------------------------------------
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat 2>/dev/null || true)
fi

# ---- build outbound JSON safely ---------------------------------------------
SEND_JSON=$(CLAUDE_NOTIFIER_PAYLOAD="$PAYLOAD" /usr/bin/python3 - "$EVENT" "${PWD:-}" <<'PYEOF' 2>/dev/null || true
import json, os, sys, time

event, fallback_cwd = sys.argv[1], sys.argv[2]
raw = os.environ.get("CLAUDE_NOTIFIER_PAYLOAD", "")
try:
    out = json.loads(raw) if raw.strip() else {}
    if not isinstance(out, dict):
        out = {}
except Exception:
    out = {}

def clean(value, limit=180):
    if value is None:
        return ""
    text = " ".join(str(value).replace("\r", "\n").split())
    return text if len(text) <= limit else text[:limit] + "..."

def first_dict(*values):
    for value in values:
        if isinstance(value, dict):
            return value
    return {}

def nested(data, *keys):
    current = data
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current

def describe_question(data):
    tool_obj = first_dict(data.get("tool"), data.get("tool_use"), data.get("toolUse"))
    tool_input = first_dict(
        data.get("tool_input"),
        data.get("toolInput"),
        data.get("input"),
        tool_obj.get("input")
    )
    questions = tool_input.get("questions") or data.get("questions")
    if not isinstance(questions, list) or not questions:
        question = clean(tool_input.get("question") or data.get("question"), 220)
        return f"需要选择: {question}" if question else ""

    first = questions[0] if isinstance(questions[0], dict) else {}
    title = clean(first.get("question") or first.get("header"), 220)
    options = first.get("options")
    labels = []
    if isinstance(options, list):
        for option in options[:3]:
            if isinstance(option, dict):
                label = clean(option.get("label"), 40)
                if label:
                    labels.append(label)
    suffix = f" 选项: {' / '.join(labels)}" if labels else ""
    count = f" 等 {len(questions)} 个问题" if len(questions) > 1 else ""
    return f"需要选择: {title}{count}{suffix}" if title else ""

def describe_tool(data):
    tool_obj = first_dict(data.get("tool"), data.get("tool_use"), data.get("toolUse"))
    tool_name = (
        data.get("tool_name") or data.get("toolName") or
        tool_obj.get("name") or nested(data, "permission", "tool_name") or
        nested(data, "permission", "toolName") or "Tool"
    )
    tool_input = first_dict(
        data.get("tool_input"),
        data.get("toolInput"),
        data.get("input"),
        tool_obj.get("input"),
        nested(data, "permission", "tool_input"),
        nested(data, "permission", "toolInput"),
        nested(data, "permission", "input")
    )

    description = clean(
        tool_input.get("description") or data.get("description") or data.get("reason")
    )
    command = clean(
        tool_input.get("command") or data.get("command"),
        220
    )
    file_path = clean(
        tool_input.get("file_path") or tool_input.get("filePath") or
        tool_input.get("path") or data.get("file_path") or data.get("path")
    )
    url = clean(tool_input.get("url") or data.get("url"))

    if description and command:
        return f"{tool_name}: {description} — {command}"
    if description:
        return f"{tool_name}: {description}"
    if command:
        return f"{tool_name}: {command}"
    if file_path:
        return f"{tool_name}: {file_path}"
    if url:
        return f"{tool_name}: {url}"
    return clean(tool_name)

source_event = event
if event in ("permission", "permission_request", "pretool", "question"):
    out["event"] = "notification"
else:
    out["event"] = event

out["cwd"] = out.get("cwd") or fallback_cwd
out["notifier_source_event"] = source_event
if source_event == "question":
    action_summary = describe_question(out) or describe_tool(out)
else:
    action_summary = describe_tool(out)
if action_summary and source_event in ("permission", "permission_request", "pretool", "question"):
    out["action_summary"] = action_summary
    out["message"] = action_summary
out["notifier_script_received_at"] = time.time()
print(json.dumps(out, ensure_ascii=False))
PYEOF
)

printf '%s notify.sh received event=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" >> "$LOG_FILE" 2>/dev/null || true
if [ "$EVENT" = "permission" ] || [ "$EVENT" = "permission_request" ] || [ "$EVENT" = "pretool" ] || [ "$EVENT" = "question" ]; then
    printf '%s %s payload=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" "$SEND_JSON" >> "$LOG_FILE" 2>/dev/null || true
fi

# ---- try to reach the running app --------------------------------------------
if [ -f "$PORT_FILE" ]; then
    PORT=$(cat "$PORT_FILE" 2>/dev/null || true)
    if [ -n "$PORT" ]; then
        if [ -n "$SEND_JSON" ]; then
            curl -s -X POST "http://127.0.0.1:${PORT}/event" \
                -H "Content-Type: application/json" \
                -d "$SEND_JSON" \
                --connect-timeout "$CURL_CONNECT_TIMEOUT" \
                --max-time "$CURL_MAX_TIME" >/dev/null 2>&1 && exit 0
        fi
    fi
fi

# ---- fallback: app not running → launch it and retry -------------------------
APP="/Applications/ClaudeNotifier.app"
if [ -d "$APP" ]; then
    open -a "$APP" --hide 2>/dev/null || true
    # Give the app a moment to bind its server
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
        sleep 0.2
        if [ -f "$PORT_FILE" ]; then
            PORT=$(cat "$PORT_FILE" 2>/dev/null || true)
            if [ -n "$PORT" ]; then
                curl -s -X POST "http://127.0.0.1:${PORT}/event" \
                    -H "Content-Type: application/json" \
                    -d "$SEND_JSON" \
                    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
                    --max-time "$CURL_MAX_TIME" >/dev/null 2>&1 && exit 0
            fi
        fi
    done
fi

# If we still can't reach the app, play only a sound as last resort
/usr/bin/afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &

exit 0
