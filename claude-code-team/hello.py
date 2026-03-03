#!/usr/bin/env python3
from datetime import datetime

name = input("请输入你的名字: ")
print(f"Hello, {name}! 欢迎来到这里！")
print(f"Current time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
