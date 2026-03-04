#!/bin/bash
# Claude Code Team - Environment Validation Module
# Validate that the runtime environment meets requirements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}"

# Load configuration module
source "${LIB_DIR}/config.sh" 2>/dev/null || {
    echo "Error: Cannot load configuration module" >&2
    exit 1
}

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

check() {
    echo -e "${BLUE}•${NC} $1"
}

# ============ Check Command ============
check_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if command -v "$cmd" &> /dev/null; then
        info "$cmd is installed"
        return 0
    else
        error "$cmd is not installed"
        if [ -n "$install_hint" ]; then
            echo "  Installation hint: $install_hint"
        fi
        return 1
    fi
}

# ============ Check Environment Variable ============
check_env_var() {
    local var_name="$1"
    local required="${2:-true}"
    local value=""

    eval value=\"\$$var_name\"

    if [ -n "$value" ]; then
        info "$var_name is set"
        return 0
    else
        if [ "$required" = "true" ]; then
            error "$var_name is not set (required)"
            return 1
        else
            warn "$var_name is not set (optional)"
            return 0
        fi
    fi
}

# ============ Check Configuration File ============
check_config() {
    local config_file="${SCRIPT_DIR}/../config/settings.json"

    if [ -f "$config_file" ]; then
        info "Configuration file exists"
        if jq empty "$config_file" 2>/dev/null; then
            info "Configuration file format is valid (JSON)"
            return 0
        else
            error "Configuration file format is invalid (not valid JSON)"
            return 1
        fi
    else
        warn "Configuration file does not exist, will use default values"
        return 0
    fi
}

# ============ Check Notification Channels ============
check_notify_channels() {
    local channels=$(get_config "notify.channels")

    check "Notification channel configuration"
    echo "  Configured channels: $channels"

    local has_error=0

    # Handle empty or null channels
    if [ -z "$channels" ] || [ "$channels" = "null" ]; then
        warn "No notification channels configured"
        return 0
    fi

    # Validate JSON array
    if ! echo "$channels" | jq empty 2>/dev/null; then
        error "Invalid channels configuration (not a valid JSON array)"
        return 1
    fi

    for channel in $(echo "$channels" | jq -r '.[]' 2>/dev/null); do
        case "$channel" in
            feishu)
                local chat_id=$(get_config "notify.feishu.chat_id")
                if [ -z "$chat_id" ]; then
                    error "Feishu: chat_id is not configured"
                    has_error=1
                else
                    info "Feishu: chat_id is configured"
                fi
                ;;
            discord)
                local webhook=$(get_config "notify.discord.webhook_url")
                if [ -z "$webhook" ]; then
                    error "Discord: webhook_url is not configured"
                    has_error=1
                else
                    info "Discord: webhook_url is configured"
                fi
                ;;
            telegram)
                local bot_token=$(get_config "notify.telegram.bot_token")
                local tg_chat_id=$(get_config "notify.telegram.chat_id")
                if [ -z "$bot_token" ] || [ -z "$tg_chat_id" ]; then
                    error "Telegram: bot_token or chat_id is not configured"
                    has_error=1
                else
                    info "Telegram: configuration is complete"
                fi
                ;;
            *)
                warn "Unknown notification channel: $channel"
                ;;
        esac
    done

    return $has_error
}

# ============ Check Directory Permissions ============
check_directories() {
    local result_dir=$(get_config "result_dir")
    local has_error=0

    check "Directory permission check"

    # Check result directory
    if [ -d "$result_dir" ]; then
        if [ -w "$result_dir" ]; then
            info "Result directory is writable: $result_dir"
        else
            error "Result directory is not writable: $result_dir"
            has_error=1
        fi
    else
        if mkdir -p "$result_dir" 2>/dev/null; then
            info "Created result directory: $result_dir"
        else
            error "Cannot create result directory: $result_dir"
            has_error=1
        fi
    fi

    # Check hooks directory
    local hooks_dir="${HOME}/.claude/hooks"
    if [ -d "$hooks_dir" ]; then
        info "Hooks directory exists: $hooks_dir"
    else
        warn "Hooks directory does not exist (optional, for notifications)"
    fi

    return $has_error
}

# ============ Full Environment Check ============
full_check() {
    local has_error=0

    echo "========================================"
    echo "  Claude Code Team - Environment Check"
    echo "========================================"
    echo ""

    echo "--- Dependency Check ---"
    check_command "claude" "npm install -g @anthropic-ai/claude-cli" || has_error=1
    check_command "jq" "apt-get install jq / brew install jq" || has_error=1
    check_command "curl" "apt-get install curl" || has_error=1
    echo ""

    echo "--- Environment Variable Check ---"
    check_env_var "ANTHROPIC_API_KEY" "true" || has_error=1
    check_env_var "OPENCLAW_GATEWAY_TOKEN" "false"
    echo ""

    echo "--- Configuration File Check ---"
    check_config || has_error=1
    echo ""

    echo "--- Notification Channel Check ---"
    check_notify_channels || has_error=1
    echo ""

    echo "--- Directory Permission Check ---"
    check_directories || has_error=1
    echo ""

    echo "========================================"
    if [ $has_error -eq 0 ]; then
        echo -e "  ${GREEN}✓ Environment check passed${NC}"
        echo "========================================"
        return 0
    else
        echo -e "  ${RED}✗ Environment check failed${NC}"
        echo "========================================"
        return 1
    fi
}

# ============ Main Program ============
case "${1:-check}" in
    check)
        full_check
        ;;
    command)
        check_command "$2" "$3"
        ;;
    env)
        check_env_var "$2" "${3:-true}"
        ;;
    config)
        check_config
        ;;
    notify)
        check_notify_channels
        ;;
    dirs)
        check_directories
        ;;
    *)
        echo "Usage: $0 {check|command|env|config|notify|dirs}"
        echo ""
        echo "Commands:"
        echo "  check              Full environment check (default)"
        echo "  command <cmd>      Check for specified command"
        echo "  env <var>          Check specified environment variable"
        echo "  config             Check configuration file"
        echo "  notify             Check notification channel configuration"
        echo "  dirs               Check directory permissions"
        ;;
esac
