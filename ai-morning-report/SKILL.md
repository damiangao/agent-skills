# AI 新闻早报 Skill

自动搜索 AI 行业新闻，使用 LLM 生成精选早报，支持多渠道推送。

## 📋 功能

- 🔍 使用 baidu-search 搜索 AI 相关新闻
- 🎯 按媒体权威性智能排序（专业 AI 媒体 > 官方媒体 > 科技媒体）
- 🤖 使用 LLM 自动生成新闻摘要和洞察
- 📤 支持飞书、QQ、微信等平台推送
- ⏰ 支持 cron 定时任务

## 🚀 使用方式

### 手动运行

```bash
cd /root/.openclaw/workspace/skills/ai-morning-report/scripts
python3 generate_report.py
```

### 定时任务（推荐）

```bash
# 每天早上 9 点（北京时间）自动生成
openclaw cron add --name "AI 新闻早报" \
  --schedule "0 9 * * *" \
  --tz "Asia/Shanghai" \
  --command "python3 /root/.openclaw/workspace/skills/ai-morning-report/scripts/generate_report.py"
```

## ⚙️ 配置

### 环境变量

```bash
# LLM 配置（必填）
export LLM_API_URL="https://your-api-endpoint.com/v1/messages"
export LLM_API_KEY="your-api-key"
export LLM_MODEL="MiniMax-M2.5"

# 推送配置（可选，默认使用当前会话渠道）
export DELIVERY_CHANNEL="feishu"
export DELIVERY_TARGET="user:ou_xxx"
```

### 搜索关键词

编辑 `generate_report.py` 中的 `CONFIG["QUERIES"]`：

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

编辑 `search_news.py` 中的 `CONFIG["MEDIA_CATEGORIES"]`，支持自定义媒体分类和权重。

## 📝 输出格式

```
📰 今日 AI 新闻早报（3 月 8 日）
📰 早报字数：约 1500 字 | ⏱️ 预估阅读时间：5 分钟

---

⭐⭐⭐⭐⭐ | [标题](链接)
简述：xxx
我的理解：xxx
来源：xxx | 日期

---
```

## 🔧 依赖

- Python 3.8+
- baidu-search skill
- requests 库

## 📁 文件说明

- `scripts/generate_report.py` - 早报生成主脚本
- `scripts/search_news.py` - 新闻搜索、去重、排序
- `README.md` - 详细文档

## 💡 提示

- 早报会自动过滤广告内容和旧闻（仅保留 3 天内）
- 支持多个推送渠道，可自定义
- 建议搭配 cron 使用，实现自动化
