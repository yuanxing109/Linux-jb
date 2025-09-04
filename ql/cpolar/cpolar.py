# cpolar.py 修复版本
# -*- coding: UTF-8 -*-
# Version: v1.1
# Created by lstcml on 2022/07/21
# 修复版本 by assistant

import os
import sys

path = os.path.split(os.path.realpath(__file__))[0]
log_path = os.path.join(path, "nwct_cpolar_log")
os.makedirs(log_path, exist_ok=True)

log_name = os.path.join(log_path, "cpolar")
app_path = os.path.join(path, "cpolar")

# 检查cpolar是否存在且有执行权限
if not os.path.exists(app_path) or not os.access(app_path, os.X_OK):
    print("错误: cpolar程序不存在或没有执行权限")
    sys.exit(1)

# 使用5700端口，也可以从参数获取
port = "5700"
if len(sys.argv) > 1:
    port = sys.argv[1]

commond = f"{app_path} -log={log_name} {port}"
print(f"执行命令: {commond}")
os.system(commond)
