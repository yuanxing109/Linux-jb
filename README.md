# 玩客云自用脚本集合 (WKY-Scripts)

本仓库存储用于玩客云设备的各种安装和配置脚本，帮助您快速搭建家庭服务器环境。

## 📦 包含内容

### 系统安装脚本
- **安装 CasaOS** - 轻量级家庭云系统
  ```bash
  curl -sSL https://raw.githubusercontent.com/yuanxing109/WKY-Scripts/main/install_casaos.sh | bash
- **安装 Docker** - 容器化平台
  ```bash
  apt-get install docker.io
- **一键换源** - 快速更换国内软件源
  ```bash
  bash <(curl -sSL https://linuxmirrors.cn/main.sh)

### 应用部署脚本
- **青龙面板** - 定时任务管理
  ```bash
  docker run -dit \
  -v $PWD/ql/config:/ql/config \
  -v $PWD/ql/log:/ql/log \
  -v $PWD/ql/db:/ql/db \
  -v $PWD/ql/repo:/ql/repo \
  -v $PWD/ql/raw:/ql/raw \
  -v $PWD/ql/scripts:/ql/scripts \
  -p 5700:5700 \
  --name qinglong \
  --hostname qinglong \
  --restart unless-stopped \
  whyour/qinglong:2.10.13

- **OpenList** - 多存储文件列表程序
  ```bash
  curl -sSL https://raw.githubusercontent.com/yuanxing109/WKY-Scripts/main/install_openlist.sh | bash

### 工具脚本
- **Cpolar推送** - 自动推送URL到push
  项目地址：https://github.com/Hoper-J/cpolar-connect
  ```bash
  # 使用官方安装脚本
  curl -LsSf https://astral.sh/uv/install.sh | sh
  
  # 或安装到系统
  uv tool install cpolar-connect
  
  # 1. 安装 cpolar
  curl -L https://www.cpolar.com/static/downloads/install-release-cpolar.sh | sudo bash
  
  # 2. 配置认证（需要先注册 cpolar 账号）
  cpolar authtoken YOUR_TOKEN
  
  # 3. 设置开机自启
  sudo systemctl enable cpolar
  sudo systemctl start cpolar
  
  # 4. 查看用户名（客户端配置需要）
  whoami
## 🚀 快速开始

### 前提条件
- 玩客云设备（已刷入合适的系统，如Armbian）
- 网络连接
- SSH 访问权限
