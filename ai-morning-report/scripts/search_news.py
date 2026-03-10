#!/usr/bin/env python3
"""
AI 新闻搜索脚本
使用 baidu-search 混合搜索 AI 新闻，按媒体权重排序

使用方法:
  python3 search_news.py
"""

import json
import subprocess
import sys
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

    # 专业AI媒体搜索（只搜专业媒体）
    "MEDIA_QUERIES": [
        "机器之心",
        "新智元",
        "量子位",
        "AIbase",
    ],

    "SEARCH_TOP_K": 10,  # 每个关键词搜索结果数
    "TOP_K": 30,         # 最终保留的新闻数量

    # 媒体分类和权重配置（分数越高越重要）
    "MEDIA_CATEGORIES": {
        # 专业AI媒体（最高优先级）
        "专业AI媒体": {
            "weight": 100,
            "media": ["机器之心", "新智元", "量子位", "AIbase", "AI科技评论"]
        },
        # 权威官方媒体（第二优先级）
        "官方媒体": {
            "weight": 80,
            "media": ["新华社", "人民日报", "人民网", "新华网", "央视新闻", "央广网", "中证网"]
        },
        # 综合性科技媒体（第三优先级）
        "综合科技媒体": {
            "weight": 60,
            "media": ["36氪", "钛媒体", "虎嗅", "雷锋网"]
        },
        # 主流门户（第四优先级）
        "主流门户": {
            "weight": 40,
            "media": ["新浪网", "网易", "凤凰网", "ZAKER"]
        },
        # 财经媒体（第五优先级）
        "财经媒体": {
            "weight": 30,
            "media": ["金融界", "同花顺", "金十数据", "财联社"]
        },
        # 其他媒体（最低优先级）
        "其他": {
            "weight": 10,
            "media": ["中国环境", "云南网"]
        },
    },

    #  backwards compatible MEDIA_WEIGHTS
    "MEDIA_WEIGHTS": {},

    # 需要过滤的广告关键词
    "AD_KEYWORDS": [
        "GEO优化", "抖音代运营", "短视频代运营", "SEO优化",
        "服务商排行榜", "推荐榜单", "实力排行榜"
    ],
}

# ===============================


def get_media_weight(source: str) -> int:
    """获取媒体权重，基于分类配置"""
    for category, config in CONFIG["MEDIA_CATEGORIES"].items():
        # 检查媒体名称是否匹配（支持模糊匹配）
        for media_name in config["media"]:
            if media_name in source or source in media_name:
                return config["weight"]
    # 未分类的媒体给个基础权重
    return 5


def is_ad_content(title: str, content: str) -> bool:
    """检查是否为广告内容"""
    text = title + ' ' + content
    for keyword in CONFIG["AD_KEYWORDS"]:
        if keyword in text:
            return True
    return False


def is_valid_source(source: str) -> bool:
    """检查来源是否有效（过滤掉无效的百家号和无法识别的来源）"""
    # 如果来源为 None 或空，说明无法识别真实媒体
    if not source:
        return False
    # 如果是百家号，说明没识别出真实媒体，过滤掉
    if source == "百家号":
        return False
    # 如果是未知来源，过滤掉
    if source == "未知":
        return False
    return True


