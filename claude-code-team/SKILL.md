---
name: claude-code-team
description: Asynchronous Claude Code Agent Teams with session management and multi-channel notifications (Feishu, Discord, Telegram).
homepage: https://github.com/damiangao/agent-skills/tree/main/claude-code-team
metadata: {"clawdbot":{"emoji":"🚀","os":["darwin","linux"],"requires":{"bins":["jq","curl","claude"]}}}
---

# Claude Code Agent Teams

Execute coding tasks asynchronously with automatic notifications on completion.

## Tools

| Tool | Description |
|------|-------------|
| `invoke_task` | Execute a coding task asynchronously |
| `list_sessions` | List all active sessions |
| `get_session` | Get session ID for a project directory |
| `remove_session` | Remove a session mapping |
| `check_env` | Validate environment configuration |
| `test_notification` | Send test notification |

## Quick Start

```bash
# 1. Set API key
export ANTHROPIC_API_KEY="sk-xxx"

# 2. Install hooks (one-time setup)
./main.sh install-hooks

# 3. Run a task
./main.sh invoke "Create a snake game" /path/to/project
```

## Setup

### Prerequisites

```bash
# Install dependencies
sudo apt-get install jq curl      # Ubuntu/Debian
brew install jq curl              # macOS
npm install -g @anthropic-ai/claude-cli
```

### Configuration

Configuration priority: **Environment Variables > settings.json > Defaults**

| Priority | Source | Use Case |
|----------|--------|----------|
| 1 (Highest) | Environment variables | API keys, secrets, temporary overrides |
| 2 | `config/settings.json` | Team-shared configuration |
| 3 (Lowest) | Built-in defaults | Default values if not configured |

**Environment variables** (recommended for secrets):

```bash
export ANTHROPIC_API_KEY="sk-xxx"       # Required
export ANTHROPIC_BASE_URL="https://..." # Optional
export ANTHROPIC_MODEL="claude-sonnet-4-6" # Optional
```

**Config file** (`config/settings.json`):

```json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "claude-sonnet-4-6",
  "notify": {
    "channels": ["feishu"],
    "feishu": { "chat_id": "user:ou_xxx" }
  }
}
```

> **Tip:** Use environment variables for sensitive data (API keys) and `settings.json` for shareable configuration (notification channels).

## Usage

```bash
# Auto session (recommended)
./main.sh invoke "Fix login bug" /path/to/project

# Force new session
./main.sh invoke "Refactor module" /path/to/project new

# Custom session ID
./main.sh invoke "Hotfix" /path/to/project hotfix-001

# Manage sessions
./main.sh list-sessions
./main.sh get-session /path/to/project
./main.sh remove-session /path/to/project

# Check environment
./main.sh check-env

# Test notification
./main.sh test-notify
```

## Notification Channels

Configure in `config/settings.json`:

**Feishu:**
```json
{"notify": {"channels": ["feishu"], "feishu": {"chat_id": "user:ou_xxx"}}}
```

**Discord:**
```json
{"notify": {"channels": ["discord"], "discord": {"webhook_url": "https://discord.com/api/webhooks/..."}}}
```

**Telegram:**
```json
{"notify": {"channels": ["telegram"], "telegram": {"bot_token": "123456:ABC...", "chat_id": "@channel"}}}
```

## Workflow

```
Invoke task → Validate env → Get/Create session → Start notification
    ↓
Run Claude Code in background → Task completes → Hook triggers
    ↓
Send completion notification → Write results
```

## Output Files

Default: `~/.openclaw/data/claude-code-results/`

| File | Description |
|------|-------------|
| `task-output.txt` | Full Claude Code output |
| `task-meta.json` | Task metadata (status, exit code) |

## Troubleshooting

```bash
# Check environment
./main.sh check-env

# Test notification
./main.sh test-notify

# Reinstall hooks
./main.sh remove-hooks && ./main.sh install-hooks
```
