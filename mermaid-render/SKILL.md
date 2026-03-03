# SKILL.md - Mermaid 图表渲染

将 Mermaid 语法渲染为 PNG/SVG 图片。

## 使用方式

```bash
python3 /root/.openclaw/workspace/skills/mermaid-render/render.py "mermaid代码" output.png
```

## 安装依赖

```bash
npm install -g @mermaid-js/mermaid-cli

# 创建 puppeteer 配置（Linux root 用户需要）
echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > ~/.puppeteer.json
```

## 示例

输入:
```
flowchart TD
    A[用户] --> B[AI]
    B --> C[回复]
```

输出: 生成 PNG 图片

## 参数

- 第1个参数: Mermaid 代码 (字符串)
- 第2个参数: 输出文件路径 (可选，默认 /tmp/mermaid.png)
- 第3个参数: 输出格式 (可选，默认 png，支持 svg, pdf)
- 第4个参数: 背景色 (可选，默认 white)