def extract_real_source(news):
    """从新闻中提取真实来源（百家号文章需要从内容/URL 中识别）"""
    import re
    title = news.get('title', '')
    content = news.get('content', '')
    url = news.get('url', '')
    website = news.get('website', '')
    full_text = title + ' ' + content

    # ========== 0. 优先从内容中提取专业媒体名称（电头格式）==========
    # 专业 AI 媒体的电头格式："新智元报道"、"机器之心"、"量子位"
    content_start = content[:300] if content else ''
    
    # 电头匹配模式（优先级最高）- 确保媒体名和"报道"之间没有空格
    dateline_patterns = [
        # 据 XX 报道
        r'^(\s*据)?(机器之心|新智元|量子位|AIbase|AI 科技评论)(报道|消息|讯|网)',
        # XX 报道（没有空格）
        r'^(\s*)(机器之心|新智元|量子位|AIbase|AI 科技评论)(报道)',
    ]
    
    for pattern in dateline_patterns:
        match = re.search(pattern, content_start, re.IGNORECASE)
        if match:
            extracted = match.group(2) if match.lastindex >= 2 else match.group(1)
            # 标准化名称
            name_mapping = {
                '机器之心': '机器之心',
                '新智元': '新智元',
                '量子位': '量子位',
                'AIbase': 'AIbase',
                'AI 科技评论': 'AI 科技评论',
            }
            return name_mapping.get(extracted, extracted)
    
    # ========== 1. 从 URL 中提取来源（最可靠）==========
    url_source_map = {
        # 专业 AI 媒体
        'jiqizhixin': '机器之心',
        'jiqizh.com': '机器之心',
        'aiera.com': '新智元',
        'aiera': '新智元',
        'qbitai.com': '量子位',
        'qbitai': '量子位',
        'aibase.com': 'AIbase',
        'aibase': 'AIbase',
        'syncedreview.com': '机器之心',
        'jiqizhixin.cn': '机器之心',

        # 权威官方媒体
        'xinhuanet.com': '新华社',
        'xinhua': '新华社',
        'people.com.cn': '人民日报',
        'people.cn': '人民日报',
        'cctv.com': '央视新闻',
        'cctv.cn': '央视新闻',
        'cnr.cn': '央广网',
        'news.cn': '新华网',
        'xinhuanet': '新华社',
        'chinanews.com': '中国新闻网',
        'cs.com.cn': '中证网',
        'cs.com': '中证网',

        # 综合性科技媒体
        '36kr.com': '36氪',
        '36kr': '36氪',
        'tmtpost.com': '钛媒体',
        'tmtpost': '钛媒体',
        'huxiu.com': '虎嗅',
        'huxiu': '虎嗅',
        'leiphone.com': '雷锋网',
        'leiphone': '雷锋网',
        'pingwest.com': '品玩',
        'geekpark.net': '极客公园',
        'ifanr.com': '爱范儿',
        'cyzone.cn': '创业邦',
        'techweb.com.cn': 'TechWeb',

        # 主流科技媒体
        'sina.com.cn': '新浪科技',
        'sina.cn': '新浪科技',
        'sina.com': '新浪科技',
        'tech.sina.com.cn': '新浪科技',
        '163.com': '网易科技',
        'tech.163.com': '网易科技',
        'ifeng.com': '凤凰网',
        'tech.ifeng.com': '凤凰网科技',
        'sohu.com': '搜狐科技',
        'qq.com': '腾讯科技',
        'tech.qq.com': '腾讯科技',
        'myzaker.com': 'ZAKER',

        # 财经媒体
        'jrj.com.cn': '金融界',
        'jrj.com': '金融界',
        '10jqka.com.cn': '同花顺',
        'thsi.cn': '同花顺',
        'jin10.com': '金十数据',
        'cls.cn': '财联社',
        'caijing.com.cn': '财经网',
        'caixin.com': '财新网',
        'eeo.com.cn': '经济观察网',
        'yicai.com': '第一财经',
        'stcn.com': '证券时报',
        'p5w.net': '全景网',
        'hexun.com': '和讯网',

        # 其他科技媒体
        'zhidx.com': '智东西',
        'donews.com': 'DoNews',
        'chinaz.com': '站长之家',
        'admin5.com': 'A5创业网',
        'itbear.com.cn': 'ITBear',
        'it168.com': 'IT168',
        'zol.com.cn': '中关村在线',
        'pconline.com.cn': '太平洋电脑网',
    }

    url_lower = url.lower()
    for key, source in url_source_map.items():
        if key in url_lower:
            return source

    # ========== 2. 从内容开头提取来源（电头格式）==========
    # 常见电头格式："新华社北京3月5日电"、"人民日报客户端"、"央视网消息"
    content_start = content[:300] if content else ''

    # 电头匹配模式
    dateline_patterns = [
        # 新华社 X月X日电 / 新华社北京X月X日电
        r'^(\s*[^\s]{2,10}报?讯\s+)?(新华社)[\s·]*[^\s]*\d{1,2}月\d{1,2}日?电',
        # 人民日报 / 人民日报客户端
        r'^(\s*[^\s]{2,10}报?讯\s+)?(人民日报)(客户端|网|讯)',
        # 央视新闻 / 央视网
        r'^(\s*[^\s]{2,10}报?讯\s+)?(央视)(新闻|网|讯|客户端)',
        # 央广网
        r'^(\s*[^\s]{2,10}报?讯\s+)?(央广网)',
        # 中新网 / 中国新闻网
        r'^(\s*[^\s]{2,10}报?讯\s+)?(中国新闻网|中新网)',
        # 据XX报道 / 来自XX
        r'^(\s*据)?(机器之心|新智元|量子位|AIbase|36氪|钛媒体|虎嗅|雷锋网|品玩|极客公园)(报道|消息|讯|网)',
        # XX消息 / XX讯
        r'^(\s*)(机器之心|新智元|量子位|AIbase|36氪|钛媒体|虎嗅|雷锋网)(消息|讯|网)',
    ]

    for pattern in dateline_patterns:
        match = re.search(pattern, content_start, re.IGNORECASE)
        if match:
            extracted = match.group(2)
            # 标准化名称
            name_mapping = {
                '央视': '央视新闻',
                '中新网': '中国新闻网',
            }
            return name_mapping.get(extracted, extracted)

    # ========== 3. 从标题中提取来源（括号格式）==========
    # 格式："标题内容（机器之心）"、"标题内容【新智元】"
    title_source_patterns = [
        r'[（(](机器之心|新智元|量子位|AIbase|AI科技评论|36氪|钛媒体|虎嗅|雷锋网)[）)]',
        r'[【\[](机器之心|新智元|量子位|AIbase|AI科技评论|36氪|钛媒体|虎嗅|雷锋网)[】\]]',
    ]
    for pattern in title_source_patterns:
        match = re.search(pattern, title)
        if match:
            return match.group(1)

    # ========== 4. 从全文内容中提取媒体名称 ==========
    # 专业 AI 媒体（优先级高）
    ai_media_list = [
        "机器之心", "新智元", "量子位", "AIbase", "AI科技评论",
        "智东西", "品玩", "极客公园", "爱范儿",
    ]

    # 权威官方媒体
    official_media = [
        "新华社", "人民日报", "人民网", "新华网", "央视新闻",
        "央广网", "中国新闻网", "中证网", "光明网",
    ]

    # 综合性科技媒体
    tech_media = [
        "36氪", "钛媒体", "虎嗅", "雷锋网", "DoNews",
        "创业邦", "TechWeb", "站长之家", "ITBear", "IT168",
    ]

    # 财经媒体
    finance_media = [
        "金融界", "同花顺", "金十数据", "财联社", "财经网",
        "财新网", "经济观察网", "第一财经", "证券时报", "全景网", "和讯网",
    ]

    # 按优先级检测（AI媒体 > 官方媒体 > 科技媒体 > 财经媒体）
    for media in ai_media_list + official_media + tech_media + finance_media:
        if media in full_text:
            return media

    # ========== 5. 处理百家号文章 ==========
    is_baijiahao = 'baijiahao' in url_lower or 'baijiahao.baidu.com' in url_lower or '百家号' in website

    if is_baijiahao:
        # 百家号文章常有的来源标记："本文来自：XX网"
        source_patterns = [
            r'本文来自[：:]([^，。\s]{2,20})',
            r'来源[：:]([^，。\s]{2,20})',
            r'转载自[：:]([^，。\s]{2,20})',
            r'稿件来源[：:]([^，。\s]{2,20})',
        ]
        for pattern in source_patterns:
            match = re.search(pattern, full_text)
            if match:
                extracted = match.group(1).strip()
                # 清理常见后缀
                for suffix in ['网', '报', '客户端', '官方账号']:
                    if extracted.endswith(suffix) and len(extracted) > 4:
                        return extracted
                # 标准化处理
                if '新浪' in extracted:
                    return '新浪科技'
                if '网易' in extracted:
                    return '网易科技'
                if '腾讯' in extracted:
                    return '腾讯科技'
                if '搜狐' in extracted:
                    return '搜狐科技'
                return extracted

        # 如果还是无法识别，返回"百家号"让后续过滤
        return '百家号'

    # ========== 6. 返回原始网站名 ==========
    return website if website else '未知'


