#!/bin/bash
# Claude Code Team - Hook Installation Script
# Install/uninstall notification hooks to Claude Code hooks directory

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CCT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${HOME}/.claude/hooks"
NOTIFY_HOOK="${HOOKS_DIR}/notify-agi.sh"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# ============ Create Hook Script ============
create_hook() {
    mkdir -p "$HOOKS_DIR"

    cat > "$NOTIFY_HOOK" << HOOKEOF
#!/bin/bash
# Claude Code Team - Notification Hook
# Triggered by Claude Code Agent Teams

HOOKS_DIR="\${HOME}/.claude/hooks"
CCT_DIR="${CCT_DIR}"
LIB_DIR="\${CCT_DIR}/lib"

# Parse incoming JSON data
read -r JSON_DATA

# Extract fields
SESSION_ID=\$(echo "\$JSON_DATA" | jq -r '.session_id // empty')
EVENT_NAME=\$(echo "\$JSON_DATA" | jq -r '.hook_event_name // empty')
CWD=\$(echo "\$JSON_DATA" | jq -r '.cwd // empty')

# Check if this is an Agent Teams task
if [ -z "\$SESSION_ID" ] || [[ ! "\$SESSION_ID" =~ ^session- ]]; then
    exit 0
fi

# Load configuration and notification modules
source "\${LIB_DIR}/config.sh" 2>/dev/null
source "\${LIB_DIR}/notify.sh" 2>/dev/null

# Export configuration
export_config

# Read task metadata
RESULT_DIR="\${CCT_RESULT_DIR:-/root/.openclaw/data/claude-code-results}"
META_FILE="\${RESULT_DIR}/task-meta.json"
OUTPUT_FILE="\${RESULT_DIR}/task-output.txt"

if [ ! -f "\$META_FILE" ]; then
    exit 0
fi

TASK_PROMPT=\$(jq -r '.prompt // "Unknown task"' "\$META_FILE" 2>/dev/null)
EXIT_CODE=\$(jq -r '.exit_code // -1' "\$META_FILE" 2>/dev/null)

# Determine status
if [ "\$EXIT_CODE" = "0" ]; then
    STATUS="Success"
else
    STATUS="Failed"
fi

# Generate summary
OUTPUT_PREVIEW=""
if [ -f "\$OUTPUT_FILE" ] && [ -s "\$OUTPUT_FILE" ]; then
    OUTPUT_PREVIEW=\$(tail -n 50 "\$OUTPUT_FILE" | head -n 20 | sed 's/"/\\"/g' | tr '\n' ' ')
    if [ \${#OUTPUT_PREVIEW} -gt 800 ]; then
        OUTPUT_PREVIEW="\${OUTPUT_PREVIEW:0:800}..."
    fi
fi

# Build notification message
MSG="🤖 Claude Code Task Completed

\${STATUS}

📝 Task: \${TASK_PROMPT}
🔑 Session: \${SESSION_ID}
📁 Directory: \${CWD}

📋 Output Summary:
\`\`\`
\${OUTPUT_PREVIEW}
\`\`\`

⏰ \$(date '+%Y-%m-%d %H:%M:%S')"

# Send notification to all configured channels
send_notification "\$MSG"

# Write wake marker
if [ -n "\${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
    cat > "\${RESULT_DIR}/pending-wake.json" << WAKEEOF
{
  "session_id": "\${SESSION_ID}",
  "timestamp": "\$(date -Iseconds)",
  "event": "task_completed",
  "status": "\${STATUS}"
}
WAKEEOF
    # Trigger gateway wake (with timeout)
    curl -s -X POST "https://gateway.openclaw.local/wake" \\
        -H "Authorization: Bearer \${OPENCLAW_GATEWAY_TOKEN}" \\
        -H "Content-Type: application/json" \\
        -d "{\"session_id\":\"\${SESSION_ID}\"}" --max-time 10 > /dev/null 2>&1 || true
fi
HOOKEOF

    chmod +x "$NOTIFY_HOOK"
    info "Created notification hook: $NOTIFY_HOOK"
}

# ============ Uninstall Hook ============
remove_hook() {
    if [ -f "$NOTIFY_HOOK" ]; then
        rm -f "$NOTIFY_HOOK"
        info "Removed notification hook"
    else
        warn "Hook does not exist: $NOTIFY_HOOK"
    fi
}

# ============ Check Hook Status ============
check_status() {
    echo "=== Hook Status Check ==="
    echo ""

    if [ -f "$NOTIFY_HOOK" ]; then
        info "Notification hook is installed"
        echo "  Path: $NOTIFY_HOOK"
        if [ -x "$NOTIFY_HOOK" ]; then
            info "Execute permission: Set"
        else
            warn "Execute permission: Not set"
        fi
    else
        warn "Notification hook is not installed"
    fi

    echo ""
    echo "=== Claude Code Hooks Directory ==="
    echo "  Path: $HOOKS_DIR"

    if [ -d "$HOOKS_DIR" ]; then
        info "Directory exists"
        echo ""
        echo "Installed Hooks:"
        ls -la "$HOOKS_DIR"/*.sh 2>/dev/null || echo "  (none)"
    else
        warn "Directory does not exist"
    fi
}

# ============ Update Claude Settings ============
update_claude_settings() {
    local claude_settings="${HOME}/.claude/settings.json"
    local claude_dir="${HOME}/.claude"

    mkdir -p "$claude_dir"

    # Check if settings.json exists and merge settings
    if [ -f "$claude_settings" ]; then
        # Backup existing settings
        cp "$claude_settings" "${claude_settings}.bak"

        # Update hooks configuration using jq
        local tmp_file=$(mktemp)
        jq '.hooks.Stop = [
            {
                "hooks": [
                    {
                        "type": "command",
                        "command": "'"${NOTIFY_HOOK}"'",
                        "timeout": 30
                    }
                ]
            }
        ]' "$claude_settings" > "$tmp_file" 2>/dev/null

        if [ $? -eq 0 ]; then
            mv "$tmp_file" "$claude_settings"
        else
            rm -f "$tmp_file"
            # Fallback: create new settings
            cat > "$claude_settings" << SETTINGSEOF
{
  "model": "claude-sonnet-4-6",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${NOTIFY_HOOK}",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionEnd": []
  }
}
SETTINGSEOF
        fi
    else
        # Create new settings file
        cat > "$claude_settings" << SETTINGSEOF
{
  "model": "claude-sonnet-4-6",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${NOTIFY_HOOK}",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionEnd": []
  }
}
SETTINGSEOF
    fi

    info "Updated Claude settings: $claude_settings"
}

# ============ Main Program ============
case "${1:-install}" in
    install)
        echo "=== Installing Claude Code Team Hooks ==="
        echo ""

        # Check dependencies
        if ! command -v jq &> /dev/null; then
            error "jq is not installed"
            echo "  Install: apt-get install jq OR brew install jq"
            exit 1
        fi

        create_hook
        update_claude_settings

        echo ""
        info "Installation complete!"
        echo ""
        echo "Hook features:"
        echo "  - Send notification when task starts"
        echo "  - Send notification when task completes (with output summary)"
        echo "  - Support multiple notification channels (Feishu/Discord/Telegram)"
        echo "  - Auto trigger gateway wake (if TOKEN is configured)"
        ;;

    remove|uninstall)
        echo "=== Uninstalling Claude Code Team Hooks ==="
        echo ""
        remove_hook
        ;;

    status)
        check_status
        ;;

    *)
        echo "Usage: $0 {install|remove|status}"
        echo ""
        echo "Commands:"
        echo "  install   Install/update hook (default)"
        echo "  remove    Uninstall hook"
        echo "  status    Check hook status"
        ;;
esac
