#!/bin/bash
# OKR Tracker CLI - 命令行工具

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${MINDFLOW_WORKSPACE:-$HOME/.openclaw/workspace}"
TRACKER_FILE="$WORKSPACE/okr-tracker.md"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助
show_help() {
    cat << EOF
${BLUE}OKR Tracker CLI${NC} - 目标追踪工具

用法：${YELLOW}$0 <命令> [参数]${NC}

命令:
  ${GREEN}status${NC}              显示当前 OKR 进度概览
  ${GREEN}update${NC} <字段> <值>  更新指定字段
  ${GREEN}log${NC} <内容>         记录今日事项到 memory
  ${GREEN}report${NC} [月份]       生成月度报告
  ${GREEN}remind${NC} <设置>       设置周期性提醒

示例:
  $0 status
  $0 update exercise 3
  $0 log "今天完成了原型设计"
  $0 report 2026-03

EOF
}

# 显示状态
show_status() {
    if [[ ! -f "$TRACKER_FILE" ]]; then
        echo -e "${RED}错误：追踪文件不存在${NC}"
        echo "请先创建 okr-tracker.md 文件"
        exit 1
    fi
    
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}     OKR 追踪看板 - 状态概览${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # 提取关键进度信息
    echo -e "\n${YELLOW}📊 O1 投资体系${NC}"
    grep -E "(建仓进度|本月工作时间)" "$TRACKER_FILE" | head -2 | sed 's/^- /  /'
    
    echo -e "\n${YELLOW}🤖 O2 智能体${NC}"
    grep -E "(原型 #|技术快报)" "$TRACKER_FILE" | head -3 | sed 's/^- /  /'
    
    echo -e "\n${YELLOW}🏠 O3 生活根基${NC}"
    grep -E "(工作时间|锻炼|满意度)" "$TRACKER_FILE" | head -3 | sed 's/^- /  /'
    
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "详细查看：${GREEN}cat $TRACKER_FILE${NC}"
}

# 更新字段
update_field() {
    local field="$1"
    local value="$2"
    
    if [[ -z "$field" || -z "$value" ]]; then
        echo -e "${RED}错误：请提供字段和值${NC}"
        echo "用法：$0 update <字段> <值>"
        exit 1
    fi
    
    echo -e "${GREEN}更新 $field = $value${NC}"
    # TODO: 实现具体的更新逻辑
    echo "（此功能需要编辑 okr-tracker.md 文件）"
}

# 记录日志
log_entry() {
    local content="$1"
    local today=$(date +%Y-%m-%d)
    local memory_file="$WORKSPACE/memory/$today.md"
    
    # 创建 memory 目录
    mkdir -p "$WORKSPACE/memory"
    
    # 添加日志
    echo -e "\n## OKR 相关\n- $content" >> "$memory_file"
    echo -e "${GREEN}✓ 已记录到 $memory_file${NC}"
}

# 主函数
main() {
    case "$1" in
        status)
            show_status
            ;;
        update)
            update_field "$2" "$3"
            ;;
        log)
            log_entry "$2"
            ;;
        report)
            echo "报告功能开发中..."
            ;;
        remind)
            echo "提醒设置功能开发中..."
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            echo -e "${RED}未知命令：$1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
