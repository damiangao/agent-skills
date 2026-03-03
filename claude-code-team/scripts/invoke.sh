#!/bin/bash
# Claude Code Agent Teams - 异步执行编码任务（带 Session 管理）
# 用法：invoke.sh "任务描述" [工作目录] [Session ID 或 new]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
CONFIG_FILE="${SCRIPT_DIR}/../config/settings.json"
SESSION_MANAGER="${SCRIPT_DIR}/session-manager.sh"

# 加载配置模块
source "${LIB_DIR}/config.sh" 2>/dev/null || {
    echo "❌ 错误：无法加载配置模块"
    exit 1
}

# 导出配置到环境变量
export_config

# 颜色定义
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

# ============ 环境校验 ============
validate_environment() {
    local has_error=0

    echo "=== 环境校验 ==="
    echo ""

    # 检查 claude 命令
    if ! command -v claude &> /dev/null; then
        error "claude 命令未找到"
        echo "  请先安装 Claude Code CLI"
        has_error=1
    else
        info "claude 命令已安装"
    fi

    # 检查 jq
    if ! command -v jq &> /dev/null; then
        error "jq 未安装"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  macOS: brew install jq"
        has_error=1
    else
        info "jq 已安装"
    fi

    # 检查 API Key
    local api_key=$(get_config "api_key")
    if [ -z "$api_key" ]; then
        error "ANTHROPIC_API_KEY 未设置"
        echo "  请设置环境变量: export ANTHROPIC_API_KEY='your-key'"
        has_error=1
    else
        info "ANTHROPIC_API_KEY 已设置"
    fi

    # 检查 Gateway Token（可选）
    local gateway_token=$(get_config "gateway_token")
    if [ -z "$gateway_token" ]; then
        warn "OPENCLAW_GATEWAY_TOKEN 未设置（可选）"
        echo "  设置后可启用自动唤醒功能"
    else
        info "OPENCLAW_GATEWAY_TOKEN 已设置"
    fi

    echo ""

    if [ $has_error -eq 1 ]; then
        echo "=== 环境校验失败 ==="
        exit 1
    else
        echo "=== 环境校验通过 ==="
        echo ""
    fi
}

# ============ 读取配置 ============
read_config() {
    # 使用配置模块读取配置
    API_BASE_URL=$(get_config "api_base_url")
    API_KEY=$(get_config "api_key")
    MODEL=$(get_config "model")
    RESULT_DIR=$(get_config "result_dir")

    # 读取通知配置
    NOTIFY_CHANNELS=$(get_config "notify.channels")
    FEISHU_CHAT_ID=$(get_config "notify.feishu.chat_id")

    # 确保结果目录存在
    mkdir -p "$RESULT_DIR"
}

# ============ 参数解析 ============
parse_args() {
    TASK="${1:-}"
    WORKDIR="${2:-/root/.openclaw/workspace}"
    SESSION_INPUT="${3:-auto}"

    if [ -z "$TASK" ]; then
        echo "用法：$0 '任务描述' [工作目录] [Session ID]"
        echo ""
        echo "Session ID 选项："
        echo "  auto      自动管理（默认）：首次创建，后续复用"
        echo "  new       强制创建新 Session"
        echo "  <id>      使用指定 Session ID"
        echo ""
        echo "示例："
        echo "  $0 'Create a snake game' /path/to/project"
        echo "  $0 'Fix login bug' /path/to/project new"
        echo "  $0 'Hotfix' /path/to/project hotfix-001"
        echo ""
        echo "通知渠道（通过 config/settings.json 配置）："
        echo "  - Feishu (默认)"
        echo "  - Discord (需配置 webhook_url)"
        echo "  - Telegram (需配置 bot_token 和 chat_id)"
        exit 1
    fi
}

# ============ Session 管理 ============
manage_session() {
    if [ "$SESSION_INPUT" = "auto" ]; then
        local session_result=$("$SESSION_MANAGER" get-or-create "$WORKDIR")
        local session_status="${session_result%%:*}"
        SESSION_ID="${session_result#*:}"

        if [ "$session_status" = "existing" ]; then
            info "复用 Session: $SESSION_ID"
        else
            info "创建新 Session: $SESSION_ID"
        fi
    elif [ "$SESSION_INPUT" = "new" ]; then
        SESSION_ID=$("$SESSION_MANAGER" set "$WORKDIR" "true")
        info "新建 Session: $SESSION_ID"
    else
        SESSION_ID="$SESSION_INPUT"
        info "使用指定 Session: $SESSION_ID"
    fi

    TASK_NAME="$SESSION_ID"
}

