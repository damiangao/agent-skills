# Claude Code Agent Teams

Execute coding tasks asynchronously using Claude Code Agent Teams with automatic multi-channel notifications (Feishu, Discord, Telegram).

## Features

- **Asynchronous Execution** - Run tasks in the background without blocking your terminal
- **Session Management** - Automatic session creation and reuse per project directory
- **Multi-Channel Notifications** - Get notified via Feishu, Discord, or Telegram
- **Agent Teams Support** - Leverage Claude Code's experimental Agent Teams feature
- **Configurable** - Environment variables or JSON configuration file

## Quick Start

### 1. Set Environment Variables

```bash
export ANTHROPIC_API_KEY="sk-xxx"
export OPENCLAW_GATEWAY_TOKEN="xxx"  # Optional, for wake notification
```

### 2. Install Hooks (One-Time Setup)

```bash
./scripts/install-hooks.sh install
```

### 3. Run Your First Task

```bash
./scripts/invoke.sh "Create a snake game" /path/to/project
```

## Installation

### Prerequisites

- **Bash 4.0+** - Modern bash shell
- **jq** - JSON processor
- **curl** - HTTP client
- **Claude Code CLI** - `claude` command

### Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq curl

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-cli
```

### Verify Installation

```bash
# Check all dependencies
./lib/validate.sh check

# Test notifications
./lib/notify.sh test
```

## Configuration

Configuration follows priority order: **Environment Variables > Config File > Default Values**

### Option 1: Environment Variables (Recommended for Secrets)

```bash
# Required
export ANTHROPIC_API_KEY="sk-xxx"

# Optional
export ANTHROPIC_BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
export ANTHROPIC_MODEL="claude-sonnet-4-6"
export OPENCLAW_GATEWAY_TOKEN="xxx"
```

### Option 2: Configuration File

Initialize the default configuration:

```bash
./lib/config.sh init
```

Edit `config/settings.json`:

```json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "claude-sonnet-4-6",
  "result_dir": "/root/.openclaw/data/claude-code-results",
  "notify": {
    "channels": ["feishu", "discord"],
    "feishu": {
      "chat_id": "user:ou_xxx"
    },
    "discord": {
      "webhook_url": "https://discord.com/api/webhooks/...",
      "username": "Claude Code Team"
    },
    "telegram": {
      "bot_token": "123456:ABC-DEF...",
      "chat_id": "@channel_name"
    }
  },
  "agent_teams": {
    "enabled": true,
    "teammate_mode": "auto"
  }
}
```

### View Current Configuration

```bash
./lib/config.sh list
```

## Usage

### Basic Command

```bash
./scripts/invoke.sh "Task Description" [Working Directory] [Session Option]
```

### Parameters

| Position | Parameter | Description | Default |
|----------|-----------|-------------|---------|
| 1 | Task Description | The task to execute (required) | - |
| 2 | Working Directory | Project directory | `~/claude-code-projects` |
| 3 | Session Option | `auto`, `new`, or custom ID | `auto` |

### Session Options

- **auto** (default) - Automatically create session on first run, reuse on subsequent runs
- **new** - Force create a new session
- **<custom-id>** - Use a specific session ID

### Examples

```bash
# Auto session management (recommended)
./scripts/invoke.sh "Create a React todo app" /path/to/project

# Force new session
./scripts/invoke.sh "Refactor authentication module" /path/to/project new

# Custom session ID
./scripts/invoke.sh "Hotfix for login bug" /path/to/project hotfix-001

# Quick task with default directory
./scripts/invoke.sh "Write a fibonacci function in Python"
```

## Notification Channels

### Feishu (Lark)

Requires `openclaw` CLI installed.

```json
{
  "notify": {
    "channels": ["feishu"],
    "feishu": {
      "chat_id": "user:ou_xxx"
    }
  }
}
```

### Discord

1. Go to Server Settings → Integrations → Webhooks
2. Click "New Webhook"
3. Copy the webhook URL

```json
{
  "notify": {
    "channels": ["discord"],
    "discord": {
      "webhook_url": "https://discord.com/api/webhooks/...",
      "username": "Claude Code Team"
    }
  }
}
```

### Telegram

1. Create a bot: Talk to [@BotFather](https://t.me/botfather)
2. Get the bot token
3. Send a message to your bot
4. Get chat ID: `https://api.telegram.org/bot<token>/getUpdates`

```json
{
  "notify": {
    "channels": ["telegram"],
    "telegram": {
      "bot_token": "123456:ABC-DEF...",
      "chat_id": "@channel_name or 123456789"
    }
  }
}
```

### Multiple Channels

```json
{
  "notify": {
    "channels": ["feishu", "discord", "telegram"]
  }
}
```

## Session Management

View and manage sessions:

