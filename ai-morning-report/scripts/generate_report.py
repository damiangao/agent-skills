#!/usr/bin/env python3
"""
AI 新闻早报生成器 - 搜索工具

使用 baidu-search 搜索新闻，调用 search_news.py 的媒体处理逻辑
返回原始数据给 OpenClaw 处理

使用方法:
  python3 generate_report.py

输出:
  JSON 格式的新闻列表，供 OpenClaw 总结

环境变量:
  DELIVERY_CHANNEL - 推送渠道 (可选)
  DELIVERY_TARGET - 推送目标 (可选)
"""

import json
import subprocess
import sys
import os
from datetime import datetime

# ============ 配置项 =============
CONFIG = {
    # 话题搜索关键词
    "TOPIC_QUERIES": [
        "AI 大模型",
        "人工智能 自动驾驶",
        "AI 智能体 Agent",
        "人形机器人",
        "OpenAI 谷歌 英伟达",
    ],
    
    # 专业 AI 媒体搜索（确保搜到专业媒体）
    "MEDIA_QUERIES": [
        "机器之心 site:jiqizhixin.com",
        "新智元 site:aiera.com",
        "量子位 site:qbitai.com",
        "36 氪 AI site:36kr.com",
    ],
    
    "SEARCH_TOP_K": 10,      # 每个关键词搜索结果数
    "NEWS_COUNT": 50,        # 返回给 LLM 的新闻数量
}

# ===============================

# 导入 search_news.py 的函数
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from search_news import extract_real_source, is_valid_source, sort_news_by_priority


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
        print(f"搜索 '{query}' 失败：{e}", file=sys.stderr)
    return []


def fetch_news():
    """获取新闻列表，处理媒体来源"""
    print("🔍 搜索 AI 新闻...")
    
    all_news = []
    
    # 1. 搜索话题新闻
    print("\n📌 话题搜索：")
    for query in CONFIG['TOPIC_QUERIES']:
        print(f"  搜索：{query}")
        results = search_news(query)
        for news in results:
            processed = process_news(news)
            if processed:
                all_news.append(processed)
    
    # 2. 搜索专业媒体（确保搜到）
    print("\n📌 专业媒体搜索：")
    for query in CONFIG['MEDIA_QUERIES']:
        print(f"  搜索：{query}")
        results = search_news(query)
        for news in results:
            processed = process_news(news)
            if processed:
                all_news.append(processed)
    
    print(f"\n📰 共获取 {len(all_news)} 条有效新闻")
    
    # 按优先级排序
    sorted_news = sort_news_by_priority(all_news)
    
    # 过滤低质量媒体
    low_quality = ['云南网', '陕西网', '中国环境', '中国日报网']
    filtered_news = [n for n in sorted_news if n['source'] not in low_quality]
    print(f"🗑️ 过滤低质量媒体后剩 {len(filtered_news)} 条")
    
    # 去重
    deduped = deduplicate(filtered_news)
    print(f"🔄 去重后剩 {len(deduped)} 条")
    
    # 返回完整内容，让 OpenClaw 的 LLM 来总结精简
    news_list = []
    for news in deduped[:CONFIG['NEWS_COUNT']]:
        news_list.append({
            "title": news.get('title', ''),
            "content": news.get('content', ''),  # 完整内容，不截断
            "url": news.get('url', ''),
            "date": news.get('date', '')[:10],
            "source": news.get('source', '未知'),
            "weight": news.get('weight', 0)
        })
    
    return news_list


def process_news(news):
    """处理单条新闻，提取真实来源"""
    real_source = extract_real_source(news)
    
    # 严格过滤：没识别出真实来源就扔掉
    if not real_source:
        return None
    if real_source == '未知':
        return None
    
    # 检查 URL 是否来自百家号
    url = news.get('url', '').lower()
    is_baijiahao = 'baijiahao.baidu.com' in url or 'baijia.baidu.com' in url
    
    # 如果是百家号，需要进一步判断
    if is_baijiahao:
        # 专业媒体、权威媒体、综合科技媒体在百家号发文章 → 保留
        trusted_sources = [
            # 专业 AI 媒体
            '机器之心', '新智元', '量子位', 'AIbase', 'AI 科技评论',
            # 权威官方媒体
            '新华社', '人民日报', '央视新闻', '新华网', '中证网', '央广网',
            # 综合科技媒体
            '36 氪', '钛媒体', '虎嗅', '雷锋网',
            # 主流门户
            '新浪', '网易', '凤凰网',
            # 财经媒体
            '同花顺', '金融界', '财联社', '证券时报', '财经网',
        ]
        # 检查是否是可信媒体
        is_trusted = any(trusted in real_source for trusted in trusted_sources)
        if not is_trusted:
            # 不可信的百家号自媒体 → 过滤掉
            return None
    
    weight = get_media_weight(real_source)
    
    return {
        "title": news.get('title', ''),
        "content": news.get('content', ''),
        "url": news.get('url', ''),
        "date": news.get('date', ''),
        "source": real_source,
        "weight": weight
    }


def get_media_weight(source: str) -> int:
    """获取媒体权重"""
    # 专业 AI 媒体
    if any(m in source for m in ['机器之心', '新智元', '量子位', 'AIbase', 'AI科技评论']):
        return 100
    # 官方媒体
    if any(m in source for m in ['新华社', '人民日报', '央视新闻', '新华网', '中证网']):
        return 80
    # 综合科技媒体
    if any(m in source for m in ['36 氪', '钛媒体', '虎嗅', '雷锋网']):
        return 60
    # 主流门户
    if any(m in source for m in ['新浪', '网易', '凤凰网']):
        return 40
    # 财经媒体
    if any(m in source for m in ['同花顺', '金融界', '财联社']):
        return 30
    return 5


def deduplicate(news_list):
    """去重（基于标题相似度）"""
    if not news_list:
        return []
    
    result = []
    for news in news_list:
        title = news.get('title', '')[:30].lower()
        is_dup = False
        for existing in result:
            existing_title = existing.get('title', '')[:30].lower()
            # 计算公共字符数
            common = sum(1 for c in title if c in existing_title)
            if common > len(title) * 0.6:
                is_dup = True
                # 保留权重高的
                if news.get('weight', 0) > existing.get('weight', 0):
                    result.remove(existing)
                    result.append(news)
                break
        if not is_dup:
            result.append(news)
    return result


if __name__ == "__main__":
    # 获取新闻
    news_list = fetch_news()
    
    # 输出 JSON 格式，供 OpenClaw 读取
    print("\n" + "="*50)
    print("JSON_OUTPUT_START")
    print(json.dumps(news_list, ensure_ascii=False, indent=2))
    print("JSON_OUTPUT_END")
    print("="*50)
    
    # 保存到文件（可选，用于调试）
    output_file = "/root/.openclaw/workspace/ai_news_raw.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(news_list, f, ensure_ascii=False, indent=2)
    
    print(f"\n📁 已保存到：{output_file}")
    print(f"📰 共 {len(news_list)} 条新闻")
    
    # 统计来源
    sources = {}
    for news in news_list:
        src = news['source']
        sources[src] = sources.get(src, 0) + 1
    print(f"📊 来源统计：{sources}")
    
    print("\n💡 下一步：请 OpenClaw 总结这些新闻并发送到飞书")
