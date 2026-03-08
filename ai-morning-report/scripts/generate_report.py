#!/usr/bin/env python3
"""
AI 新闻早报生成器 - LLM 版本
使用 baidu-search 搜索新闻，用 LLM 总结成固定格式

使用方法:
  python3 generate_report.py

环境变量:
  LLM_API_URL - LLM API 地址
  LLM_API_KEY - LLM API Key
  LLM_MODEL - LLM 模型名称
  DELIVERY_CHANNEL - 推送渠道 (feishu/qqbot/wechat)
  DELIVERY_TARGET - 推送目标用户/频道
"""

import json
import subprocess
import sys
import os
import requests
from datetime import datetime

# ============ 配置项 =============
# 从环境变量读取配置，支持自定义
CONFIG = {
    # 搜索关键词
    "QUERIES": [
        "AI 大模型",
        "人工智能 自动驾驶",
        "AI 智能体 Agent",
        "人形机器人",
        "OpenAI 谷歌 英伟达",
    ],
    
    "SEARCH_TOP_K": 10,      # 每个关键词搜索结果数
    "NEWS_COUNT": 10,        # 最终精选新闻数
    
    # LLM 配置（从环境变量读取）
    "LLM_API_URL": os.getenv("LLM_API_URL", "https://api.minimax.chat/v1/messages"),
    "LLM_API_KEY": os.getenv("LLM_API_KEY", ""),
    "LLM_MODEL": os.getenv("LLM_MODEL", "MiniMax-M2.5"),
    
    # 推送配置（从环境变量读取）
    "DELIVERY_CHANNEL": os.getenv("DELIVERY_CHANNEL", ""),
    "DELIVERY_TARGET": os.getenv("DELIVERY_TARGET", ""),
}

# ===============================


def search_news(query):
    """调用 baidu-search 搜索新闻"""
    cmd = [
        "python3", "search.py",
        json.dumps({
            "query": query,
            "search_recency_filter": "week",
            "resource_type_filter": [{"type": "web", "top_k": CONFIG['SEARCH_TOP_K']}]
        })
    ]
    
    try:
        result = subprocess.run(
            cmd,
            cwd="/root/.openclaw/workspace/skills/baidu-search/scripts",
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            json_output = '\n'.join(lines[1:]) if len(lines) > 1 else lines[0]
            data = json.loads(json_output)
            return data if isinstance(data, list) else []
    except Exception as e:
        print(f"搜索 '{query}' 失败: {e}", file=sys.stderr)
    return []


def call_llm(prompt: str) -> str:
    """调用 LLM 生成内容"""
    headers = {
        "Authorization": f"Bearer {CONFIG['LLM_API_KEY']}",
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01"
    }
    
    payload = {
        "model": CONFIG['LLM_MODEL'],
        "max_tokens": 8192,
        "messages": [
            {"role": "user", "content": prompt}
        ]
    }
    
    try:
        response = requests.post(
            CONFIG['LLM_API_URL'],
            headers=headers,
            json=payload,
            timeout=120
        )
        response.raise_for_status()
        result = response.json()
        
        # 解析 content（可能是 thinking + text）
        content = result.get("content", [])
        for item in content:
            if item.get("type") == "text":
                return item.get("text", "")
        
        return ""
    except Exception as e:
        print(f"LLM 调用失败: {e}", file=sys.stderr)
        return ""


def generate_report():
    """生成早报"""
    print("🔍 搜索AI新闻...")
    
    # 1. 搜索新闻
    all_news = []
    for query in CONFIG['QUERIES']:
        print(f"  搜索: {query}")
        results = search_news(query)
        all_news.extend(results)
        print(f"    获取 {len(results)} 条")
    
    print(f"\n📰 共获取 {len(all_news)} 条新闻")
    
    # 2. 截取关键信息
    news_list = []
    for news in all_news[:50]:  # 取前50条作为上下文
        title = news.get('title', '')[:80]
        content = news.get('content', '')[:200]
        url = news.get('url', '')
        date = news.get('date', '')[:10]
        source = news.get('website', '')
        
        news_list.append({
            "title": title,
            "content": content,
            "url": url,
            "date": date,
            "source": source
        })
    
    # 3. 构建 LLM prompt
    today = datetime.now()
    month_day = f"{today.month}月{today.day}日"
    
    news_json = json.dumps(news_list, ensure_ascii=False, indent=2)
    
    prompt = f"""你是一个AI新闻早报编辑。请根据以下搜索到的AI新闻，生成今日早报。

## 要求：
1. 筛选出 {CONFIG['NEWS_COUNT']} 条最有价值的AI新闻
2. **只选择日期为最近 2 天的新闻**,不要选择更早的旧闻
3. 按重要程度排序（参考来源的权威性）
4. **来源字段必须使用真实媒体名称**，可选来源如下（按优先级排序）：
   - 专业AI媒体（优先）：机器之心、新智元、量子位、AIbase、AI科技评论
   - 官方媒体：新华社、人民日报、人民网、新华网、央视新闻、央广网、中证网
   - 综合科技媒体：36氪、钛媒体、虎嗅、雷锋网
   - 主流门户：新浪网、网易、凤凰网
   - 财经媒体：金融界、同花顺、金十数据、财联社
   **严禁显示"百家号"，必须从上述列表中选择合适的真实媒体名称**
5. 如果无法确定具体媒体，根据新闻内容性质选择最接近的媒体类型
6. 每条新闻必须包含：标题、简述（50字内）、我的理解（1句话）、来源、日期

## 输出格式：
```
📰 今日 AI 新闻早报（{month_day}）
📰 早报字数：约XXX字 | ⏱️ 预估阅读时间：X分钟

---

⭐⭐⭐⭐⭐ | [标题](链接)
简述：xxx
我的理解：xxx
来源：xxx | 日期

---
```

## 搜索结果：
{news_json}

请直接输出早报内容，不要有其他说明。"""

    # 4. 调用 LLM 生成早报
    print("\n🤖 LLM 正在生成早报...")
    report = call_llm(prompt)
    
    if report:
        print("\n" + "="*50)
        print(report)
        print("="*50)
    else:
        print("❌ LLM 生成失败")
    
    return report


def send_report(report: str):
    """发送早报到配置的渠道
    
    支持渠道：feishu, qqbot, wechat, telegram 等
    通过环境变量 DELIVERY_CHANNEL 和 DELIVERY_TARGET 配置
    """
    channel = CONFIG.get("DELIVERY_CHANNEL", "")
    target = CONFIG.get("DELIVERY_TARGET", "")
    
    if not channel:
        print("ℹ️ 未配置推送渠道，跳过发送")
        print("💡 设置环境变量：export DELIVERY_CHANNEL=feishu")
        return False
    
    try:
        cmd = ["openclaw", "message", "send", "--channel", channel]
        
        if target:
            cmd.extend(["--target", target])
        
        cmd.extend(["--message", report])
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print(f"✅ 早报已发送到 {channel}")
            return True
        else:
            print(f"❌ 发送失败：{result.stderr}", file=sys.stderr)
            return False
    except Exception as e:
        print(f"❌ 发送异常：{e}", file=sys.stderr)
        return False


if __name__ == "__main__":
    # 检查 API Key 配置
    if not CONFIG["LLM_API_KEY"]:
        print("❌ 错误：未配置 LLM_API_KEY 环境变量")
        print("💡 请设置：export LLM_API_KEY=your-api-key")
        sys.exit(1)
    
    report = generate_report()
    
    # 发送早报到配置的渠道
    if report:
        print("\n📤 正在发送早报...")
        send_report(report)
