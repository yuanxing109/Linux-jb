# 玩客云自用脚本集合 (WKY-Scripts)

本仓库存储用于玩客云设备的各种安装和配置脚本，帮助您快速搭建家庭服务器环境。

## 📦 包含内容

### 系统安装脚本
- **一键换源** - 快速更换国内软件源
  ```bash
  bash <(curl -sSL https://linuxmirrors.cn/main.sh)
- **安装 Docker** - 容器化平台
  ```bash
  apt-get install docker.io
- **安装 CasaOS** - 轻量级家庭云系统
  ```bash
  curl -sSL https://raw.githubusercontent.com/yuanxing109/WKY-Scripts/main/scripts/casaos-install.sh | bash

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

### 工具脚本
- **CPU监控** - 根据温度调整CPU频率（防止死机）
  ```bash
  curl -sSL https://raw.githubusercontent.com/yuanxing109/WKY-Scripts/main/wky-cpu-install.sh | bash
- *WIFI配置* - 玩客云 免驱无线网卡 终端配网
  ```bash
  curl -sSL https://raw.githubusercontent.com/yuanxing109/WKY-Scripts/main/scripts/connect_wifi.sh | bash

  chmod +x connect_wifi.sh
  #实现开机自动连接到已经配置的wifi
  #打开interfaces文件，内容如下：
  sudo vim /etc/network/interfaces
  #然后在最后添加内容：
  auto wlan0
  iface wlan0 inet dhcp
      wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
  #重启网络服务
  sudo systemctl restart networking
## 🚀 快速开始

### 前提条件
- 玩客云设备（已刷入合适的系统，如Armbian）
- 网络连接
- SSH 访问权限

## ⚠️ 免责声明

本仓库提供的脚本和工具仅用于学习和研究目的，作者不对使用这些脚本可能造成的任何直接或间接损失负责。

使用者应自行评估风险，并在理解脚本功能的前提下谨慎使用。使用本仓库内容即表示您同意自行承担所有相关风险。
## 📄 许可证

本项目采用 [MIT License](LICENSE)。
