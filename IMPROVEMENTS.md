# Improvements

This document contains code review analysis and improvement suggestions for future optimization.

---

## claude-code-agent

### Current Status
- Basic async task execution capability
- Session management functionality
- Feishu notification support

### Suggested Improvements

#### 1. Hardcoded Paths
**Files**: `scripts/invoke.sh`, `scripts/notify-hook.sh`

Multiple uses of hardcoded path `/home/ubuntu/clawd/data/claude-code-results`. Recommendations:
- Use environment variables or config files for path management
- Allow user customization while providing defaults

#### 2. Insufficient Error Handling
**File**: `scripts/invoke.sh`

- Missing retry mechanism for API call failures
- User-unfriendly error messages when environment variables are missing
- Add comprehensive error handling and user prompts

#### 3. Session Persistence
**File**: `data/sessions.json`

- Session data stored in temporary location, may be lost after restart
- Support persisting session data to user-specified directory

---

## claude-code-team

### Current Status
- Enhanced multi-channel notifications (Feishu/Discord/Telegram)
- Modular library file structure
- Comprehensive environment validation

### Suggested Improvements

#### 1. Config File Initialization
**File**: `lib/config.sh`

The `init` command creates default config that still requires manual editing. Recommendations:
- Provide interactive configuration wizard
- Or create config template files for user reference

#### 2. Notification Module Reusability
**File**: `lib/notify.sh`

Notification logic is hardcoded in the script. Recommendations:
- Support plugin-style notification channel extension
- Abstract notification logic as independent module

#### 3. Validation Script Completeness
**File**: `lib/validate.sh`

The `check` command validates all environments, but:
- Missing checks for optional dependencies (e.g., puppeteer for mermaid-render)
- Add `--quick` mode to check only required items

#### 4. Documentation Consistency
**File**: `SKILL.md`

Chinese and English documentation differ. Recommendations:
- Unify as bilingual docs or keep synchronized updates
- Ensure config examples match actual code

---

## mermaid-render

### Current Status
- Basic Mermaid rendering functionality
- Multi-format output support (PNG/SVG/PDF)

### Suggested Improvements

#### 1. Dependency Installation Instructions
**File**: `SKILL.md`

Dependency installation steps are minimal. Add:
- Windows/macOS installation guide
- Docker containerized deployment option (optional)

#### 2. Error Handling
**File**: `render.py`

- Missing error handling for invalid Mermaid syntax
- Add syntax validation and friendly error prompts

#### 3. Performance Optimization
**File**: `render.py`

- Each render starts a new puppeteer instance, high overhead
- Support persistent connection mode or reuse browser instance

#### 4. Output Directory
**File**: `render.py`

- Default output to `/tmp/`, users may not find it
- Default to current working directory instead

---

## General Suggestions

### 1. Test Coverage
All three skills lack automated testing. Recommendations:
- Add unit tests (especially for core logic)
- Add integration test scripts
- Provide test data samples

### 2. Version Management
- Consider adding version numbers to each skill
- Use semantic versioning (SemVer)
- Provide changelog (CHANGELOG.md)

### 3. Example Projects
- Provide example working directories and config files
- Add "5-minute quick start" tutorial
- Create demo videos or GIFs

### 4. Cross-Platform Support
- Currently mainly targeting Linux
- Add Windows and macOS compatibility testing
- Provide platform-specific installation scripts

### 5. Security Considerations
- Use encrypted storage for API Keys
- Don't write sensitive info to logs
- Add permission checks (e.g., file write permissions)

### 6. Observability
- Add log level control (DEBUG/INFO/WARN/ERROR)
- Support log output to file
- Provide debug mode switch

---

## Priority Recommendations

### High Priority
1. Fix hardcoded path issues (claude-code-agent)
2. Improve error handling and user prompts
3. Unify Chinese/English documentation

### Medium Priority
4. Add automated testing
5. Improve config file management
6. Cross-platform compatibility

### Low Priority
7. Performance optimization (mermaid-render browser reuse)
8. Plugin-style architecture extension
9. Example projects and tutorial videos

---

## Summary

