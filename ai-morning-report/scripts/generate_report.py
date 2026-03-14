#!/usr/bin/env python3
"""
AI 新闻早报 Skill - 数据准备

搜索 AI 新闻，按媒体权威性排序，保存到 JSON 文件
供 OpenClaw 大模型读取并生成早报

使用方法:
  python3 generate_report.py

输出:
  - 终端：搜索统计（JSON 格式，供 OpenClaw 读取）
  - 文件：/root/.openclaw/workspace/ai_news_raw.json
"""

import json
import subprocess
import sys
import os
from datetime import datetime

# ============ 配置项 =============
CONFIG = {
    # 搜索关键词
    "TOPIC_QUERIES": [
        "AI 大模型",
        "人工智能 自动驾驶",
        "AI 智能体 Agent",
        "人形机器人",
        "OpenAI 谷歌 英伟达",
    ],
    "MEDIA_QUERIES": [
        "机器之心 site:jiqizhixin.com",
        "新智元 site:aiera.com",
        "量子位 site:qbitai.com",
        "36 氪 AI site:36kr.com",
    ],
    "SEARCH_TOP_K": 10,
    "NEWS_COUNT": 50,
    
    # 媒体权重
    "MEDIA_WEIGHTS": {
        100: ['机器之心', '新智元', '量子位', 'AIbase', 'AI 科技评论'],
        80: ['新华社', '人民日报', '央视新闻', '新华网', '中证网'],
        60: ['36 氪', '钛媒体', '虎嗅', '雷锋网'],
        40: ['新浪', '网易', '凤凰网'],
        30: ['财联社', '同花顺', '金融界'],
    },
    "BLACKLIST": ['百家号', '搜狐号', '今日头条', '知乎专栏', '云南网', '陕西网'],
}

# ===============================

def search_news(query):
    """调用 baidu-search 搜索"""
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
        print(f"搜索 '{query}' 失败：{e}", file=sys.stderr)
    return []


def get_media_weight(source: str) -> int:
    """获取媒体权重"""
    for weight, media_list in CONFIG['MEDIA_WEIGHTS'].items():
        if any(m in source for m in media_list):
            return weight
    return 5


def extract_real_source(news):
    """提取真实来源"""
    url = news.get('url', '').lower()
    content = news.get('content', '')
    
    if content:
        media_patterns = [
            '机器之心', '新智元', '量子位', '36 氪', '钛媒体', '虎嗅',
            '新华社', '人民日报', '央视新闻', '新浪', '网易', '凤凰',
            '财联社', '同花顺', 'AIbase', 'AI 科技评论'
        ]
        for media in media_patterns:
            if media in content[:100]:
                return media
    
    if '36kr.com' in url:
        return '36 氪'
    elif 'jiqizhixin.com' in url:
        return '机器之心'
    elif 'aiera.com' in url:
        return '新智元'
    elif 'qbitai.com' in url:
        return '量子位'
    
    return None


def process_news(news):
    """处理单条新闻"""
    real_source = extract_real_source(news)
    if not real_source:
        return None
    
    url = news.get('url', '').lower()
    is_baijiahao = 'baijiahao.baidu.com' in url
    
    if is_baijiahao:
        trusted = ['机器之心', '新智元', '量子位', '36 氪', '新华社', '新浪', '网易']
        if not any(t in real_source for t in trusted):
            return None
    
    if any(b in real_source for b in CONFIG['BLACKLIST']):
        return None
    
    return {
        "title": news.get('title', ''),
        "content": news.get('content', ''),
        "url": news.get('url', ''),
        "date": news.get('date', ''),
        "source": real_source,
        "weight": get_media_weight(real_source)
    }


def deduplicate(news_list):
    """去重"""
    result = []
    for news in news_list:
        title = news.get('title', '')[:30].lower()
        is_dup = False
        for existing in result:
            existing_title = existing.get('title', '')[:30].lower()
            common = sum(1 for c in title if c in existing_title)
            if common > len(title) * 0.6:
                is_dup = True
                if news.get('weight', 0) > existing.get('weight', 0):
                    result.remove(existing)
                    result.append(news)
                break
        if not is_dup:
            result.append(news)
    return result


def fetch_news():
    """获取新闻"""
    print("🔍 搜索 AI 新闻...", file=sys.stderr)
    all_news = []
    
    for query in CONFIG['TOPIC_QUERIES'] + CONFIG['MEDIA_QUERIES']:
        print(f"  搜索：{query}", file=sys.stderr)
        results = search_news(query)
        for news in results:
            processed = process_news(news)
            if processed:
                all_news.append(processed)
    
    print(f"📰 共获取 {len(all_news)} 条", file=sys.stderr)
    sorted_news = sorted(all_news, key=lambda x: x.get('weight', 0), reverse=True)
    deduped = deduplicate(sorted_news)
    print(f"🔄 去重后剩 {len(deduped)} 条", file=sys.stderr)
    
    return deduped[:CONFIG['NEWS_COUNT']]


if __name__ == "__main__":
    # 1. 获取新闻
    news_list = fetch_news()
    
    # 2. 保存到 JSON 文件
    output_file = "/root/.openclaw/workspace/ai_news_raw.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(news_list, f, ensure_ascii=False, indent=2)
    print(f"📁 已保存到：{output_file}", file=sys.stderr)
    
    # 3. 输出统计（JSON 格式，供 OpenClaw 读取）
    stats = {
        "status": "success",
        "news_count": len(news_list),
        "output_file": output_file,
        "sources": {},
        "message": "新闻数据已准备完成，请读取 JSON 文件并生成早报"
    }
    
    # 来源统计
    for news in news_list:
        src = news['source']
        stats["sources"][src] = stats["sources"].get(src, 0) + 1
    
    # 输出 JSON 统计（stdout 供 OpenClaw 读取）
    print("\n" + json.dumps(stats, ensure_ascii=False, indent=2))
    
    # 4. 输出来源列表（stderr 供人类阅读）
    print(f"\n📊 来源统计：{stats['sources']}", file=sys.stderr)
    print("\n✅ 数据准备完成，请 LLM 读取 JSON 生成早报并推送", file=sys.stderr)
