#!/bin/bash
# Claude Code Agent Teams - Async Task Executor with Session Management
# Usage: invoke.sh "Task Description" [Working Directory] [Session ID or new]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
CONFIG_FILE="${SCRIPT_DIR}/../config/settings.json"
SESSION_MANAGER="${SCRIPT_DIR}/session-manager.sh"

# Load configuration module
source "${LIB_DIR}/config.sh" 2>/dev/null || {
    echo "Error: Cannot load configuration module" >&2
    exit 1
}

# Export configuration to environment variables
export_config

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# ============ Environment Validation ============
validate_environment() {
    local has_error=0

    echo "=== Environment Validation ==="
    echo ""

    # Check claude command
    if ! command -v claude &> /dev/null; then
        error "claude command not found"
        echo "  Please install Claude Code CLI:"
        echo "  npm install -g @anthropic-ai/claude-cli"
        has_error=1
    else
        info "claude command is installed"
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        error "jq is not installed"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  macOS: brew install jq"
        has_error=1
    else
        info "jq is installed"
    fi

    # Check curl
    if ! command -v curl &> /dev/null; then
        error "curl is not installed"
        echo "  Ubuntu/Debian: sudo apt-get install curl"
        echo "  macOS: brew install curl"
        has_error=1
    else
        info "curl is installed"
    fi

    # Check API Key
    local api_key=$(get_config "api_key")
    if [ -z "$api_key" ]; then
        error "ANTHROPIC_API_KEY is not set"
        echo "  Set environment variable: export ANTHROPIC_API_KEY='your-key'"
        has_error=1
    else
        info "ANTHROPIC_API_KEY is set"
    fi

    # Check Gateway Token (optional)
    local gateway_token=$(get_config "gateway_token")
    if [ -z "$gateway_token" ]; then
        warn "OPENCLAW_GATEWAY_TOKEN is not set (optional)"
        echo "  Set this to enable auto-wake functionality"
    else
        info "OPENCLAW_GATEWAY_TOKEN is set"
    fi

    echo ""

    if [ $has_error -eq 1 ]; then
        echo "=== Environment Validation Failed ==="
        exit 1
    else
        echo "=== Environment Validation Passed ==="
        echo ""
    fi
}

# ============ Read Configuration ============
read_config() {
    # Use configuration module to read settings
    API_BASE_URL=$(get_config "api_base_url")
    API_KEY=$(get_config "api_key")
    MODEL=$(get_config "model")
    RESULT_DIR=$(get_config "result_dir")

    # Read notification configuration
    NOTIFY_CHANNELS=$(get_config "notify.channels")
    FEISHU_CHAT_ID=$(get_config "notify.feishu.chat_id")

    # Ensure result directory exists
    if ! mkdir -p "$RESULT_DIR" 2>/dev/null; then
        error "Failed to create result directory: $RESULT_DIR"
        exit 1
    fi
}

