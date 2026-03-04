#!/bin/bash
# Claude Code Team - mcporter CLI Wrapper
# Usage: cli.sh <tool> [arguments]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

error() { echo "✗ $1" >&2; exit 1; }

invoke_task() {
    local task="$1" workdir="${2:-${HOME}/claude-code-projects}" session="${3:-auto}"
    [ -z "$task" ] && error "task is required"
    "${SCRIPT_DIR}/main.sh" invoke "$task" "$workdir" "$session"
}

list_sessions() { "${SCRIPT_DIR}/main.sh" list-sessions; }

get_session() {
    [ -z "$1" ] && error "workdir is required"
    "${SCRIPT_DIR}/main.sh" get-session "$1"
}

remove_session() {
    [ -z "$1" ] && error "workdir is required"
    "${SCRIPT_DIR}/main.sh" remove-session "$1"
}

check_env() { "${SCRIPT_DIR}/main.sh" check-env; }

test_notification() { "${SCRIPT_DIR}/main.sh" test-notify; }

show_help() {
    cat << EOF
Claude Code Team - mcporter CLI Wrapper

Usage: $0 <tool> [arguments]

Tools:
  invoke_task <task> [workdir] [session]   Execute a coding task
  list_sessions                             List all sessions
  get_session <workdir>                     Get session for directory
  remove_session <workdir>                  Remove session
  check_env                                 Validate environment
  test_notification                         Send test notification

Examples:
  $0 invoke_task "Create a snake game" /path/to/project
  $0 list_sessions
  $0 get_session /path/to/project
  $0 check_env
EOF
}

[ $# -lt 1 ] && { show_help; exit 1; }

TOOL="$1"; shift

case "$TOOL" in
    invoke_task) invoke_task "$@" ;;
    list_sessions) list_sessions ;;
    get_session) get_session "$@" ;;
    remove_session) remove_session "$@" ;;
    check_env) check_env ;;
    test_notification) test_notification ;;
    help|--help|-h) show_help ;;
    *) error "Unknown tool: $TOOL" ;;
esac
