# AI 新闻早报 📰

一个基于 OpenClaw 的自动化 AI 新闻聚合工具，每天 9:00 自动生成并推送精选 AI 行业早报。

**已稳定运行 2 个月**，每天自动推送 10 条精选新闻 + 深度洞察。

---

## ✨ 核心功能

- 🔍 **多源搜索** - 9 个关键词覆盖 AI 全领域（大模型、自动驾驶、Agent、机器人）
- 🎯 **权威排序** - 媒体权重算法（机器之心 100 分 > 36 氪 60 分 > 百家号 5 分）
- 🤖 **AI 总结** - LLM 生成 80-100 字简述 + 1-2 句深度洞察
- 📤 **自动推送** - 飞书机器人定时推送（每天 9:00）
- ⏰ **Cron Job** - OpenClaw 原生定时任务，无需额外配置

---

## 📁 项目结构

```
ai-morning-report/
├── README.md                  # 项目说明（本文件）
├── SKILL.md                   # OpenClaw Skill 使用手册
├── requirements.txt           # Python 依赖
└── scripts/
    └── generate_report.py     # 早报生成脚本（搜索 + 排序 + 去重）
```

---

## 🚀 快速开始

### 前置条件

- OpenClaw 2026.2.26+
- Python 3.8+

### 安装

```bash
cd /root/.openclaw/workspace/skills/ai-morning-report
pip install -r requirements.txt
```

### 配置 Cron Job

编辑 `~/.openclaw/cron/jobs.json`，添加：

```json
{
  "name": "AI 新闻早报",
  "enabled": true,
  "schedule": {
    "kind": "cron",
    "expr": "0 9 * * *",
    "tz": "Asia/Shanghai"
  },
  "payload": {
    "message": "【每日自动调用】请执行 AI 新闻早报 Skill：\n\n1. 运行脚本：python3 generate_report.py\n2. 读取 JSON：cat ai_news_raw.json\n3. 生成早报：按模板生成\n4. 发送给用户：openclaw message send --channel feishu --target user:YOUR_USER_ID --message \"早报内容\""
  },
  "delivery": {
    "mode": "announce",
    "channel": "feishu",
    "target": "user:YOUR_USER_ID"
  }
}
```

**替换 `YOUR_USER_ID`** 为你的飞书用户 ID（如 `ou_xxxxxxxxxxxx`）。

### 测试运行

```bash
# 手动运行
python3 scripts/generate_report.py

# 查看输出
cat /root/.openclaw/workspace/ai_news_raw.json | head -50

# 测试 Cron Job
openclaw cron run "AI 新闻早报"
```

---

## 📝 输出示例

```
📰 今日 AI 新闻早报（3 月 14 日）
📰 早报字数：约 1800 字 | ⏱️ 预估阅读时间：6 分钟

---

⭐⭐⭐⭐⭐ | 上海打造全球首个人形机器人零部件中试平台
**📝 简述**：上海在 2026 全球投资促进大会上宣布打造全球首个人形机器人零部件中试平台，围绕关节模组、减速器等 5 类零部件搭建小批量试制线，提供 72 项测试验证。
**💡 我的理解**：这是人形机器人产业化的重要基础设施，意味着中国正在从"造机器人"向"造好机器人"转变。
**📰 来源**：财联社 | 2026-03-14

---

（重复 10 条）

---

💡 我的观察：

1. **产业化加速**：上海人形机器人中试平台落地，标志着从实验室走向规模化生产。
2. **内容创作拐点**：AI 短剧成本仅为真人 1/4，但"活人气息"仍是人类优势。
3. **AGI 竞赛升级**：量化巨头幻方孵化 DeepSeek，追求通用人工智能。
4. **社会适应期**：从"AI 焦虑"到"先用起来"，政策层面开始系统性应对。

---

*每天早上 9 点自动推送*
```

---

## ⚙️ 配置说明

### 搜索关键词

编辑 `scripts/generate_report.py`：

```python
"TOPIC_QUERIES": [
    "AI 大模型",
    "人工智能 自动驾驶",
    "AI 智能体 Agent",
    "人形机器人",
    "OpenAI 谷歌 英伟达"
]
```

### 媒体权重

```python
"MEDIA_WEIGHTS": {
    100: ['机器之心', '新智元', '量子位'],      # 专业 AI 媒体
    80:  ['新华社', '人民日报', '央视新闻'],    # 官方媒体
    60:  ['36 氪', '钛媒体', '虎嗅'],           # 科技媒体
    40:  ['新浪科技', '网易科技', '腾讯科技'],  # 主流门户
    5:   ['百家号', '搜狐号', '头条号']         # 自媒体（过滤）
}
```

### 过滤规则

- ✅ 保留：专业 AI 媒体、官方媒体、科技媒体
- ❌ 过滤：百家号、搜狐号等自媒体（权重 < 10）
- ✅ 去重：基于标题相似度（threshold=0.9）
- ✅ 时效：仅保留最近 3 天内的新闻

---

## 🏗️ 技术架构

```
┌─────────────────────┐
│  generate_report.py │  ← Python 脚本（数据生成）
│  (每天运行一次)      │
└──────────┬──────────┘
           │
           ↓ 写入
┌─────────────────────┐
│ ai_news_raw.json    │  ← 数据缓存（50 条新闻）
│ (数据缓存)          │
└──────────┬──────────┘
           │
           ↓ 读取
┌─────────────────────┐
│  Cron Job (9:00)    │  ← OpenClaw 定时触发
└──────────┬──────────┘
           │
           ↓ Prompt
┌─────────────────────┐
│  OpenClaw LLM       │  ← 筛选 10 条 + 生成洞察
└──────────┬──────────┘
           │
           ↓ message 工具
┌─────────────────────┐
│  飞书推送           │  ← 最终输出
└─────────────────────┘
```

### 核心设计思想

1. **数据生成与总结分离**
   - Python 脚本：搜索、排序、去重、过滤（精确控制）
   - LLM：总结、格式化、洞察生成（发挥语言优势）

2. **数据缓存策略**
   - 生成一次，多次使用
   - Cron Job 直接读取 JSON，无需重复搜索
   - 便于调试和回溯

3. **媒体权威性排序**
   - 权重算法确保高质量新闻优先
   - 过滤低质自媒体内容

---

## 📊 运行统计

| 指标 | 数值 |
|------|------|
| **运行时长** | ~60 秒/次 |
| **新闻数量** | 50 条/天 |
| **推送条数** | 10 条/天 |
| **Token 消耗** | ~200k/次 |
| **稳定运行** | 2 个月+ |

---

## 🔧 调试技巧

### 查看生成的数据

```bash
cat /root/.openclaw/workspace/ai_news_raw.json | python3 -m json.tool | head -100
```

### 查看 Cron Job 状态

```bash
openclaw cron list | grep "AI 新闻早报"
```

### 手动触发

```bash
openclaw cron run "AI 新闻早报"
```

### 查看日志

```bash
tail -100 ~/.openclaw/logs/openclaw.log | grep "AI 新闻早报"
```

---

## 🤝 贡献

欢迎提交 Issue 和 PR！

---

## 📄 License

MIT License

---

**Made with ❤️ by OpenClaw Community**
