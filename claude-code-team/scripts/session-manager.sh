#!/bin/bash
# Session Manager - Maintains mapping between project directories and Session IDs
# Usage:
#   session-manager.sh get /path/to/project    # Get session_id
#   session-manager.sh set /path/to/project    # Create/update session_id
#   session-manager.sh list                    # List all mappings
#   session-manager.sh remove /path/to/project # Remove mapping

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
SESSIONS_FILE="${DATA_DIR}/sessions.json"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Initialize sessions.json (if not exists)
if [ ! -f "$SESSIONS_FILE" ]; then
    echo '{}' > "$SESSIONS_FILE"
fi

# Get session_id
get_session() {
    local workdir="$1"

    if [ -z "$workdir" ]; then
        echo "Error: Working directory is required" >&2
        return 1
    fi

    local session_id=$(jq -r --arg dir "$workdir" '.[$dir] // empty' "$SESSIONS_FILE" 2>/dev/null)

    if [ -n "$session_id" ]; then
        echo "$session_id"
    else
        echo ""
    fi
}

# Create or get session_id
set_session() {
    local workdir="$1"
    local force_new="${2:-false}"

    if [ -z "$workdir" ]; then
        echo "Error: Working directory is required" >&2
        return 1
    fi

    # Check if already exists
    if [ "$force_new" != "true" ]; then
        local existing=$(get_session "$workdir")
        if [ -n "$existing" ]; then
            echo "$existing"
            return 0
        fi
    fi

    # Generate new session_id
    local session_id="session-$(date +%s)-$$"

    # Write mapping (use temp file for atomic operation)
    local tmp_file=$(mktemp)
    if jq --arg dir "$workdir" --arg sid "$session_id" '.[$dir] = $sid' "$SESSIONS_FILE" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$SESSIONS_FILE"
        echo "$session_id"
    else
        rm -f "$tmp_file"
        echo "Error: Failed to update sessions file" >&2
        return 1
    fi
}

# List all mappings
list_sessions() {
    if [ ! -f "$SESSIONS_FILE" ]; then
        echo "{}"
        return 0
    fi

    # Validate JSON format
    if ! jq empty "$SESSIONS_FILE" 2>/dev/null; then
        echo "Error: Invalid JSON in sessions file" >&2
        return 1
    fi

    jq '.' "$SESSIONS_FILE"
}

# Remove mapping
remove_session() {
    local workdir="$1"

    if [ -z "$workdir" ]; then
        echo "Error: Working directory is required" >&2
        return 1
    fi

    local tmp_file=$(mktemp)
    if jq --arg dir "$workdir" 'del(.[$dir])' "$SESSIONS_FILE" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$SESSIONS_FILE"
        echo "Removed: $workdir"
    else
        rm -f "$tmp_file"
        echo "Error: Failed to update sessions file" >&2
        return 1
    fi
}

# Get or create session (smart mode)
get_or_create() {
    local workdir="$1"

    if [ -z "$workdir" ]; then
        echo "Error: Working directory is required" >&2
        return 1
    fi

    local session_id=$(get_session "$workdir")

    if [ -n "$session_id" ]; then
        echo "existing:$session_id"
    else
        local new_id=$(set_session "$workdir" "true")
        if [ $? -eq 0 ]; then
            echo "new:$new_id"
        else
            return 1
        fi
    fi
}

# Show help
show_help() {
    echo "Usage: $0 {get|set|list|remove|get-or-create} [workdir]"
    echo ""
    echo "Commands:"
    echo "  get <workdir>              Get session_id for directory"
    echo "  set <workdir> [force]      Create new session_id (force=true to overwrite)"
    echo "  list                       List all session mappings"
    echo "  remove <workdir>           Remove session mapping"
    echo "  get-or-create <workdir>    Get existing or create new session"
    echo ""
    echo "Examples:"
    echo "  $0 get /path/to/project          # Get session_id"
    echo "  $0 set /path/to/project          # Create new session_id"
    echo "  $0 list                          # List all mappings"
    echo "  $0 remove /path/to/project       # Remove mapping"
    echo "  $0 get-or-create /path/to/project # Get or create (smart)"
}

# ============ Main Program ============
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
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
