# nwct_cpolar.py 优化版本
# -*- coding: UTF-8 -*-
# Version: v1.9
# Created by lstcml on 2022/10/18
# 优化版本 by assistant
# 建议定时10分钟：*/10 * * * *

'''
cron: */10 * * * *
new Env('Cpolar内网穿透');
'''

'''
使用说明：
1、打开https://www.cpolar.com/注册登录后获取authtoken；
2、新增变量qlnwct_authtoken，值为你账户的authtoken，运行脚本
3、可选：设置PUSH_PLUS_TOKEN变量用于推送通知

更新记录：
v1.9
1、移除未使用的导入和变量；
2、简化代码结构；
3、优化错误处理和日志输出；
'''

import os
import re
import sys
import requests
import subprocess
from time import sleep

path = os.path.split(os.path.realpath(__file__))[0]
log_path = os.path.join(path, "nwct_cpolar_log")
log_file = os.path.join(log_path, "cpolar.master.log") 
app_path = os.path.join(path, "cpolar")
last_url_file = os.path.join(path, "last_url.txt")
commond = f"python3 {os.path.join(path, 'cpolar.py')} &"

# 检查更新
def update():
    print(f"当前运行的脚本版本：v{version}")
    try:
        r1 = requests.get("https://raw.githubusercontent.com/jiankujidu/cpolar/main/nwct_cpolar.py", timeout=10).text
        r2 = re.findall(re.compile(r"version = v?(\d+\.\d+)"), r1)
        if r2 and float(r2[0]) > version:
            print(f"发现新版本：v{r2[0]}")
            print("正在自动更新脚本...")
            os.system("killall cpolar 2>/dev/null")
            os.system("ql raw https://raw.githubusercontent.com/jiankujidu/cpolar/main/nwct_cpolar.py &")
            return True
    except Exception as e:
        print(f"检查更新失败: {e}")
    return False

# 判断CPU架构
def check_os():
    try:
        r = subprocess.check_output('uname -m', shell=True).decode().strip()
        if 'aarch64' in r or 'arm' in r:
            cpu = 'arm'
        elif 'x86_64' in r or 'x64' in r:
            cpu = 'amd64'
        else:
            print('穿透失败：不支持当前架构！')
            return None
        print(f'获取CPU架构：{r}')
        return cpu
    except Exception as e:
        print(f'获取CPU架构失败: {e}')
        return None

# 下载主程序
def download_cpolar(cpu):
    try:
        if not os.path.exists("cpolar"):
            print("正在下载cpolar程序...")
            zip_filename = f"cpolar-stable-linux-{cpu}.zip"
            res = requests.get(f"https://www.cpolar.com/static/downloads/releases/3.3.18/cpolar-stable-linux-{cpu}.zip", timeout=60)
            with open(zip_filename, "wb") as f:
                f.write(res.content)
            
            # 解压下载的文件
            print("正在解压cpolar程序...")
            try:
                import zipfile
                with zipfile.ZipFile(zip_filename, 'r') as zip_ref:
                    zip_ref.extractall(".")
            except:
                os.system(f"unzip -o {zip_filename} >/dev/null 2>&1")
            
            # 删除压缩文件
            os.remove(zip_filename)
            
            # 确保cpolar文件存在并设置执行权限
            if os.path.exists("cpolar"):
                os.chmod("cpolar", 0o755)
                print("cpolar程序下载并解压成功")
            else:
                print("错误: 解压后未找到cpolar可执行文件")
                return False

        # 设置authtoken
        print("正在设置authtoken...")
        result = os.system(f"{app_path} authtoken {authtoken} >/dev/null 2>&1")
        if result != 0:
            print("设置authtoken失败，请检查token是否正确")
            return False
            
        return True
    except Exception as e:
        print(f"下载或设置cpolar失败: {e}")
        return False

# 获取穿透url
def get_url():
    try:
        if not os.path.exists(log_file):
            return ""
            
        with open(log_file, 'r', encoding='utf-8') as f:
            log_content = f.read()
            
        # 匹配URL的正则表达式
        urls = re.findall(r'https?://[^\s<>"]+', log_content)
        
        for url in urls:
            if 'cpolar' in url:
                print(f"获取穿透链接成功: {url}")
                return url.replace('\\', '')
                
        return ""
    except Exception as e:
        print(f"获取URL失败: {e}")
        return ""

