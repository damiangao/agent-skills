#!/bin/bash
# Claude Code Agent Teams - 异步执行编码任务（带 Session 管理）
# 用法：invoke.sh "任务描述" [工作目录] [Session ID 或 new]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/settings.json"
SESSION_MANAGER="${SCRIPT_DIR}/session-manager.sh"

# 默认配置
API_BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
API_KEY="${ANTHROPIC_API_KEY:-}"
MODEL="kimi-k2.5"
RESULT_DIR="/home/ubuntu/clawd/data/claude-code-results"
FEISHU_CHAT_ID="user:ou_8f725769032066e49523f31b501e33c6"

# 检查 API Key
if [ -z "$API_KEY" ]; then
    echo "❌ 错误：ANTHROPIC_API_KEY 环境变量未设置"
    exit 1
fi

# 读取配置文件
if [ -f "$CONFIG_FILE" ]; then
    API_BASE_URL=$(jq -r '.api_base_url // "'$API_BASE_URL'"' "$CONFIG_FILE" 2>/dev/null)
    MODEL=$(jq -r '.model // "'$MODEL'"' "$CONFIG_FILE" 2>/dev/null)
    FEISHU_CHAT_ID=$(jq -r '.feishu_chat_id // "'$FEISHU_CHAT_ID'"' "$CONFIG_FILE" 2>/dev/null)
fi

# ==================== 参数解析 ====================
TASK="${1:-}"
WORKDIR="${2:-/root/.openclaw/workspace}"
SESSION_INPUT="${3:-auto}"

if [ -z "$TASK" ]; then
    echo "用法：$0 '任务描述' [工作目录] [Session ID]"
    echo ""
    echo "Session ID 选项：auto(默认) | new | <custom-id>"
    exit 1
fi

# ==================== Session ID 管理 ====================
if [ "$SESSION_INPUT" = "auto" ]; then
    SESSION_RESULT=$("$SESSION_MANAGER" get-or-create "$WORKDIR")
    SESSION_STATUS="${SESSION_RESULT%%:*}"
    SESSION_ID="${SESSION_RESULT#*:}"
    [ "$SESSION_STATUS" = "existing" ] && echo "📌 复用 Session: $SESSION_ID" || echo "🆕 创建 Session: $SESSION_ID"
elif [ "$SESSION_INPUT" = "new" ]; then
    SESSION_ID=$("$SESSION_MANAGER" set "$WORKDIR" "true")
    echo "🆕 新建 Session: $SESSION_ID"
else
    SESSION_ID="$SESSION_INPUT"
    echo "🏷️  使用 Session: $SESSION_ID"
fi

TASK_NAME="$SESSION_ID"

# ==================== 准备工作 ====================
echo ""
echo "🚀 启动 Claude Code Agent Teams"
echo "📋 任务：$TASK"
echo "📁 工作目录：$WORKDIR"
echo ""

# 清理旧结果
rm -f "$RESULT_DIR/latest.json" "$RESULT_DIR/pending-wake.json" "$RESULT_DIR/.hook-lock" "$RESULT_DIR/.task-done" 2>/dev/null

# 写入任务元数据
mkdir -p "$RESULT_DIR"
cat > "$RESULT_DIR/task-meta.json" << EOF
{
  "task_name": "${TASK_NAME}",
  "session_id": "${SESSION_ID}",
  "prompt": "${TASK}",
  "workdir": "${WORKDIR}",
  "started_at": "$(date -Iseconds)",
  "status": "running"
}
EOF

# ==================== 创建后台脚本 ====================
RUN_SCRIPT="/tmp/claude-run-${TASK_NAME}.sh"
cat > "$RUN_SCRIPT" << 'RUNEOF'
#!/bin/bash
TASK="$1"
WORKDIR="$2"
RESULT_DIR="$3"
TASK_NAME="$4"
API_BASE_URL="$5"
API_KEY="$6"
MODEL="$7"
SESSION_ID="$8"

export ANTHROPIC_BASE_URL="$API_BASE_URL"
export ANTHROPIC_API_KEY="$API_KEY"
export ANTHROPIC_MODEL="$MODEL"
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

cd "$WORKDIR"
stdbuf -oL -eL claude -p "$TASK" --permission-mode acceptEdits --teammate-mode auto > "$RESULT_DIR/task-output.txt" 2>&1

EXIT_CODE=$?
echo "Exit code: $EXIT_CODE" >> "$RESULT_DIR/task-output.txt"
sync

# 更新元数据
cat > "$RESULT_DIR/task-meta.json" << METAEOF
{
  "task_name": "${TASK_NAME}",
  "session_id": "${SESSION_ID}",
  "prompt": "${TASK}",
  "workdir": "${WORKDIR}",
  "completed_at": "$(date -Iseconds)",
  "exit_code": ${EXIT_CODE},
  "status": "done"
}
METAEOF

# 触发 Hook
echo "{\"session_id\":\"${SESSION_ID}\",\"hook_event_name\":\"Stop\",\"cwd\":\"${WORKDIR}\"}" | bash /root/.claude/hooks/notify-agi.sh &
RUNEOF

chmod +x "$RUN_SCRIPT"

# ==================== 后台启动 ====================
nohup bash "$RUN_SCRIPT" "$TASK" "$WORKDIR" "$RESULT_DIR" "$TASK_NAME" "$API_BASE_URL" "$API_KEY" "$MODEL" "$SESSION_ID" > /dev/null 2>&1 &
PID=$!

echo "✅ 任务已启动 (PID: $PID)"
echo "📝 完成后会自动通知你"

# 立即发送 Feishu 启动通知
MSG="🚀 Claude Code 任务已启动

任务：${TASK}
Session: ${SESSION_ID}

⏳ 任务正在后台执行，完成后会通知你。"
timeout 10 openclaw message send --channel feishu --target "$FEISHU_CHAT_ID" --message "$MSG" > /dev/null 2>&1 || true
