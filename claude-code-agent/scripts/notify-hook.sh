#!/bin/bash
# Claude Code 完成通知 Hook
# 由 invoke.sh 在任务完成后调用

LOG="/home/ubuntu/clawd/data/claude-code-results/hook.log"
RESULT_DIR="/home/ubuntu/clawd/data/claude-code-results"
TASK_OUTPUT="${RESULT_DIR}/task-output.txt"
META_FILE="${RESULT_DIR}/task-meta.json"
FEISHU_CHAT_ID="user:ou_8f725769032066e49523f31b501e33c6"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG"; }
log "=== Hook fired ==="

# 防重复（30 秒内不重复发送）
LOCK="${RESULT_DIR}/.hook-lock"
if [ -f "$LOCK" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK") ))
    if [ "$AGE" -lt 30 ]; then
        log "Duplicate ${AGE}s skip"
        exit 0
    fi
fi
touch "$LOCK"

# 读取输出（文件已确保写完）
OUTPUT=""
if [ -f "$TASK_OUTPUT" ] && [ -s "$TASK_OUTPUT" ]; then
    OUTPUT=$(tail -c 4000 "$TASK_OUTPUT")
    log "Output: ${#OUTPUT} chars"
else
    log "Output file empty or not found"
fi

# 读取任务名
TASK="unknown"
if [ -f "$META_FILE" ]; then
    TASK=$(jq -r '.task_name // "unknown"' "$META_FILE" 2>/dev/null)
    log "Task: $TASK"
fi

# 发送 Feishu 消息
if [ -n "$OUTPUT" ]; then
    SUMMARY=$(echo "$OUTPUT" | tail -c 500 | tr '\n' ' ')
    MSG="🤖 Claude Code 完成

任务：${TASK}
摘要：${SUMMARY:0:350}"
    
    log "Sending..."
    if timeout 30 openclaw message send --channel feishu --target "$FEISHU_CHAT_ID" --message "$MSG" >> "$LOG" 2>&1; then
        log "Sent OK"
    else
        log "Send failed"
    fi
else
    log "Skip: no output"
fi

log "=== Done ==="
