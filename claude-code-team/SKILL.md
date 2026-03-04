---
name: claude-code-team
description: Asynchronous Claude Code Agent Teams execution with session management and multi-channel notifications. Use when user wants to run coding tasks in background with automatic notifications on completion. Supports Feishu, Discord, Telegram.
---

# Claude Code Agent Teams

Execute coding tasks asynchronously using Claude Code Agent Teams with automatic multi-channel notifications (Feishu, Discord, Telegram).

## Quick Start

```bash
# 1. Set required environment variables
export ANTHROPIC_API_KEY="sk-xxx"
export OPENCLAW_GATEWAY_TOKEN="xxx"  # Optional, for wake notification

# 2. Install hooks (one-time setup)
scripts/install-hooks.sh install

# 3. Run your first task
scripts/invoke.sh "Create a snake game" /path/to/project
```

## Setup Guide

### Prerequisites

- Bash 4.0+
- `jq` - JSON processor
- `curl` - HTTP client
- Claude Code CLI (`claude` command)

```bash
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq curl
```

### Configuration

Configuration follows priority order: **Environment Variables > Config File > Default Values**

#### Method 1: Environment Variables (Recommended for Secrets)

```bash
export ANTHROPIC_API_KEY="sk-xxx"              # Required
export ANTHROPIC_BASE_URL="https://..."         # Optional
export ANTHROPIC_MODEL="kimi-k2.5"              # Optional
export OPENCLAW_GATEWAY_TOKEN="xxx"            # Optional, for wake API
```

#### Method 2: Config File (`config/settings.json`)

```bash
# Initialize default config
lib/config.sh init

# Edit config/settings.json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "kimi-k2.5",
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
      "chat_id": "@channel_name or 123456789"
    }
  }
}
```

### Verify Setup

```bash
# Check environment
lib/validate.sh check

# Test notifications
lib/notify.sh test

# List current configuration
lib/config.sh list
```

### Install/Remove Hooks

```bash
# Install notification hooks
scripts/install-hooks.sh install

# Check hook status
scripts/install-hooks.sh status

# Remove hooks
scripts/install-hooks.sh remove
```

## Usage

### Basic Usage (Auto Session Management)

```bash
scripts/invoke.sh "Create a snake game" /path/to/project
```

### Session Options

| Parameter | Description |
|-----------|-------------|
| `auto` (default) | Auto manage: create first time, reuse later |
| `new` | Force create new session |
| `<custom-id>` | Use custom session ID |

### Examples

```bash
# Auto session (recommended)
scripts/invoke.sh "Fix login bug" /path/to/project

# Force new session
scripts/invoke.sh "Refactor entire module" /path/to/project new

# Custom session ID
scripts/invoke.sh "Hotfix" /path/to/project hotfix-001
```

## Workflow

```
User invokes script
    ↓
Environment validation
    ↓
Session manager queries/creates session_id
    ↓
Send start notification to all channels
    ↓
Launch Claude Code Agent Teams (background)
    ↓
Task completes → Hook triggers
    ↓
1. Write latest.json (full result)
2. Send completion notification (all channels)
3. Write pending-wake.json (wake marker, optional)
    ↓
User receives notification with summary
```

## Session Management

Sessions are automatically managed by work directory:

```bash
# View sessions
scripts/session-manager.sh list

# Get session for directory
scripts/session-manager.sh get /path/to/project

# Remove session mapping
scripts/session-manager.sh remove /path/to/project

# Get or create (smart mode)
scripts/session-manager.sh get-or-create /path/to/project
```

## Notification Channels

### Feishu

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

Requires `openclaw` CLI installed.

### Discord

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

Get webhook URL from: Server Settings → Integrations → Webhooks → New Webhook

### Telegram

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

- Create bot: Talk to [@BotFather](https://t.me/botfather)
- Get chat ID: Send message to bot, then visit `https://api.telegram.org/bot<token>/getUpdates`

### Multiple Channels

```json
{
  "notify": {
    "channels": ["feishu", "discord", "telegram"]
  }
}
```

## Output Files

Results saved to configured `result_dir` (default: `~/.openclaw/data/claude-code-results/`):

| File | Description |
|------|-------------|
| `task-output.txt` | Full Claude Code output |
| `task-meta.json` | Task metadata |
| `latest.json` | Complete result JSON |
| `pending-wake.json` | Wake marker for OpenClaw Gateway |

## Configuration Reference

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ANTHROPIC_API_KEY` | API Key for Claude | Yes |
| `ANTHROPIC_BASE_URL` | Custom API base URL | No |
| `ANTHROPIC_MODEL` | Model to use | No |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway token for wake API | No |

### Config File Options

```json
{
  "api_base_url": "https://...",      // Claude API endpoint
  "model": "kimi-k2.5",                // Model name
  "result_dir": "/path/to/results",    // Output directory
  "notify": {
    "channels": ["feishu", "discord"], // Enabled channels
    "feishu": { "chat_id": "..." },
    "discord": { "webhook_url": "...", "username": "..." },
    "telegram": { "bot_token": "...", "chat_id": "..." }
  },
  "agent_teams": {
    "enabled": true,                   // Enable Agent Teams
    "teammate_mode": "auto"            // Auto teammate management
  }
}
```

## Troubleshooting

### Environment Check Failed

```bash
# Run full validation
lib/validate.sh check

# Check specific component
lib/validate.sh command claude
lib/validate.sh env ANTHROPIC_API_KEY
```

### Notification Not Received

```bash
# Test notification manually
lib/notify.sh test

# Test specific channel
lib/notify.sh feishu "Test message"
lib/notify.sh discord "Test message"
lib/notify.sh telegram "Test message"
```

### Hook Not Triggering

```bash
# Check hook status
scripts/install-hooks.sh status

# Reinstall hooks
scripts/install-hooks.sh install
```

## Project Structure

```
claude-code-team/
├── SKILL.md                    # This documentation
├── README.md                   # Extended documentation
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

1. **Game Development** (iterative)
   - Create game → Modify mechanics → Adjust visuals

2. **Web App Development**
   - Create app → Add features → Write tests

3. **Project Refactoring**
   - Extract modules → Improve structure → Add documentation

4. **Long-running Tasks**
   - Start task → Close terminal → Receive notification when done

## Notes

- First run requires API Key setup
- Sessions are isolated by work directory
- Async mode: continue chatting while task runs
- Complex tasks may take 5-10 minutes
- All configured notification channels receive messages