# ============ 任务准备 ============
prepare_task() {
    echo ""
    echo -e "${BLUE}🚀 启动 Claude Code Agent Teams${NC}"
    echo "📋 任务：$TASK"
    echo "📁 工作目录：$WORKDIR"
    echo "🔧 模型：$MODEL"
    echo "📢 通知渠道：$NOTIFY_CHANNELS"
    echo ""

    # 清理旧结果
    rm -f "$RESULT_DIR/latest.json" "$RESULT_DIR/pending-wake.json" "$RESULT_DIR/.hook-lock" "$RESULT_DIR/.task-done" 2>/dev/null

    # 写入任务元数据（使用 jq 确保 JSON 格式正确）
    mkdir -p "$RESULT_DIR"
    jq -n \
        --arg task_name "${TASK_NAME}" \
        --arg session_id "${SESSION_ID}" \
        --arg prompt "${TASK}" \
        --arg workdir "${WORKDIR}" \
        --arg started_at "$(date -Iseconds)" \
        --argjson notify_channels "${NOTIFY_CHANNELS}" \
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

# ============ 创建并启动后台脚本 ============
launch_task() {
    # 创建后台执行脚本
    local run_script="/tmp/claude-run-${TASK_NAME}.sh"
    cat > "$run_script" << RUNEOF
#!/bin/bash
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

# 确保工作目录存在
mkdir -p "\$WORKDIR"
cd "\$WORKDIR" || {
    echo "错误：无法切换到工作目录 \$WORKDIR" >&2
    exit 1
}

# 执行任务
stdbuf -oL -eL claude -p "\$TASK" --permission-mode acceptEdits --teammate-mode auto > "\$RESULT_DIR/task-output.txt" 2>&1

EXIT_CODE=\$?
echo "Exit code: \$EXIT_CODE" >> "\$RESULT_DIR/task-output.txt"
sync

# 更新元数据
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

# 触发 Hook
if [ -f "\${HOME}/.claude/hooks/notify-agi.sh" ]; then
    echo "{\"session_id\":\"\${SESSION_ID}\",\"hook_event_name\":\"Stop\",\"cwd\":\"\${WORKDIR}\"}" | \
        bash "\${HOME}/.claude/hooks/notify-agi.sh" &
fi
RUNEOF

    chmod +x "$run_script"

    # 后台启动
    nohup bash "$run_script" "$TASK" "$WORKDIR" "$RESULT_DIR" "$TASK_NAME" \
        "$API_BASE_URL" "$API_KEY" "$MODEL" "$SESSION_ID" "$NOTIFY_CHANNELS" \
        > /dev/null 2>&1 &
    PID=$!

    info "任务已启动 (PID: $PID)"
    echo "📝 完成后会自动通知你"
}

# ============ 发送启动通知 ============
send_start_notification() {
    local msg="🚀 Claude Code 任务已启动

任务：${TASK}
Session: ${SESSION_ID}
目录: ${WORKDIR}

⏳ 任务正在后台执行，完成后会通知你。"

    # 加载通知模块
    source "${LIB_DIR}/notify.sh" 2>/dev/null || return

    send_notification "$msg" &
}

# ============ 主程序 ============
main() {
    # 初始化配置文件（如果不存在）
    init_config > /dev/null 2>&1

    # 环境校验
    validate_environment

    # 读取配置
    read_config

    # 解析参数
    parse_args "$@"

    # 管理 Session
    manage_session

    # 准备任务
    prepare_task

    # 启动任务
    launch_task

    # 发送启动通知
    send_start_notification

    echo ""
    echo "💡 提示："
    echo "  - 查看输出: tail -f ${RESULT_DIR}/task-output.txt"
    echo "  - Session 管理: scripts/session-manager.sh list"
}

main "$@"
