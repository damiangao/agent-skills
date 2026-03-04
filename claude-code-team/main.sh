#!/bin/bash
# Claude Code Team - Simplified Unified Script
# Usage: main.sh <command> [arguments]
# Commands: invoke, list-sessions, get-session, remove-session, check-env, test-notify, install-hooks, remove-hooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/settings.json"
SESSIONS_FILE="${SCRIPT_DIR}/data/sessions.json"
HOOKS_DIR="${HOME}/.claude/hooks"

# ============ Configuration ============
get_config() {
    local key="$1"
    local env_key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
    local env_val=""
    case "$key" in
        "api_key") env_val="${ANTHROPIC_API_KEY:-}" ;;
        "gateway_token") env_val="${OPENCLAW_GATEWAY_TOKEN:-}" ;;
        "api_base_url") env_val="${ANTHROPIC_BASE_URL:-}" ;;
        "model") env_val="${ANTHROPIC_MODEL:-}" ;;
    esac
    [ -n "$env_val" ] && { echo "$env_val"; return 0; }
    [ -f "$CONFIG_FILE" ] && { local v=$(jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null); [ -n "$v" ] && [ "$v" != "null" ] && { echo "$v"; return 0; }; }
    # Defaults
    case "$key" in
        "api_base_url") echo "https://coding.dashscope.aliyuncs.com/apps/anthropic" ;;
        "model") echo "claude-sonnet-4-6" ;;
        "result_dir") echo "$HOME/.openclaw/data/claude-code-results" ;;
        "notify.channels") echo '["feishu"]' ;;
    esac
}

# ============ Notifications ============
send_feishu() {
    local msg="$1" chat_id=$(get_config "notify.feishu.chat_id")
    [ -z "$chat_id" ] && return 1
    command -v openclaw &>/dev/null && timeout 15 openclaw message send --channel feishu --target "$chat_id" --message "$msg" 2>/dev/null
}

send_discord() {
    local msg="$1" webhook=$(get_config "notify.discord.webhook_url")
    [ -z "$webhook" ] && return 1
    local escaped=$(printf '%s' "$msg" | sed 's/"/\\"/g' | tr '\n' ' ')
    timeout 15 curl -s -X POST "$webhook" -H "Content-Type: application/json" -d "{\"content\":\"$escaped\",\"username\":\"Claude Code Team\"}" 2>/dev/null
}

send_telegram() {
    local msg="$1" token=$(get_config "notify.telegram.bot_token") chat_id=$(get_config "notify.telegram.chat_id")
    [ -z "$token" ] || [ -z "$chat_id" ] && return 1
    local escaped=$(printf '%s' "$msg" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    timeout 15 curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" -H "Content-Type: application/json" -d "{\"chat_id\":\"$chat_id\",\"text\":\"$escaped\",\"parse_mode\":\"HTML\"}" 2>/dev/null
}

send_notification() {
    local msg="$1" channels=$(get_config "notify.channels")
    [ -z "$channels" ] || [ "$channels" = "null" ] && return 1
    for ch in $(echo "$channels" | jq -r '.[]' 2>/dev/null); do
        case "$ch" in
            feishu) send_feishu "$msg" ;;
            discord) send_discord "$msg" ;;
            telegram) send_telegram "$msg" ;;
        esac
    done
}

# ============ Session Management ============
init_sessions_file() {
    mkdir -p "$(dirname "$SESSIONS_FILE")"
    [ ! -f "$SESSIONS_FILE" ] && echo '{}' > "$SESSIONS_FILE"
}

get_session() {
    init_sessions_file
    jq -r --arg dir "$1" '.[$dir] // empty' "$SESSIONS_FILE" 2>/dev/null
}

set_session() {
    init_sessions_file
    local sid="session-$(date +%s)-$$"
    local tmp=$(mktemp)
    jq --arg dir "$1" --arg sid "$sid" '.[$dir] = $sid' "$SESSIONS_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$SESSIONS_FILE" && echo "$sid"
}

