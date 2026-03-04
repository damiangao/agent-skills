#!/bin/bash
# Claude Code Team - Notification Module
# Support for multiple notification channels: Feishu / Discord / Telegram

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration module
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || {
    echo "Error: Cannot load configuration module" >&2
    exit 1
}

# Color definitions
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

warn() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# ============ Feishu Notification ============
send_feishu() {
    local message="$1"
    local chat_id=$(get_config "notify.feishu.chat_id")

    if [ -z "$chat_id" ]; then
        error "Feishu chat_id is not configured"
        return 1
    fi

    # Use openclaw CLI to send
    if command -v openclaw &> /dev/null; then
        timeout 15 openclaw message send \
            --channel feishu \
            --target "$chat_id" \
            --message "$message" 2>/dev/null || {
            error "Failed to send Feishu notification"
            return 1
        }
    else
        warn "openclaw command not found, skipping Feishu notification"
        return 1
    fi
}

# ============ Discord Notification ============
send_discord() {
    local message="$1"
    local webhook_url=$(get_config "notify.discord.webhook_url")
    local username=$(get_config "notify.discord.username")

    if [ -z "$webhook_url" ]; then
        error "Discord webhook_url is not configured"
        return 1
    fi

    # Validate webhook URL format
    if [[ ! "$webhook_url" =~ ^https://discord\.com/api/webhooks/ ]]; then
        error "Invalid Discord webhook URL format"
        return 1
    fi

    # Escape special characters for JSON
    local escaped_message
    escaped_message=$(printf '%s' "$message" | python3 -c '
import sys, json
data = sys.stdin.read()
# Escape for JSON string
print(json.dumps(data)[1:-1])
' 2>/dev/null || echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    local payload
    payload="{\"content\": \"${escaped_message}\", \"username\": \"${username:-Claude Code Team}\"}"

    timeout 15 curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 15 \
        2>/dev/null || {
        error "Failed to send Discord notification"
        return 1
    }
}

# ============ Telegram Notification ============
send_telegram() {
    local message="$1"
    local bot_token=$(get_config "notify.telegram.bot_token")
    local chat_id=$(get_config "notify.telegram.chat_id")

    if [ -z "$bot_token" ] || [ -z "$chat_id" ]; then
        error "Telegram bot_token or chat_id is not configured"
        return 1
    fi

    # Validate bot token format (basic check)
    if [[ ! "$bot_token" =~ ^[0-9]+:[A-Za-z0-9_-]+ ]]; then
        error "Invalid Telegram bot token format"
        return 1
    fi

    local api_url="https://api.telegram.org/bot${bot_token}/sendMessage"

    # Escape HTML special characters
    local escaped_message
    escaped_message=$(printf '%s' "$message" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

    local payload
    payload="{\"chat_id\": \"${chat_id}\", \"text\": \"${escaped_message}\", \"parse_mode\": \"HTML\"}"

    timeout 15 curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 15 \
        2>/dev/null || {
        error "Failed to send Telegram notification"
        return 1
    }
}

# ============ Unified Notification Entry ============
send_notification() {
    local message="$1"
    local channels=$(get_config "notify.channels")

    if [ -z "$channels" ] || [ "$channels" = "null" ]; then
        warn "No notification channels configured"
        return 1
    fi

    # Validate channels is a valid JSON array
    if ! echo "$channels" | jq empty 2>/dev/null; then
        error "Invalid notification channels configuration"
        return 1
    fi

    local has_error=0
    local sent_count=0

    for channel in $(echo "$channels" | jq -r '.[]' 2>/dev/null); do
        case "$channel" in
            feishu)
                if send_feishu "$message"; then
                    sent_count=$((sent_count + 1))
                else
                    has_error=1
                fi
                ;;
            discord)
                if send_discord "$message"; then
                    sent_count=$((sent_count + 1))
                else
                    has_error=1
                fi
                ;;
            telegram)
                if send_telegram "$message"; then
                    sent_count=$((sent_count + 1))
                else
                    has_error=1
                fi
                ;;
            *)
                warn "Unknown notification channel: $channel"
                has_error=1
                ;;
        esac
    done

    if [ $sent_count -eq 0 ] && [ $has_error -eq 1 ]; then
        error "Failed to send notification to any channel"
        return 1
    fi

    return $has_error
}

# ============ Test Notification ============
test_notification() {
    local test_msg="🧪 Claude Code Team - Notification Test

This is a test message.

If you receive this, the notification configuration is correct!

Time: $(date '+%Y-%m-%d %H:%M:%S')"

    echo "Testing notification channels..."
    send_notification "$test_msg"

    if [ $? -eq 0 ]; then
        info "Test notification sent successfully"
    else
        error "Failed to send test notification"
    fi
}

# ============ Main Program ============
# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "${1:-send}" in
    send)
        send_notification "$2"
        ;;
    feishu)
        send_feishu "$2"
        ;;
    discord)
        send_discord "$2"
        ;;
    telegram)
        send_telegram "$2"
        ;;
    test)
        test_notification
        ;;
    *)
        echo "Usage: $0 {send|feishu|discord|telegram|test} [message]"
        echo ""
        echo "Commands:"
        echo "  send <msg>      Send to all configured channels"
        echo "  feishu <msg>    Send to Feishu"
        echo "  discord <msg>   Send to Discord"
        echo "  telegram <msg>  Send to Telegram"
        echo "  test            Send test message"
        ;;
esac
fi
