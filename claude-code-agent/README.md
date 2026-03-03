# Claude Code Agent Teams Skill

使用 Claude Code 的 Agent Teams 模式异步执行编码任务，带 Session 管理和自动通知。

## 功能特点

- ✅ **异步执行** - 任务后台运行，不阻塞当前对话
- ✅ **Agent Teams** - 多 Agent 协作，适合复杂项目
- ✅ **Session 管理** - 自动维护项目会话，上下文连续
- ✅ **自动通知** - 完成后自动发送 Feishu 消息
- ✅ **双通道架构** - latest.json + pending-wake.json + 即时通知

## 使用方法

### 基础用法（自动 Session 管理）

```bash
export ANTHROPIC_API_KEY="sk-xxx"
export OPENCLAW_GATEWAY_TOKEN="xxx"

# 首次调用：自动创建 session
./invoke.sh "创建落沙游戏" /path/to/project

# 后续调用：自动复用 session
./invoke.sh "修改水颜色" /path/to/project
```

### Session ID 选项

| 参数 | 说明 |
|------|------|
| `auto`（默认） | 自动管理：首次创建，后续复用 |
| `new` | 强制创建新 session |
| `<custom-id>` | 使用自定义 session ID |

### 示例

```bash
# 自动管理（推荐）
./invoke.sh "修改落沙游戏的水流速度" /root/.openclaw/workspace/sand-simulator

# 强制新建 session
./invoke.sh "重构整个项目" /path/to/project new

# 使用自定义 session
./invoke.sh "修复 bug" /path/to/project hotfix-001

# 简写（使用默认 workspace）
./invoke.sh "添加测试用例"
```

## Session 管理

### 查看当前 Sessions

```bash
./session-manager.sh list
```

输出示例：
```json
{
  "/root/.openclaw/workspace/sand-simulator": "session-1772374705-12345",
  "/root/.openclaw/workspace/games/snake": "session-1772371814-67890"
}
```

### 手动管理 Sessions

```bash
# 获取 session_id
./session-manager.sh get /path/to/project

# 创建新 session
./session-manager.sh set /path/to/project

# 删除映射
./session-manager.sh remove /path/to/project
```

## 工作流程

```
用户调用 invoke.sh
    ↓
Session Manager 查询/创建 session_id
    ↓
启动 Claude Code Agent Teams（后台）
    ↓
任务完成 → Hook 触发
    ↓
1. 写入 latest.json（完整结果）
2. 发送 Feishu 通知（摘要）
3. 写入 pending-wake.json（唤醒标记）
4. 调用 Gateway wake API（立即唤醒）
    ↓
OpenClaw 读取结果，处理完成
```

## 输出文件

所有结果保存在 `/home/ubuntu/clawd/data/claude-code-results/`

| 文件 | 说明 |
|------|------|
| `task-output.txt` | Claude Code 完整输出 |
| `task-meta.json` | 任务元数据（状态、时间等） |
| `latest.json` | 完整结果 JSON（含 session_id） |
| `pending-wake.json` | 唤醒标记（供 OpenClaw 读取） |
| `hook.log` | Hook 执行日志 |

## 配置

编辑 `config/settings.json`：

```json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "kimi-k2.5",
  "feishu_chat_id": "user:ou_xxx",
  "result_dir": "/home/ubuntu/clawd/data/claude-code-results"
}
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_API_KEY` | 阿里云百炼 API Key（必需） |
| `OPENCLAW_GATEWAY_TOKEN` | OpenClaw Gateway Token（用于 wake API） |

## 典型使用场景

### 1. 游戏开发（连续迭代）

```bash
# 第一次：创建游戏
./invoke.sh "创建一个落沙模拟器，包含沙子、水、火、石头" /path/to/game

# 第二次：修改水流
./invoke.sh "让水流得更快一些" /path/to/game

# 第三次：调整火焰
./invoke.sh "火焰颜色改成橙红色" /path/to/game
```

### 2. Web 应用开发

```bash
./invoke.sh "创建 TODO 应用，FastAPI + SQLite" /path/to/todo
./invoke.sh "添加用户登录功能" /path/to/todo
./invoke.sh "添加 API 测试用例" /path/to/todo
```

### 3. 项目重构

```bash
./invoke.sh "重构用户模块，提取服务层" /path/to/project new
```

## 注意事项

1. **首次运行需要设置 API Key**
2. **Session 按工作目录隔离** - 不同项目自动使用不同 session
3. **异步模式** - 任务启动后可以继续聊天，完成后会收到通知
4. **复杂任务可能需要 5-10 分钟**

## 文件结构

```
claude-code-agent/
├── SKILL.md              # 技能说明（本文件）
├── scripts/
│   ├── invoke.sh         # 主调用脚本
│   ├── session-manager.sh # Session 管理
│   └── notify-hook.sh    # Hook 通知脚本
├── config/
│   └── settings.json     # 配置文件
└── data/
    └── sessions.json     # Session 映射（自动生成）
```
