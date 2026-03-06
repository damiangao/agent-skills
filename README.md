# OpenClaw Skills

Personal OpenClaw skills collection, now open-sourced for the community.

## Skills List

### 1. Claude Code Agent Teams (claude-code-team)

**Recommended** - Enhanced Claude Code Agent Teams with async task execution and multi-channel notifications.

- **Async Execution** - Tasks run in background, non-blocking
- **Agent Teams Mode** - Multi-agent collaboration for complex projects
- **Multi-Channel Notifications** - Feishu, Discord, Telegram support
- **Session Management** - Auto-maintain project sessions, continuous context

[View Documentation](./claude-code-team/SKILL.md)

### 2. Claude Code Agent (claude-code-agent)

Basic version of Claude Code Agent Teams with async execution and Feishu notifications.

- **Async Execution** - Background task execution
- **Session Management** - Auto-maintain project sessions
- **Feishu Notifications** - Automatic completion messages

[View Documentation](./claude-code-agent/README.md)

### 3. Mermaid Render (mermaid-render)

Render Mermaid syntax to PNG/SVG images.

- **Multi-Format Support** - PNG, SVG, PDF
- **Customizable** - Background color and other parameters
- **Easy to Use** - One-line command rendering

[View Documentation](./mermaid-render/SKILL.md)

### 4. OKR Tracker (okr-tracker)

OKR 周期性追踪与提醒技能，帮助用户追踪目标进度、设置定时提醒、生成进度报告。

- **OKR 追踪** - 管理多个 OKR 目标的进度
- **周期提醒** - 每日/每周/每月定时提醒
- **进度报告** - 自动生成月度/季度汇总
- **自然语言** - 用对话方式更新进度

[View Documentation](./okr-tracker/SKILL.md)

## Quick Start

### Requirements

- Bash 4.0+
- `jq` - JSON processor
- `curl` - HTTP client
- Claude Code CLI (`claude` command)
- Python 3 (for mermaid-render)

```bash
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq curl
```

### Installation

1. Clone or download this repository
2. Deploy skills to OpenClaw workspace

```bash
# Example: Deploy to OpenClaw skills directory
cp -r claude-code-team /root/.openclaw/workspace/skills/
cp -r mermaid-render /root/.openclaw/workspace/skills/
cp -r okr-tracker /root/.openclaw/workspace/skills/
```

### Configuration

Each skill has its own config files and documentation. Refer to individual `SKILL.md` files.

Common environment variables:

```bash
export ANTHROPIC_API_KEY="sk-xxx"              # Claude API Key
export OPENCLAW_GATEWAY_TOKEN="xxx"            # OpenClaw Gateway Token (optional)
```

## Usage Examples

### Claude Code Agent Teams

```bash
# Async execute coding task
scripts/invoke.sh "Create a snake game" /path/to/project

# View sessions
scripts/session-manager.sh list
```

### Mermaid Render

```bash
# Render flowchart
python3 render.py "flowchart TD; A-->B; B-->C" output.png
```

### OKR Tracker

```bash
# View OKR status
./cli.sh status

# Update progress
./cli.sh update exercise 3

# Log daily entry
./cli.sh log "今天完成了原型设计"
```

## Directory Structure

```
agent-skills/
├── README.md                     # Project documentation
├── LICENSE                       # Apache 2.0 License
├── .gitignore                    # Git ignore config
├── IMPROVEMENTS.md               # Improvement suggestions & usage guide
├── claude-code-agent/            # Basic Agent Teams
│   ├── SKILL.md
│   ├── README.md
│   ├── scripts/
│   │   ├── invoke.sh
│   │   ├── session-manager.sh
│   │   └── notify-hook.sh
│   └── config/
│       └── settings.json
├── claude-code-team/             # Enhanced Agent Teams (recommended)
│   ├── SKILL.md
│   ├── scripts/
│   │   ├── invoke.sh
│   │   ├── session-manager.sh
│   │   └── install-hooks.sh
│   ├── lib/
│   │   ├── config.sh
│   │   ├── notify.sh
│   │   └── validate.sh
│   └── config/
│       └── settings.json
├── mermaid-render/               # Mermaid rendering tool
│   ├── SKILL.md
│   └── render.py
└── okr-tracker/                  # OKR tracking & reminders
    ├── SKILL.md
    ├── README.md
    ├── cli.sh
    ├── _meta.json
    ├── .gitignore
    ├── config/
    └── data/
```

## License

Apache License 2.0

## Contributing

Issues and Pull Requests are welcome!
