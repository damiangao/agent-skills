#!/bin/bash
# Claude Code Team - Unified Configuration Management Module
# Priority: Environment Variables > Config File > Default Values

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/settings.json"

# ============ Default Values ============
defaults() {
    cat << 'EOF'
{
    "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
    "model": "claude-sonnet-4-6",
    "result_dir": "/root/.openclaw/data/claude-code-results",
    "notify": {
        "channels": ["feishu"],
        "feishu": {
            "chat_id": "user:ou_xxxxxx"
        },
        "discord": {
            "webhook_url": "",
            "username": "Claude Code Team"
        },
        "telegram": {
            "bot_token": "",
            "chat_id": ""
        }
    },
    "agent_teams": {
        "enabled": true,
        "teammate_mode": "auto"
    }
}
EOF
}

# ============ Read Configuration ============
# Output format: KEY=VALUE (one per line)
get_config() {
    local key="$1"

    # 1. First check environment variables
    local env_key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
    local env_val=""

    case "$key" in
        "api_key") env_val="${ANTHROPIC_API_KEY:-}" ;;
        "gateway_token") env_val="${OPENCLAW_GATEWAY_TOKEN:-}" ;;
        "api_base_url") env_val="${ANTHROPIC_BASE_URL:-}" ;;
        "model") env_val="${ANTHROPIC_MODEL:-}" ;;
        *) env_val="${!env_key:-}" ;;
    esac

    if [ -n "$env_val" ]; then
        echo "$env_val"
        return 0
    fi

    # 2. Read configuration file
    if [ -f "$CONFIG_FILE" ]; then
        local config_val=$(jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$config_val" ] && [ "$config_val" != "null" ]; then
            echo "$config_val"
            return 0
        fi
    fi

    # 3. Use default values
    defaults | jq -r ".$key // empty" 2>/dev/null
}

# ============ List All Configuration ============
list_config() {
    echo "=== Current Configuration (Environment > Config File > Default) ==="
    echo ""

    # Read default values as base
    local base_config=$(defaults)

    # Merge configuration file
    if [ -f "$CONFIG_FILE" ]; then
        base_config=$(echo "$base_config" | jq -s '.[0] * .[1]' - "$CONFIG_FILE" 2>/dev/null || echo "$base_config")
    fi

    # Merge environment variables
    local final_config="$base_config"

    [ -n "${ANTHROPIC_API_KEY:-}" ] && final_config=$(echo "$final_config" | jq --arg v "***masked***" '.api_key = $v')
    [ -n "${ANTHROPIC_BASE_URL:-}" ] && final_config=$(echo "$final_config" | jq --arg v "$ANTHROPIC_BASE_URL" '.api_base_url = $v')
    [ -n "${ANTHROPIC_MODEL:-}" ] && final_config=$(echo "$final_config" | jq --arg v "$ANTHROPIC_MODEL" '.model = $v')
    [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ] && final_config=$(echo "$final_config" | jq --arg v "***masked***" '.gateway_token = $v')

    echo "$final_config" | jq .
}

# ============ Export Configuration to Environment Variables ============
export_config() {
    export CCT_API_BASE_URL=$(get_config "api_base_url")
    export CCT_API_KEY=$(get_config "api_key")
    export CCT_MODEL=$(get_config "model")
    export CCT_RESULT_DIR=$(get_config "result_dir")
    export CCT_NOTIFY_CHANNELS=$(get_config "notify.channels")
    export CCT_FEISHU_CHAT_ID=$(get_config "notify.feishu.chat_id")
    export CCT_DISCORD_WEBHOOK=$(get_config "notify.discord.webhook_url")
    export CCT_TELEGRAM_BOT_TOKEN=$(get_config "notify.telegram.bot_token")
    export CCT_TELEGRAM_CHAT_ID=$(get_config "notify.telegram.chat_id")
    export CCT_AGENT_TEAMS_ENABLED=$(get_config "agent_teams.enabled")
    export CCT_TEAMMATE_MODE=$(get_config "agent_teams.teammate_mode")
}

# ============ Initialize Default Configuration File ============
init_config() {
    local config_dir=$(dirname "$CONFIG_FILE")

    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        defaults > "$CONFIG_FILE"
        echo "✅ Created default configuration file: $CONFIG_FILE"
    else
        echo "ℹ️  Configuration file already exists: $CONFIG_FILE"
    fi
}

# ============ Update Configuration File ============
set_config() {
    local key="$1"
    local value="$2"

    if [ -z "$key" ] || [ -z "$value" ]; then
        echo "Error: Both key and value are required" >&2
        return 1
    fi

    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        init_config > /dev/null
    fi

    # Update configuration using jq
    local tmp_file=$(mktemp)
    if jq --arg key "$key" --arg val "$value" 'setpath($key | split(".")) = $val' "$CONFIG_FILE" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$CONFIG_FILE"
        echo "✅ Updated: $key = $value"
    else
        rm -f "$tmp_file"
        echo "Error: Failed to update configuration" >&2
        return 1
    fi
}

# ============ Main Program ============
# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "${1:-}" in
    get)
        get_config "$2"
        ;;
    list)
        list_config
        ;;
    export)
        export_config
        ;;
    init)
        init_config
        ;;
    set)
        set_config "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {get|list|export|init|set} [key] [value]"
        echo ""
        echo "Commands:"
        echo "  get <key>        Get configuration value"
        echo "  list             List all configuration"
        echo "  export           Export configuration to environment variables"
        echo "  init             Initialize default configuration file"
        echo "  set <key> <val>  Set configuration value"
        echo ""
        echo "Configuration priority: Environment Variables > Config File > Default Values"
        echo ""
        echo "Environment variable mapping:"
        echo "  ANTHROPIC_API_KEY       -> api_key"
        echo "  ANTHROPIC_BASE_URL      -> api_base_url"
        echo "  ANTHROPIC_MODEL         -> model"
        echo "  OPENCLAW_GATEWAY_TOKEN  -> gateway_token"
        ;;
esac
fi