# ============ Parse Arguments ============
parse_args() {
    TASK="${1:-}"
    WORKDIR="${2:-${HOME}/claude-code-projects}"
    SESSION_INPUT="${3:-auto}"

    if [ -z "$TASK" ]; then
        echo "Usage: $0 'Task Description' [Working Directory] [Session ID]"
        echo ""
        echo "Session ID options:"
        echo "  auto      Auto-manage (default): create first time, reuse later"
        echo "  new       Force create new Session"
        echo "  <id>      Use specified Session ID"
        echo ""
        echo "Examples:"
        echo "  $0 'Create a snake game' /path/to/project"
        echo "  $0 'Fix login bug' /path/to/project new"
        echo "  $0 'Hotfix' /path/to/project hotfix-001"
        echo ""
        echo "Notification channels (configure via config/settings.json):"
        echo "  - Feishu (default)"
        echo "  - Discord (requires webhook_url)"
        echo "  - Telegram (requires bot_token and chat_id)"
        exit 1
    fi

    # Validate task description (basic security check)
    if [[ "$TASK" =~ \$\( ]] || [[ "$TASK" =~ \` ]]; then
        error "Invalid characters in task description"
        exit 1
    fi
}

# ============ Session Management ============
manage_session() {
    if [ "$SESSION_INPUT" = "auto" ]; then
        local session_result=$("$SESSION_MANAGER" get-or-create "$WORKDIR")
        local session_status="${session_result%%:*}"
        SESSION_ID="${session_result#*:}"

        if [ "$session_status" = "existing" ]; then
            info "Reusing Session: $SESSION_ID"
        else
            info "Creating new Session: $SESSION_ID"
        fi
    elif [ "$SESSION_INPUT" = "new" ]; then
        SESSION_ID=$("$SESSION_MANAGER" set "$WORKDIR" "true")
        info "Creating new Session: $SESSION_ID"
    else
        SESSION_ID="$SESSION_INPUT"
        info "Using specified Session: $SESSION_ID"
    fi

    TASK_NAME="$SESSION_ID"
}

# ============ Prepare Task ============
prepare_task() {
    echo ""
    echo -e "${BLUE}Starting Claude Code Agent Teams${NC}"
    echo "Task: $TASK"
    echo "Working Directory: $WORKDIR"
    echo "Model: $MODEL"
    echo "Notification Channels: $NOTIFY_CHANNELS"
    echo ""

    # Clean old results
    rm -f "$RESULT_DIR/latest.json" "$RESULT_DIR/pending-wake.json" "$RESULT_DIR/.hook-lock" "$RESULT_DIR/.task-done" 2>/dev/null

    # Write task metadata (use jq to ensure proper JSON format)
    mkdir -p "$RESULT_DIR"
    jq -n \
        --arg task_name "${TASK_NAME}" \
        --arg session_id "${SESSION_ID}" \
        --arg prompt "${TASK}" \
        --arg workdir "${WORKDIR}" \
        --arg started_at "$(date -Iseconds)" \
        --argjson notify_channels "${NOTIFY_CHANNELS:-[]}" \
        '{
            task_name: $task_name,
            session_id: $session_id,
            prompt: $prompt,
            workdir: $workdir,
            started_at: $started_at,
            status: "running",
            notify_channels: $notify_channels
        }' > "$RESULT_DIR/task-meta.json"
}

# ============ Launch Task in Background ============
launch_task() {
    # Create background execution script
    local run_script="/tmp/claude-run-${TASK_NAME}.sh"
    cat > "$run_script" << RUNEOF
#!/bin/bash
set -e

TASK="\$1"
WORKDIR="\$2"
RESULT_DIR="\$3"
TASK_NAME="\$4"
API_BASE_URL="\$5"
API_KEY="\$6"
MODEL="\$7"
SESSION_ID="\$8"
NOTIFY_CHANNELS="\$9"

export ANTHROPIC_BASE_URL="\$API_BASE_URL"
export ANTHROPIC_API_KEY="\$API_KEY"
export ANTHROPIC_MODEL="\$MODEL"
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Ensure working directory exists
if [ ! -d "\$WORKDIR" ]; then
    echo "Creating working directory: \$WORKDIR"
    mkdir -p "\$WORKDIR" || {
        echo "Error: Cannot create working directory \$WORKDIR" >&2
        exit 1
    }
fi

cd "\$WORKDIR" || {
    echo "Error: Cannot change to working directory \$WORKDIR" >&2
    exit 1
}

# Execute task
stdbuf -oL -eL claude -p "\$TASK" --permission-mode acceptEdits --teammate-mode auto > "\$RESULT_DIR/task-output.txt" 2>&1

EXIT_CODE=\$?
echo "Exit code: \$EXIT_CODE" >> "\$RESULT_DIR/task-output.txt"
sync

# Update metadata
cat > "\$RESULT_DIR/task-meta.json.tmp" << METAEOF
{
  "task_name": "\${TASK_NAME}",
  "session_id": "\${SESSION_ID}",
  "prompt": "\${TASK}",
  "workdir": "\${WORKDIR}",
  "completed_at": "\$(date -Iseconds)",
  "exit_code": \${EXIT_CODE},
  "status": "\$( [ "\$EXIT_CODE" = "0" ] && echo "done" || echo "failed" )"
}
METAEOF
mv "\$RESULT_DIR/task-meta.json.tmp" "\$RESULT_DIR/task-meta.json"

# Trigger Hook (if exists)
if [ -f "\${HOME}/.claude/hooks/notify-agi.sh" ]; then
    echo "{\"session_id\":\"\${SESSION_ID}\",\"hook_event_name\":\"Stop\",\"cwd\":\"\${WORKDIR}\"}" | \
        bash "\${HOME}/.claude/hooks/notify-agi.sh" &
fi
RUNEOF

    chmod +x "$run_script"

    # Launch in background
    nohup bash "$run_script" "$TASK" "$WORKDIR" "$RESULT_DIR" "$TASK_NAME" \
        "$API_BASE_URL" "$API_KEY" "$MODEL" "$SESSION_ID" "$NOTIFY_CHANNELS" \
        > /dev/null 2>&1 &
    PID=$!

    info "Task started (PID: $PID)"
    echo "You will be notified when the task completes"
}

# ============ Send Start Notification ============
send_start_notification() {
    local msg="Claude Code Task Started

Task: ${TASK}
Session: ${SESSION_ID}
Directory: ${WORKDIR}

The task is running in the background. You will be notified when it completes."

    # Load notification module
    source "${LIB_DIR}/notify.sh" 2>/dev/null || return

    send_notification "$msg" &
}

# ============ Main Program ============
main() {
    # Initialize configuration file (if not exists)
    init_config > /dev/null 2>&1

    # Environment validation
    validate_environment

    # Read configuration
    read_config

    # Parse arguments
    parse_args "$@"

    # Manage session
    manage_session

    # Prepare task
    prepare_task

    # Launch task
    launch_task

    # Send start notification
    send_start_notification

    echo ""
    echo "Tips:"
    echo "  - View output: tail -f ${RESULT_DIR}/task-output.txt"
    echo "  - Session management: scripts/session-manager.sh list"
}

main "$@"
