#!/bin/bash
# Session 管理器 - 维护项目目录与 Session ID 的映射
# 用法：
#   session-manager.sh get /path/to/project    # 获取 session_id
#   session-manager.sh set /path/to/project    # 创建/更新 session_id
#   session-manager.sh list                    # 列出所有映射
#   session-manager.sh remove /path/to/project # 删除映射

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
SESSIONS_FILE="${DATA_DIR}/sessions.json"

# 确保数据目录存在
mkdir -p "$DATA_DIR"

# 初始化 sessions.json（如果不存在）
if [ ! -f "$SESSIONS_FILE" ]; then
    echo '{}' > "$SESSIONS_FILE"
fi

# 获取 session_id
get_session() {
    local workdir="$1"
    local session_id=$(jq -r --arg dir "$workdir" '.[$dir] // empty' "$SESSIONS_FILE" 2>/dev/null)
    
    if [ -n "$session_id" ]; then
        echo "$session_id"
    else
        echo ""
    fi
}

# 创建或获取 session_id
set_session() {
    local workdir="$1"
    local force_new="${2:-false}"
    
    # 检查是否已存在
    if [ "$force_new" != "true" ]; then
        local existing=$(get_session "$workdir")
        if [ -n "$existing" ]; then
            echo "$existing"
            return 0
        fi
    fi
    
    # 生成新的 session_id
    local session_id="session-$(date +%s)-$$"
    
    # 写入映射
    local tmp_file=$(mktemp)
    jq --arg dir "$workdir" --arg sid "$session_id" '.[$dir] = $sid' "$SESSIONS_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSIONS_FILE"
    
    echo "$session_id"
}

# 列出所有映射
list_sessions() {
    jq '.' "$SESSIONS_FILE"
}

# 删除映射
remove_session() {
    local workdir="$1"
    local tmp_file=$(mktemp)
    jq --arg dir "$workdir" 'del(.[$dir])' "$SESSIONS_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSIONS_FILE"
    echo "Removed: $workdir"
}

# 获取或创建 session（智能模式）
get_or_create() {
    local workdir="$1"
    local session_id=$(get_session "$workdir")
    
    if [ -n "$session_id" ]; then
        echo "existing:$session_id"
    else
        local new_id=$(set_session "$workdir" "true")
        echo "new:$new_id"
    fi
}

# ==================== 主程序 ====================
case "${1:-}" in
    get)
        get_session "$2"
        ;;
    set)
        set_session "$2" "${3:-false}"
        ;;
    list)
        list_sessions
        ;;
    remove)
        remove_session "$2"
        ;;
    get-or-create)
        get_or_create "$2"
        ;;
    *)
        echo "用法：$0 {get|set|list|remove|get-or-create} [workdir]"
        echo ""
        echo "示例："
        echo "  $0 get /path/to/project          # 获取 session_id"
        echo "  $0 set /path/to/project          # 创建新 session_id"
        echo "  $0 list                          # 列出所有映射"
        echo "  $0 remove /path/to/project       # 删除映射"
        echo "  $0 get-or-create /path/to/project # 获取或创建（智能）"
        exit 1
        ;;
esac
