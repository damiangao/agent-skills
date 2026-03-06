# OKR Tracker Skill

OKR 周期性追踪与提醒技能，帮助用户追踪目标进度、设置定时提醒、生成进度报告。

## 功能特性

- 🎯 **OKR 追踪** - 管理多个 OKR 目标的进度
- ⏰ **周期提醒** - 每日/每周/每月定时提醒
- 📊 **进度报告** - 自动生成月度/季度汇总
- 💬 **自然语言** - 用对话方式更新进度

## 安装

```bash
# 克隆或复制此 skill 到 OpenClaw skills 目录
cp -r okr-tracker ~/.openclaw/workspace/skills/
```

## 使用示例

### 设置提醒
```
每天早上 9 点提醒我记录工作时间
每周五晚 8 点提醒我项目检查
每月 28 号提醒我 OKR 复盘
```

### 更新进度
```
本周锻炼 3 次
本月工作时间 120 小时
建仓完成 10 万
原型#1 完成 50%
```

### 查询进度
```
我 OKR 进度怎么样
本月工作时间多少
还有多少建仓任务
```

### 生成报告
```
生成月度报告
季度复盘
```

## 文件结构

```
okr-tracker/
├── SKILL.md          # 技能定义（AI 阅读）
├── README.md         # 用户文档
├── cli.sh            # 命令行工具（可选）
├── config/           # 配置文件目录
└── data/             # 数据目录
```

## 数据存储

- 主追踪文件：`~/.openclaw/workspace/okr-tracker.md`
- 每日记录：`~/.openclaw/workspace/memory/YYYY-MM-DD.md`

## License

MIT
