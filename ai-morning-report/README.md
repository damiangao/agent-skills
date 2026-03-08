# AI 新闻早报 📰

一个基于 AI 的自动化新闻聚合工具，每天自动生成精选 AI 行业早报。

## ✨ 功能特点

- 🔍 **多源搜索**：自动搜索 AI、大模型、自动驾驶、机器人等领域新闻
- 🎯 **智能筛选**：按媒体权威性排序，优先选择专业 AI 媒体和官方媒体
- 🤖 **AI 总结**：使用 LLM 自动生成新闻摘要和洞察
- 📤 **多渠道推送**：支持飞书、QQ、微信等平台自动推送
- ⏰ **定时任务**：支持 cron 定时运行，每天自动生成

## 📁 项目结构

```
ai-morning-report/
├── README.md              # 项目说明
├── SKILL.md               # OpenClaw Skill 描述
├── requirements.txt       # Python 依赖
└── scripts/
    ├── generate_report.py # 早报生成主脚本
    └── search_news.py     # 新闻搜索与处理
```

## 🚀 快速开始

### 前置条件

1. Python 3.8+
2. OpenClaw 环境
3. baidu-search skill（用于新闻搜索）

### 安装依赖

```bash
cd /root/.openclaw/workspace/skills/ai-morning-report
pip install -r requirements.txt
```

### 配置环境变量

```bash
# LLM 配置
export LLM_API_URL="https://your-api-endpoint.com/v1/messages"
export LLM_API_KEY="your-api-key"
export LLM_MODEL="MiniMax-M2.5"

# 推送配置（可选）
export DELIVERY_CHANNEL="feishu"  # feishu, qqbot, wechat 等
export DELIVERY_TARGET="user:xxx"  # 推送目标用户/频道
```

### 运行

```bash
# 手动运行
python3 scripts/generate_report.py

# 或通过 OpenClaw cron 定时运行
openclaw cron add --name "AI 新闻早报" --schedule "0 1 * * *" \
  --command "cd /root/.openclaw/workspace/skills/ai-morning-report && python3 scripts/generate_report.py"
```

## 📝 输出格式

```
📰 今日 AI 新闻早报（3 月 8 日）
📰 早报字数：约 1500 字 | ⏱️ 预估阅读时间：5 分钟

---

⭐⭐⭐⭐⭐ | [医疗 AI：「红房子·启元」妇产科大模型发布](https://...)
简述：复旦大学附属妇产科医院发布「红房子·启元」妇产科垂直大模型
我的理解：医疗 AI 向垂直领域深入，专科大模型成为新趋势
来源：机器之心 | 2026-03-08

---
```

## ⚙️ 配置说明

### 搜索关键词

在 `generate_report.py` 中配置 `CONFIG["QUERIES"]`：

```python
"QUERIES": [
    "AI 大模型",
    "人工智能 自动驾驶",
    "AI 智能体 Agent",
    "人形机器人",
    "OpenAI 谷歌 英伟达",
]
```

### 媒体优先级

在 `search_news.py` 中配置 `CONFIG["MEDIA_CATEGORIES"]`，支持自定义媒体分类和权重。

### 新闻筛选

- 自动过滤广告内容
- 自动去重（基于标题相似度）
- 仅保留最近 3 天内的新闻
- 按媒体权威性排序

## 🔌 集成方式

### OpenClaw Cron

```json
{
  "name": "AI 新闻早报",
  "schedule": {
    "kind": "cron",
    "expr": "0 9 * * *",
    "tz": "Asia/Shanghai"
  },
  "command": "python3 /root/.openclaw/workspace/skills/ai-morning-report/scripts/generate_report.py"
}
```

### API 调用

```bash
# 生成早报并获取 JSON 输出
python3 scripts/search_news.py > news.json

# 使用自定义 LLM 处理
python3 scripts/generate_report.py --input news.json
```

## 🛠️ 开发指南

### 添加新的新闻源

修改 `search_news.py` 中的 `MEDIA_CATEGORIES` 配置。

### 自定义输出格式

修改 `generate_report.py` 中的 LLM prompt 模板。

### 支持新的推送渠道

在 `send_to_feishu()` 函数基础上，添加新的推送方法。

## 📄 License

MIT License

## 🤝 贡献

欢迎提交 Issue 和 PR！

---

**Made with ❤️ by OpenClaw Community**
