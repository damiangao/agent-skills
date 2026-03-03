#!/usr/bin/env python3
"""Mermaid 图表渲染器 - 使用 mmdc CLI"""
import os
import sys
import tempfile
import subprocess


def render_mermaid(mermaid_code: str, output_path: str = None, 
                   output_format: str = "png", background: str = "white", scale: int = 2):
    """渲染 Mermaid 图表为图片
    
    Args:
        mermaid_code: Mermaid 图表代码
        output_path: 输出文件路径 (可选)
        output_format: 输出格式 (png/svg/pdf)
        background: 背景色
        
    Returns:
        生成的图片路径
    """
    # 创建临时输入文件
    with tempfile.NamedTemporaryFile(mode='w', suffix='.mmd', delete=False) as f:
        f.write(mermaid_code)
        input_file = f.name
    
    # 如果没有指定输出路径，自动生成
    if output_path is None:
        output_dir = tempfile.gettempdir()
        output_path = os.path.join(output_dir, f"mermaid_diagram.{output_format}")
    
    # Puppeteer 配置路径
    puppeteer_config = os.path.expanduser("~/.puppeteer.json")
    
    # 构建命令
    cmd = [
        "mmdc",
        "-i", input_file,
        "-o", output_path,
        "-b", background,
        "-s", str(scale)
    ]
    
    # 添加 puppeteer 配置（如果存在）
    if os.path.exists(puppeteer_config):
        cmd.extend(["-p", puppeteer_config])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        
        # 清理临时输入文件
        os.unlink(input_file)
        
        if result.returncode != 0:
            raise RuntimeError(f"mmdc failed: {result.stderr}")
        
        return output_path
        
    except Exception as e:
        # 清理临时文件
        if os.path.exists(input_file):
            os.unlink(input_file)
        raise


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 render.py <mermaid_code> [output_file] [format] [background]")
        print("Example: python3 render.py 'graph TD A-->B' /tmp/out.png")
        sys.exit(1)
    
    # 处理换行符转义
    mermaid_code = sys.argv[1].replace('\\n', '\n')
    output_path = sys.argv[2] if len(sys.argv) > 2 else "/tmp/mermaid.png"
    output_format = sys.argv[3] if len(sys.argv) > 3 else "png"
    background = sys.argv[4] if len(sys.argv) > 4 else "white"
    scale = int(sys.argv[5]) if len(sys.argv) > 5 else 2
    
    # 如果指定了格式但没指定输出路径，根据格式自动生成
    if len(sys.argv) > 3 and len(sys.argv) <= 4:
        output_path = f"/tmp/mermaid.{output_format}"
    
    result = render_mermaid(mermaid_code, output_path, output_format, background, scale)
    print(f"✅ 图片已保存: {result}")