Overall, these three skills have a solid functional foundation:
- **claude-code-team** is the most complete, recommended for primary use
- **claude-code-agent** can serve as a lightweight alternative
- **mermaid-render** is practical but needs error handling improvements

After addressing high-priority issues, ready for community release.

---

## Appendix: How to Use These Skills

### Method 1: Deploy to OpenClaw (Recommended)

OpenClaw is a skill management platform that supports auto-loading and managing skills.

#### 1. Clone or Download Skills

```bash
# Clone the entire repository
git clone https://github.com/YOUR_USERNAME/agent-skills.git ~/.openclaw/workspace/skills/agent-skills

# Or download a single skill
git clone https://github.com/YOUR_USERNAME/agent-skills.git --depth 1
cp -r agent-skills/claude-code-team ~/.openclaw/workspace/skills/
cp -r agent-skills/mermaid-render ~/.openclaw/workspace/skills/
```

#### 2. Configure Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
export ANTHROPIC_API_KEY="sk-xxx"
export OPENCLAW_GATEWAY_TOKEN="xxx"  # Optional, for notification wake-up
```

#### 3. Install Dependencies

```bash
# Required for Claude Code Agent Teams
sudo apt-get install jq curl

# Required for Mermaid Render
npm install -g @mermaid-js/mermaid-cli
echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > ~/.puppeteer.json
```

#### 4. Enable in OpenClaw

After starting OpenClaw, skills will auto-load. Verify with:

```bash
# View loaded skills
openclaw skills list
```

---

### Method 2: Use Directly in Claude Code

If you use Claude Code CLI, you can call skill scripts directly.

#### 1. Download Skills

```bash
git clone https://github.com/YOUR_USERNAME/agent-skills.git ~/skills
```

#### 2. Configure Skill Path

Add skill path in Claude Code config, or use aliases:

```bash
# Add Shell aliases
alias claude-team='~/skills/claude-code-team/scripts/invoke.sh'
alias mermaid-render='python3 ~/skills/mermaid-render/render.py'
```

#### 3. Use Directly

```bash
# Async execute coding task
~/skills/claude-code-team/scripts/invoke.sh "Create a snake game" /path/to/project

# Render Mermaid diagram
python3 ~/skills/mermaid-render/render.py "flowchart TD; A-->B" output.png
```

---

### Method 3: Install as System Skills (Advanced)

Install skills to system path for global availability.

#### 1. Install to /opt

```bash
sudo cp -r claude-code-team /opt/openclaw-skills/
sudo cp -r mermaid-render /opt/openclaw-skills/
```

#### 2. Create Symbolic Links

```bash
sudo ln -s /opt/openclaw-skills/claude-code-team/scripts/invoke.sh /usr/local/bin/claude-team
sudo ln -s /opt/openclaw-skills/mermaid-render/render.py /usr/local/bin/mermaid-render
```

#### 3. Use Globally

```bash
# Now available from any directory
claude-team "Fix login bug" /path/to/project
mermaid-render "graph LR; A-->B" result.png
```

---

### Configuration File Examples

#### Claude Code Agent Teams Config

Edit `claude-code-team/config/settings.json`:

```json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "kimi-k2.5",
  "result_dir": "/home/user/.openclaw/data/claude-code-results",
  "notify": {
    "channels": ["feishu"],
    "feishu": {
      "chat_id": "user:ou_xxx"
    }
  }
}
```

#### Environment Variables (Recommended)

```bash
# ~/.bashrc or ~/.zshrc
export ANTHROPIC_API_KEY="sk-xxx"
export ANTHROPIC_MODEL="kimi-k2.5"
export OPENCLAW_WORKSPACE="/home/user/.openclaw/workspace"
```

---

### FAQ

**Q: Skills not working?**

A: Check the following:
1. Ensure skills directory is in OpenClaw workspace's `skills/` subdirectory
2. Confirm `SKILL.md` file exists and format is correct
3. Restart OpenClaw or Claude Code

**Q: How to debug a skill?**

A: Enable debug mode:
```bash
export DEBUG=1
scripts/invoke.sh "test" /path/to/project
```

**Q: Notifications not sending?**

A: Check configuration and credentials:
```bash
# Test notification
lib/notify.sh test

# Check environment
lib/validate.sh check
```