# ============ Invoke Task ============
invoke_task() {
    local task="$1" workdir="${2:-$HOME/claude-code-projects}" session_input="${3:-auto}"
    [ -z "$task" ] && { echo "Usage: $0 invoke 'Task' [workdir] [auto|new|session-id]"; return 1; }

    # Validate
    command -v claude &>/dev/null || { echo "Error: claude command not found"; return 1; }
    command -v jq &>/dev/null || { echo "Error: jq not found"; return 1; }
    local api_key=$(get_config "api_key")
    [ -z "$api_key" ] && { echo "Error: ANTHROPIC_API_KEY not set"; return 1; }

    # Session
    local session_id
    if [ "$session_input" = "auto" ]; then
        session_id=$(get_session "$workdir")
        [ -z "$session_id" ] && { session_id=$(set_session "$workdir"); echo "✓ Created session: $session_id"; } || echo "✓ Reusing session: $session_id"
    elif [ "$session_input" = "new" ]; then
        session_id=$(set_session "$workdir")
        echo "✓ Created new session: $session_id"
    else
        session_id="$session_input"
        echo "✓ Using session: $session_id"
    fi

    local result_dir=$(get_config "result_dir")
    mkdir -p "$result_dir"

    # Write meta
    jq -n --arg prompt "$task" --arg sid "$session_id" --arg wd "$workdir" --arg ts "$(date -Iseconds)" \
        '{prompt:$prompt,session_id:$sid,workdir:$wd,started_at:$ts,status:"running"}' > "$result_dir/task-meta.json"

    # Send start notification
    send_notification "🚀 Claude Code Task Started

Task: $task
Session: $session_id
Directory: $workdir" &

    # Run in background
    (
        mkdir -p "$workdir" && cd "$workdir" && \
        ANTHROPIC_BASE_URL=$(get_config "api_base_url") \
        ANTHROPIC_API_KEY="$api_key" \
        ANTHROPIC_MODEL=$(get_config "model") \
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
        stdbuf -oL -eL claude -p "$task" --permission-mode acceptEdits --teammate-mode auto > "$result_dir/task-output.txt" 2>&1
        local exit_code=$?

        # Update meta
        jq -n --arg prompt "$task" --arg sid "$session_id" --arg wd "$workdir" \
            --argjson code "$exit_code" --arg ts "$(date -Iseconds)" \
            '{prompt:$prompt,session_id:$sid,workdir:$wd,exit_code:$code,completed_at:$ts,status:(if $code==0 then "done" else "failed" end)}' \
            > "$result_dir/task-meta.json"

        # Notify completion
        local status=$([ "$exit_code" = "0" ] && echo "Success" || echo "Failed")
        local preview=$(tail -n 20 "$result_dir/task-output.txt" 2>/dev/null | head -n 10 | tr '\n' ' ' | cut -c1-500)
        send_notification "🤖 Claude Code Task $status

📝 Task: $task
🔑 Session: $session_id

📋 Output:
$preview"

        # Hook
        [ -f "$HOOKS_DIR/notify-agi.sh" ] && echo "{\"session_id\":\"$session_id\",\"hook_event_name\":\"Stop\",\"cwd\":\"$workdir\"}" | bash "$HOOKS_DIR/notify-agi.sh" &
    ) &
    echo "✓ Task started (PID: $!)
✓ View output: tail -f $result_dir/task-output.txt"
}