def process_news(news, forced_source=None):
    """处理单条新闻，提取真实来源和权重

    Args:
        news: 原始新闻数据
        forced_source: 强制指定的来源（如搜索特定媒体时）

    Returns:
        处理后的新闻字典，如果无法识别有效来源则返回 None
    """
    # 如果有强制来源，直接使用
    if forced_source:
        weight = get_media_weight(forced_source)
        return {
            "title": news.get('title', ''),
            "content": news.get('content', ''),
            "url": news.get('url', ''),
            "date": news.get('date', ''),
            "source": forced_source,
            "weight": weight
        }

    # 否则从内容中提取
    real_source = extract_real_source(news)

    # 如果无法识别有效来源，返回 None（后续会被过滤掉）
    if not real_source or real_source == '百家号' or real_source == '未知':
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


def search_news(query):
    """调用 baidu-search 搜索新闻"""
    cmd = [
        "python3", "search.py",
        json.dumps({
            "query": query,
            "search_recency_filter": "week",  # 一周内
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


def sort_news_by_priority(news_list):
    """按媒体优先级排序新闻

    排序优先级：
    1. 专业AI媒体（机器之心、新智元等）
    2. 官方媒体（新华社、央视新闻等）
    3. 综合科技媒体（36氪、钛媒体等）
    4. 主流门户（新浪、网易等）
    5. 财经媒体（金融界、财联社等）
    6. 其他

    同一类别内按权重分数排序
    """
    def get_sort_key(news):
        source = news.get('source', '')
        weight = news.get('weight', 0)

        # 确定类别优先级（数字越小优先级越高）
        category_priority = 6  # 默认为最低优先级
        for cat_name, cat_config in CONFIG["MEDIA_CATEGORIES"].items():
            for media_name in cat_config["media"]:
                if media_name in source or source in media_name:
                    # 根据类别名称确定优先级顺序
                    priority_map = {
                        "专业AI媒体": 1,
                        "官方媒体": 2,
                        "综合科技媒体": 3,
                        "主流门户": 4,
                        "财经媒体": 5,
                        "其他": 6,
                    }
                    category_priority = priority_map.get(cat_name, 6)
                    break
            if category_priority < 6:
                break

        # 返回排序键：(类别优先级, 权重分数) - 两者都按升序排，所以权重取负数
        return (category_priority, -weight)

    return sorted(news_list, key=get_sort_key)


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


def main():
    """主函数"""
    print("🔍 搜索AI新闻...")
    
    all_news = []
    
    # 1. 话题搜索
    print("\n📌 话题搜索...")
    for query in CONFIG['TOPIC_QUERIES']:
        print(f"  搜索: {query}")
        results = search_news(query)
        for news in results:
            processed = process_news(news)  # 话题搜索不强制来源
            if processed:  # 只添加成功识别来源的新闻
                all_news.append(processed)
        print(f"    获取 {len(results)} 条")

    # 2. 专业媒体搜索（强制标记来源）
    print("\n📌 专业媒体搜索...")
    for media in CONFIG['MEDIA_QUERIES']:
        print(f"  搜索: {media}")
        results = search_news(media + " AI")
        for news in results:
            processed = process_news(news, forced_source=media)  # 强制标记来源
            if processed:  # 只添加成功识别来源的新闻
                all_news.append(processed)
        print(f"    获取 {len(results)} 条")
    
    print(f"\n📰 共获取 {len(all_news)} 条新闻")
    
    # all_news 已经是处理过的数据，直接过滤广告
    
    # 过滤无效来源和广告内容
    print("\n🧹 过滤无效来源和广告内容...")
    filtered = []
    for news in all_news:
        # 过滤无效来源（识别不出的百家号）
        if not is_valid_source(news['source']):
            continue
        # 过滤广告内容
        if is_ad_content(news['title'], news['content']):
            continue
        filtered.append(news)
    print(f"   过滤后剩 {len(filtered)} 条")
    
    # 去重
    print("\n🔄 去重...")
    deduped = deduplicate(filtered)
    print(f"   去重后剩 {len(deduped)} 条")
    
    # 按媒体优先级排序
    print("\n⚖️ 按媒体优先级排序...")
    sorted_news = sort_news_by_priority(deduped)
    
    # 【新增】日期过滤：只保留3天内的新闻（新闻日期按北京时间）
    print("\n📅 过滤3天前的新闻...")
    from datetime import timedelta, timezone
    today_utc = datetime.now()
    # 北京时间 = UTC+8
    beijing_tz = timezone(timedelta(hours=8))
    today_beijing = today_utc.astimezone(beijing_tz)
    
    filtered_by_date = []
    for news in sorted_news:
        date_str = news.get('date', '')
        if date_str:
            try:
                # 解析日期，假设是北京时间
                news_date = datetime.strptime(date_str[:19], "%Y-%m-%d %H:%M:%S")
                # 设为北京时间
                news_date_beijing = news_date.replace(tzinfo=beijing_tz)
                # 计算与今天北京时间的差距
                if (today_beijing - news_date_beijing).days <= 2:
                    filtered_by_date.append(news)
            except:
                # 无法解析日期的也保留
                filtered_by_date.append(news)
    print(f"   3天内新闻: {len(filtered_by_date)} 条")
    
    # 取前 TOP_K
    final_news = filtered_by_date[:CONFIG['TOP_K']]
    
    # 统计来源
    sources = {}
    for news in final_news:
        src = news['source']
        sources[src] = sources.get(src, 0) + 1
    print(f"📰 来源统计: {sources}")
    
    # 移除 weight 字段（不需要发给 LLM）
    output_news = []
    for news in final_news:
        output_news.append({
            "title": news['title'],
            "content": news['content'],
            "url": news['url'],
            "date": news['date'],
            "source": news['source']
        })
    
    # 保存到文件，供后续 LLM 处理
    output_file = "/root/.openclaw/workspace/ai_news_raw.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_news, f, ensure_ascii=False, indent=2)
    
    print(f"\n📁 已保存到: {output_file}")
    print(f"📰 最终精选 {len(output_news)} 条新闻")
    
    # 输出 JSON 格式
    print("\n" + "="*50)
    print("JSON_OUTPUT_START")
    print(json.dumps(output_news, ensure_ascii=False, indent=2))
    print("JSON_OUTPUT_END")
    
    return output_news


if __name__ == "__main__":
    main()