# 进程守护
def process_daemon():
    print("正在检测穿透状态...")
    global qlurl
    qlurl = get_url()
    
    if not qlurl:
        return False
        
    try:
        # 检查cpolar进程是否运行
        result = subprocess.run('ps aux | grep cpolar | grep -v grep', shell=True, capture_output=True, text=True)
        if 'cpolar' not in result.stdout:
            return False
            
        # 尝试访问URL
        response = requests.get(f"{qlurl}/login", timeout=10)
        return response.status_code == 200
    except:
        return False

# 获取上次推送的URL
def get_last_url():
    try:
        if os.path.exists(last_url_file):
            with open(last_url_file, 'r') as f:
                return f.read().strip()
    except:
        pass
    return ""

# 保存当前URL
def save_current_url(url):
    try:
        with open(last_url_file, 'w') as f:
            f.write(url)
    except:
        pass

# 检查是否需要推送
def should_send_notification(current_url):
    last_url = get_last_url()
    
    # 如果没有上次记录或者URL发生了变化，则需要推送
    if not last_url or last_url != current_url:
        save_current_url(current_url)
        return True
    return False

# PushPlus推送函数
def pushplus_push(title, content):
    if not token:
        print("未设置PUSH_PLUS_TOKEN，跳过推送")
        return False
        
    print("正在发送PushPlus推送...")
    try:
        url = "https://www.pushplus.plus/send"
        data = {
            "token": token,
            "title": title,
            "content": content,
            "template": "txt"
        }
        
        response = requests.post(url, data=data, timeout=10)
        result = response.json()
        
        if result.get("code") == 200:
            print("PushPlus推送成功")
            return True
        else:
            print(f"PushPlus推送失败: {result.get('msg', '未知错误')}")
            return False
    except Exception as e:
        print(f"PushPlus推送异常: {e}")
        return False

# 执行程序
def start_nwct():
    need_restart = not process_daemon()
    
    if need_restart:
        os.system(f"rm -rf {log_path}")
        os.makedirs(log_path, exist_ok=True)
        os.system("killall cpolar >/dev/null 2>&1")
        print("正在启动内网穿透...")
        os.system(commond)
        sleep(15)
        
        if process_daemon():
            print(f"启动内网穿透成功！\n青龙面板：{qlurl}")
            # 检查是否需要推送
            if should_send_notification(qlurl):
                pushplus_push("内网穿透通知", f"青龙面板访问地址：{qlurl}")
            else:
                print("URL未变化，无需推送")
            return True
        else:
            print("启动内网穿透失败，请检查日志")
            return False
    else:
        print(f"穿透程序已在运行...\n青龙面板：{qlurl}")
        # 检查是否需要推送
        if should_send_notification(qlurl):
            pushplus_push("内网穿透通知", f"青龙面板访问地址：{qlurl}")
        else:
            print("URL未变化，无需推送")
        return True

if __name__ == '__main__':
    version = 1.9
    
    # 获取环境变量
    try:
        authtoken = os.environ['qlnwct_authtoken']
        if len(authtoken) < 10:
            print("错误: qlnwct_authtoken 值无效")
            sys.exit(1)
    except:
        print("请新增变量qlnwct_authtoken！")
        sys.exit(1)
        
    try:
        token = os.environ['PUSH_PLUS_TOKEN']
        print("找到PUSH_PLUS_TOKEN环境变量")
    except:
        token = ""
        print("未找到PUSH_PLUS_TOKEN环境变量，推送功能将无法使用")
    
    check_update = os.environ.get('qlnwctupdate', "true")

    # 检查更新
    updated = False
    if check_update != "false":
        updated = update()
    
    if updated:
        print("脚本已更新，请重新运行")
        sys.exit(0)
        
    # 检查CPU架构并下载程序
    cpu_type = check_os()
    if not cpu_type:
        sys.exit(1)
        
    if not download_cpolar(cpu_type):
        sys.exit(1)
        
    # 启动内网穿透
    if not start_nwct():
        sys.exit(1)
