# AI 新闻早报 Skill

## 功能

每日自动推送 AI 新闻早报给用户：
1. 搜索 AI 新闻（9 个关键词）
2. 按媒体权威性排序、去重
3. 生成早报（10 条新闻 + 洞察 + 趋势分析）
4. 发送给用户（飞书/钉钉等渠道）

## 最佳实践

### 1. Cron Job 定时推送（推荐）

**配置**（`~/.openclaw/cron/jobs.json`）：

```json
{
  "name": "AI 新闻早报",
  "enabled": true,
  "schedule": {"kind": "cron", "expr": "0 9 * * *", "tz": "Asia/Shanghai"},
  "payload": {
    "message": "【每日自动调用】请执行 AI 新闻早报 Skill：\n\n1. 运行脚本：python3 generate_report.py\n2. 读取 JSON：cat ai_news_raw.json\n3. 生成早报：按模板生成\n4. 发送给用户：openclaw message send --channel feishu --target user:YOUR_USER_ID --message \"早报内容\""
  },
  "delivery": {"mode": "announce", "channel": "feishu", "target": "user:YOUR_USER_ID"}
}
```

**说明**：
- `payload.message`: 必须明确使用 `openclaw message send` 命令（isolated session 需要）
- `delivery`: 备用配置（主会话时有用）
- `YOUR_USER_ID`: 替换为你的用户 ID（如 `ou_xxxxxxxxxxxx`）

**注意**：Cron Job 使用 isolated session，`delivery` 配置可能不生效，必须在 `payload.message` 中明确使用 `message` 工具。

### 2. 单次执行

```bash
# Step 1: 运行脚本
python3 generate_report.py

# Step 2: 读取 JSON 并生成早报（LLM）
# 读取 ai_news_raw.json，按模板生成早报

# Step 3: 发送给用户
# 通过可用渠道（飞书/钉钉等）发送早报
```



## LLM 生成模板

```
📰 今日 AI 新闻早报（{日期}）

---

⭐⭐⭐⭐⭐ | [标题]({URL})
**📝 简述**：{80-100 字总结}
**💡 我的理解**：{1-2 句洞察}
**📰 来源**：{媒体} | {日期}

---

（重复 10 条）

---

💡 我的观察：

1. **趋势 1**：{分析}
2. **趋势 2**：{分析}
3. **趋势 3**：{分析}
4. **趋势 4**：{分析}

---

*每天早上 9 点自动推送*
```

## 配置

### 关键词

编辑 `generate_report.py`:
```python
"TOPIC_QUERIES": ["AI 大模型", "人工智能 自动驾驶", "AI 智能体 Agent", "人形机器人", "OpenAI 谷歌 英伟达"]
```

### 媒体权重

```python
"MEDIA_WEIGHTS": {
    100: ['机器之心', '新智元', '量子位'],
    80: ['新华社', '人民日报', '央视新闻'],
    60: ['36 氪', '钛媒体', '虎嗅'],
}
```

## 输出

### JSON

```json
[{
  "title": "标题",
  "content": "内容",
  "url": "链接",
  "date": "2026-03-14",
  "source": "机器之心",
  "weight": 100
}]
```

### 统计

```json
{
  "status": "success",
  "news_count": 50,
  "sources": {"机器之心": 15, "新智元": 8}
}
```

## 调试

```bash
# 运行
python3 generate_report.py

# 查看
cat ai_news_raw.json | head -50

# 测试 Cron
openclaw cron run "AI 新闻早报"
```