# ============ Hooks ============
install_hooks() {
    mkdir -p "$HOOKS_DIR"
    cat > "$HOOKS_DIR/notify-agi.sh" << 'HOOKEOF'
#!/bin/bash
read -r JSON_DATA
SESSION_ID=$(echo "$JSON_DATA" | jq -r '.session_id // empty')
[[ ! "$SESSION_ID" =~ ^session- ]] && exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh" 2>/dev/null 2>/dev/null || exit 0
RESULT_DIR=$(cd "$SCRIPT_DIR" && jq -r '.result_dir // empty' config/settings.json 2>/dev/null || echo "$HOME/.openclaw/data/claude-code-results")
[ ! -f "$RESULT_DIR/task-meta.json" ] && exit 0
TASK=$(jq -r '.prompt // "Unknown"' "$RESULT_DIR/task-meta.json")
CODE=$(jq -r '.exit_code // -1' "$RESULT_DIR/task-meta.json")
STATUS=$([ "$CODE" = "0" ] && echo "Success" || echo "Failed")
PREVIEW=$(tail -n 20 "$RESULT_DIR/task-output.txt" 2>/dev/null | head -n 10 | tr '\n' ' ' | cut -c1-500)
MSG="🤖 Claude Code Task $STATUS

📝 Task: $TASK
🔑 Session: $SESSION_ID

📋 Output:
$PREVIEW"
# Inline notify
for ch in $(jq -r '.notify.channels[]? // empty' "$SCRIPT_DIR/config/settings.json" 2>/dev/null); do
    case "$ch" in
        feishu) cid=$(jq -r '.notify.feishu.chat_id // empty' "$SCRIPT_DIR/config/settings.json"); [ -n "$cid" ] && openclaw message send --channel feishu --target "$cid" --message "$MSG" 2>/dev/null ;;
        discord) wh=$(jq -r '.notify.discord.webhook_url // empty' "$SCRIPT_DIR/config/settings.json"); [ -n "$wh" ] && curl -s -X POST "$wh" -H "Content-Type: application/json" -d "{\"content\":\"$MSG\"}" 2>/dev/null ;;
    esac
done &
HOOKEOF
    chmod +x "$HOOKS_DIR/notify-agi.sh"

    # Update Claude settings
    mkdir -p "$(dirname "${HOME}/.claude/settings.json")"
    cat > "${HOME}/.claude/settings.json" << EOF
{
  "model": "claude-sonnet-4-6",
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "$HOOKS_DIR/notify-agi.sh", "timeout": 30}]}]
  }
}
EOF
    echo "✓ Hooks installed to $HOOKS_DIR"
}

remove_hooks() {
    [ -f "$HOOKS_DIR/notify-agi.sh" ] && rm -f "$HOOKS_DIR/notify-agi.sh" && echo "✓ Hooks removed" || echo "ℹ Hooks not installed"
}

# ============ Commands ============
case "${1:-help}" in
    invoke)
        shift
        invoke_task "$@"
        ;;
    list-sessions)
        init_sessions_file
        jq '.' "$SESSIONS_FILE"
        ;;
    get-session)
        get_session "$2"
        ;;
    remove-session)
        init_sessions_file
        tmp=$(mktemp)
        jq --arg dir "$2" 'del(.[$dir])' "$SESSIONS_FILE" > "$tmp" && mv "$tmp" "$SESSIONS_FILE" && echo "✓ Removed: $2"
        ;;
    check-env)
        echo "=== Environment Check ==="
        echo -n "claude: "; command -v claude &>/dev/null && echo "✓" || echo "✗"
        echo -n "jq: "; command -v jq &>/dev/null && echo "✓" || echo "✗"
        echo -n "curl: "; command -v curl &>/dev/null && echo "✓" || echo "✗"
        echo -n "ANTHROPIC_API_KEY: "; [ -n "${ANTHROPIC_API_KEY:-}" ] && echo "✓" || echo "✗"
        ;;
    test-notify)
        send_notification "🧪 Test notification from Claude Code Team"
        echo "✓ Test notification sent"
        ;;
    install-hooks)
        install_hooks
        ;;
    remove-hooks)
        remove_hooks
        ;;
    help|--help|-h)
        cat << EOF
Claude Code Team - Simplified Unified Script

Usage: $0 <command> [arguments]

Commands:
  invoke <task> [workdir] [session]  Run a coding task (session: auto|new|<id>)
  list-sessions                      List all sessions
  get-session <workdir>              Get session for directory
  remove-session <workdir>           Remove session mapping
  check-env                          Validate environment
  test-notify                        Send test notification
  install-hooks                      Install notification hooks
  remove-hooks                       Remove notification hooks

Examples:
  $0 invoke "Create a snake game" /path/to/project
  $0 invoke "Fix login bug" /path/to/project new
  $0 list-sessions
  $0 install-hooks
EOF
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
