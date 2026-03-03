#!/bin/bash
# Claude Code Team - Hook 安装脚本
# 安装/卸载通知 Hook 到 Claude Code hooks 目录

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="${HOME}/.claude/hooks"
NOTIFY_HOOK="${HOOKS_DIR}/notify-agi.sh"

# 颜色定义
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

# ============ 创建 Hook 脚本 ============
create_hook() {
    mkdir -p "$HOOKS_DIR"

    cat > "$NOTIFY_HOOK" << 'HOOKEOF'
#!/bin/bash
# Claude Code Team - 通知 Hook
# 由 Claude Code Agent Teams 触发

HOOKS_DIR="${HOME}/.claude/hooks"
CCT_DIR="${HOME}/.openclaw/workspace/skills/claude-code-team"
LIB_DIR="${CCT_DIR}/lib"

# 解析传入的 JSON 数据
read -r JSON_DATA

# 提取字段
SESSION_ID=$(echo "$JSON_DATA" | jq -r '.session_id // empty')
EVENT_NAME=$(echo "$JSON_DATA" | jq -r '.hook_event_name // empty')
CWD=$(echo "$JSON_DATA" | jq -r '.cwd // empty')

# 检查是否为 Agent Teams 任务
if [ -z "$SESSION_ID" ] || [[ ! "$SESSION_ID" =~ ^session- ]]; then
    exit 0
fi

# 加载配置模块和通知模块
source "${LIB_DIR}/config.sh" 2>/dev/null
source "${LIB_DIR}/notify.sh" 2>/dev/null

# 导出配置
export_config

# 读取任务元数据
RESULT_DIR="${CCT_RESULT_DIR:-/root/.openclaw/data/claude-code-results}"
META_FILE="${RESULT_DIR}/task-meta.json"
OUTPUT_FILE="${RESULT_DIR}/task-output.txt"

if [ ! -f "$META_FILE" ]; then
    exit 0
fi

TASK_PROMPT=$(jq -r '.prompt // "未知任务"' "$META_FILE" 2>/dev/null)
EXIT_CODE=$(jq -r '.exit_code // -1' "$META_FILE" 2>/dev/null)

# 确定状态
if [ "$EXIT_CODE" = "0" ]; then
    STATUS="✅ 成功"
else
    STATUS="❌ 失败"
fi

# 生成摘要
OUTPUT_PREVIEW=""
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    OUTPUT_PREVIEW=$(tail -n 50 "$OUTPUT_FILE" | head -n 20 | sed 's/"/\\"/g' | tr '\n' ' ')
    if [ ${#OUTPUT_PREVIEW} -gt 800 ]; then
        OUTPUT_PREVIEW="${OUTPUT_PREVIEW:0:800}..."
    fi
fi

# 构建通知消息
MSG="🤖 Claude Code 任务完成

${STATUS}

📝 任务：${TASK_PROMPT}
🔑 Session: ${SESSION_ID}
📁 目录: ${CWD}

📋 输出摘要：
\`\`\`
${OUTPUT_PREVIEW}
\`\`\`

⏰ $(date '+%Y-%m-%d %H:%M:%S')"

# 发送通知到所有配置的渠道
send_notification "$MSG"

# 写入唤醒标记
if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
    cat > "${RESULT_DIR}/pending-wake.json" << EOF
{
  "session_id": "${SESSION_ID}",
  "timestamp": "$(date -Iseconds)",
  "event": "task_completed",
  "status": "$STATUS"
}
EOF
    # 触发网关唤醒
    curl -s -X POST "https://gateway.openclaw.local/wake" \
        -H "Authorization: Bearer ${OPENCLAW_GATEWAY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"session_id\":\"${SESSION_ID}\"}" > /dev/null 2>&1 || true
fi
HOOKEOF

    chmod +x "$NOTIFY_HOOK"
    info "已创建通知 Hook: $NOTIFY_HOOK"
}

# ============ 卸载 Hook ============
remove_hook() {
    if [ -f "$NOTIFY_HOOK" ]; then
        rm -f "$NOTIFY_HOOK"
        info "已移除通知 Hook"
    else
        warn "Hook 不存在: $NOTIFY_HOOK"
    fi
}

# ============ 检查 Hook 状态 ============
check_status() {
    echo "=== Hook 状态检查 ==="
    echo ""

    if [ -f "$NOTIFY_HOOK" ]; then
        info "通知 Hook 已安装"
        echo "  路径: $NOTIFY_HOOK"
        if [ -x "$NOTIFY_HOOK" ]; then
            info "可执行权限: 已设置"
        else
            warn "可执行权限: 未设置"
        fi
    else
        warn "通知 Hook 未安装"
    fi

    echo ""
    echo "=== Claude Code Hooks 目录 ==="
    echo "  路径: $HOOKS_DIR"

    if [ -d "$HOOKS_DIR" ]; then
        info "目录存在"
        echo ""
        echo "现有 Hooks:"
        ls -la "$HOOKS_DIR"/*.sh 2>/dev/null || echo "  (无)"
    else
        warn "目录不存在"
    fi
}

# ============ 主程序 ============
case "${1:-install}" in
    install)
        echo "=== 安装 Claude Code Team Hooks ==="
        echo ""

        # 检查依赖
        if ! command -v jq &> /dev/null; then
            error "jq 未安装"
            exit 1
        fi

        create_hook

        # 配置 Claude settings.json
        echo ""
        echo "正在配置 Claude hooks..."
        cat > "${HOME}/.claude/settings.json" << 'SETTINGSEOF'
{
  "model": "kimi-k2.5",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/root/.claude/hooks/notify-agi.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionEnd": []
  }
}
SETTINGSEOF
        info "已更新 ~/.claude/settings.json"

        echo ""
        info "安装完成！"
        echo ""
        echo "Hook 功能："
        echo "  - 任务开始时发送通知"
        echo "  - 任务完成后发送通知（含输出摘要）"
        echo "  - 支持多通知渠道（Feishu/Discord/Telegram）"
        echo "  - 自动触发网关唤醒（如果配置了 TOKEN）"
        ;;

    remove|uninstall)
        echo "=== 卸载 Claude Code Team Hooks ==="
        echo ""
        remove_hook
        ;;

    status)
        check_status
        ;;

    *)
        echo "用法: $0 {install|remove|status}"
        echo ""
        echo "命令:"
        echo "  install   安装/更新 Hook（默认）"
        echo "  remove    卸载 Hook"
        echo "  status    检查 Hook 状态"
        ;;
esac
