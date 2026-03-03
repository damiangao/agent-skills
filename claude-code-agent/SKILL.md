# Claude Code Agent Teams

使用 Claude Code 的 Agent Teams 模式异步执行编码任务，完成后自动通知。

## 功能特点

- ✅ **异步执行** - 任务后台运行，不阻塞当前对话
- ✅ **Agent Teams** - 多 Agent 协作，适合复杂项目
- ✅ **自动通知** - 完成后自动发送 Feishu 消息
- ✅ **阿里云百炼** - 使用 Kimi K2.5 模型

## 使用方法

### 基础用法

```
用 Claude Code 创建一个贪吃蛇游戏
```

### 指定工作目录

```
用 Claude Code 给 /path/to/project 添加用户登录功能
```

### 复杂项目

```
用 Claude Code 开发一个完整的待办事项管理应用，包含前端和后端
```

## 工作流程

```
用户请求 → 启动 Agent Teams → 后台执行 → 完成通知
    ↓
你可以继续聊其他事情
    ↓
完成后自动收到 Feishu 消息
```

## 配置

配置文件：`config/settings.json`

```json
{
  "api_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "api_key_env": "ANTHROPIC_API_KEY",
  "model": "kimi-k2.5",
  "feishu_chat_id": "user:ou_xxx"
}
```

## 环境变量

使用前需要设置：

```bash
export ANTHROPIC_API_KEY="sk-xxx"  # 阿里云百炼 API Key
export OPENCLAW_GATEWAY_TOKEN="xxx"  # OpenClaw Gateway Token（用于发送通知）
```

或者在 `config/settings.json` 中配置 `api_key` 字段。

## 输出

任务完成后：
- 代码文件保存到指定目录
- Feishu 通知包含任务摘要
- 完整输出保存在 `/home/ubuntu/clawd/data/claude-code-results/task-output.txt`

## 示例任务

- 创建完整的游戏（贪吃蛇、俄罗斯方块等）
- 开发 Web 应用（TODO、博客、聊天室）
- 重构现有项目
- 编写测试用例
- 文档生成

## 注意事项

1. 复杂任务可能需要 5-10 分钟
2. 确保工作目录存在或有写入权限
3. 通知消息包含代码摘要，完整结果查看输出文件
