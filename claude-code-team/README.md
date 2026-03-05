# Claude Code Agent Teams

Execute coding tasks asynchronously with automatic multi-channel notifications.

## Features

- **Asynchronous Execution** - Run tasks in background without blocking terminal
- **Session Management** - Auto create/reuse sessions per project directory
- **Multi-Channel Notifications** - Feishu, Discord, Telegram support
- **Agent Teams Support** - Claude Code experimental Agent Teams

## Quick Start

```bash
# 1. Set API key
export ANTHROPIC_API_KEY="sk-xxx"

# 2. Install dependencies
sudo apt-get install jq curl && npm install -g @anthropic-ai/claude-cli

# 3. Install hooks
./main.sh install-hooks

# 4. Run a task
./main.sh invoke "Create a React todo app" /path/to/project
```

## Commands

| Command | Description |
|---------|-------------|
| `invoke <task> [workdir] [session]` | Run a coding task (session: auto\|new\|<id>) |
| `list-sessions` | List all sessions |
| `get-session <workdir>` | Get session for directory |
| `remove-session <workdir>` | Remove session |
| `check-env` | Validate environment |
| `test-notify` | Send test notification |
| `install-hooks` | Install notification hooks |
| `remove-hooks` | Remove hooks |

## Configuration

Configuration priority: **Environment Variables > settings.json > Defaults**

| Priority | Source | Use Case | Example |
|----------|--------|----------|---------|
| 1 (Highest) | Environment variables | API keys, secrets, temporary overrides | `export ANTHROPIC_API_KEY=xxx` |
| 2 | `config/settings.json` | Team-shared configuration | Notification channels |
| 3 (Lowest) | Built-in defaults | Default values if not configured | Default API endpoint |

> **Tip:** Use environment variables for sensitive data (API keys) and `settings.json` for shareable configuration (notification channels, paths).

### Environment Variables

```bash
export ANTHROPIC_API_KEY="sk-xxx"       # Required
export ANTHROPIC_BASE_URL="https://..." # Optional
export ANTHROPIC_MODEL="claude-sonnet-4-6" # Optional
```

### Config File (`config/settings.json`)

```json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "claude-sonnet-4-6",
  "result_dir": "/root/.openclaw/data/claude-code-results",
  "notify": {
    "channels": ["feishu", "discord"],
    "feishu": { "chat_id": "user:ou_xxx" },
    "discord": { "webhook_url": "https://discord.com/api/webhooks/...", "username": "Claude Code Team" },
    "telegram": { "bot_token": "123456:ABC...", "chat_id": "@channel" }
  }
}
```

## Examples

```bash
# Auto session management
./main.sh invoke "Create a snake game with pygame" /path/to/game

# Force new session
./main.sh invoke "Refactor authentication" /path/to/app new

# Custom session ID
./main.sh invoke "Hotfix" /path/to/app hotfix-001

# Check sessions
./main.sh list-sessions

# Remove a session
./main.sh remove-session /path/to/app
```

## Notification Setup

### Feishu
Requires `openclaw` CLI. Configure `chat_id` in settings.

### Discord
1. Server Settings → Integrations → Webhooks → New Webhook
2. Copy webhook URL to `notify.discord.webhook_url`

### Telegram
1. Create bot via [@BotFather](https://t.me/botfather)
2. Get chat ID: send message to bot, visit `https://api.telegram.org/bot<token>/getUpdates`
3. Configure `bot_token` and `chat_id`

## Workflow

```
┌─────────────────────────────────────────────────────────┐
│  1. User invokes task                                   │
│  2. Validate environment                                │
│  3. Get/create session (auto-managed by workdir)       │
│  4. Send start notification                             │
│  5. Launch Claude Code (background)                     │
│  6. Task completes → Hook triggers                      │
│  7. Send completion notification + summary              │
└─────────────────────────────────────────────────────────┘
```

## Output Files

Results saved to `result_dir` (default: `~/.openclaw/data/claude-code-results/`):

| File | Description |
|------|-------------|
| `task-output.txt` | Full output |
| `task-meta.json` | Metadata (status, exit code, timestamps) |

## Troubleshooting

```bash
# Check environment
./main.sh check-env

# Test notification
./main.sh test-notify

# Reinstall hooks
./main.sh remove-hooks && ./main.sh install-hooks

# View task output
tail -f ~/.openclaw/data/claude-code-results/task-output.txt
```

## License

MIT