```bash
# List all sessions
./scripts/session-manager.sh list

# Get session for a directory
./scripts/session-manager.sh get /path/to/project

# Create new session
./scripts/session-manager.sh set /path/to/project

# Remove session mapping
./scripts/session-manager.sh remove /path/to/project

# Smart get or create
./scripts/session-manager.sh get-or-create /path/to/project
```

## Hook Management

Install and manage notification hooks:

```bash
# Install hooks
./scripts/install-hooks.sh install

# Check hook status
./scripts/install-hooks.sh status

# Remove hooks
./scripts/install-hooks.sh remove
```

## Output Files

Results are saved to the configured `result_dir` (default: `~/.openclaw/data/claude-code-results/`):

| File | Description |
|------|-------------|
| `task-output.txt` | Full Claude Code output |
| `task-meta.json` | Task metadata (status, exit code, timestamps) |
| `latest.json` | Complete result JSON |
| `pending-wake.json` | Wake marker for OpenClaw Gateway |

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. User invokes script                                     │
│         ↓                                                   │
│  2. Environment validation                                  │
│         ↓                                                   │
│  3. Session manager queries/creates session_id            │
│         ↓                                                   │
│  4. Send start notification to all channels               │
│         ↓                                                   │
│  5. Launch Claude Code Agent Teams (background)           │
│         ↓                                                   │
│  6. Task completes → Hook triggers                         │
│         ↓                                                   │
│  7. Write results + Send notifications                    │
│         ↓                                                   │
│  8. User receives notification with summary               │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Environment Check Failed

```bash
# Run full validation
./lib/validate.sh check

# Check specific component
./lib/validate.sh command claude
./lib/validate.sh env ANTHROPIC_API_KEY
```

### Notification Not Received

```bash
# Test notification manually
./lib/notify.sh test

# Test specific channel
./lib/notify.sh feishu "Test message"
./lib/notify.sh discord "Test message"
./lib/notify.sh telegram "Test message"
```

### Hook Not Triggering

```bash
# Check hook status
./scripts/install-hooks.sh status

# Reinstall hooks
./scripts/install-hooks.sh install

# Check Claude settings
cat ~/.claude/settings.json
```

### Task Fails to Start

1. Verify `claude` command is available: `which claude`
2. Check API key is valid: `echo $ANTHROPIC_API_KEY`
3. Ensure working directory is writable
4. Check logs: `tail -f <result_dir>/task-output.txt`

### Session Issues

```bash
# List all sessions
./scripts/session-manager.sh list

# Remove problematic session
./scripts/session-manager.sh remove /path/to/project

# Force new session
./scripts/invoke.sh "Task" /path/to/project new
```

## Project Structure

```
claude-code-team/
├── SKILL.md                    # Skill documentation
├── README.md                   # This file
├── config/
│   └── settings.json           # Configuration file
├── lib/
│   ├── config.sh              # Configuration management
│   ├── notify.sh              # Multi-channel notifications
│   └── validate.sh            # Environment validation
├── scripts/
│   ├── invoke.sh              # Main entry point
│   ├── session-manager.sh     # Session management
│   └── install-hooks.sh       # Hook installer
└── data/                      # Session data (auto-created)
    └── sessions.json
```

## Typical Use Cases

### 1. Game Development (Iterative)

```bash
# First session - create the game
./scripts/invoke.sh "Create a snake game with pygame" /path/to/snake-game

# Continue development
./scripts/invoke.sh "Add score tracking and high score display" /path/to/snake-game

# Modify mechanics
./scripts/invoke.sh "Add power-ups and different snake speeds" /path/to/snake-game
```

### 2. Web App Development

```bash
# Create app
./scripts/invoke.sh "Create a Flask REST API for todo management" /path/to/api

# Add features
./scripts/invoke.sh "Add JWT authentication to the API" /path/to/api

# Write tests
./scripts/invoke.sh "Write pytest test cases for all endpoints" /path/to/api
```

### 3. Project Refactoring

```bash
# Long-running refactoring
./scripts/invoke.sh "Extract service layer from controllers" /path/to/project new
```

### 4. Background Tasks

```bash
# Start task and continue other work
./scripts/invoke.sh "Generate comprehensive documentation" /path/to/project

# You'll be notified when complete
```

## Security Considerations

- **API Keys**: Store in environment variables, never commit to version control
- **Webhook URLs**: Treat as secrets, rotate periodically
- **Input Validation**: Task descriptions are sanitized before execution
- **Timeout Protection**: All HTTP requests have timeout limits

## Best Practices

1. **Use meaningful session names** for long-running projects
2. **Create new sessions** for unrelated tasks
3. **Clean up old sessions** periodically
4. **Monitor notification channels** for task completion
5. **Review task output** for debugging

## Related Tools

- [Claude Code CLI](https://github.com/anthropics/claude-cli)
- [OpenClaw](https://github.com/openclaw)
- [Mermaid Live Editor](https://mermaid.live/)

## License

MIT
