#!/bin/bash

# WiFi连接配置脚本
# 支持自动检测当前连接和配置新网络

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 无线接口
INTERFACE="wlan0"
CONFIG_FILE="/etc/wpa_supplicant/wpa_supplicant.conf"

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用sudo运行此脚本${NC}"
    exit 1
fi

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查必要命令
for cmd in iwconfig iw wpa_passphrase wpa_supplicant dhclient; do
    if ! command_exists "$cmd"; then
        echo -e "${RED}错误: 未找到 $cmd 命令${NC}"
        exit 1
    fi
done

# 检查无线网卡状态
check_interface_status() {
    # 检查接口是否存在
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        echo -e "${RED}错误: 未找到无线接口 $INTERFACE${NC}"
        exit 1
    fi
    
    # 检查接口是否已启动
    if ip link show "$INTERFACE" | grep -q "state UP"; then
        echo -e "${GREEN}无线网卡 $INTERFACE 已启动${NC}"
        return 0
    else
        echo -e "${YELLOW}无线网卡 $INTERFACE 未启动${NC}"
        return 1
    fi
}

# 检查当前WiFi连接状态
check_wifi_connection() {
    echo -e "${YELLOW}检查当前网络连接...${NC}"
    current_ssid=$(iwconfig "$INTERFACE" 2>/dev/null | grep "ESSID" | awk -F'"' '{print $2}')
    
    if [ -n "$current_ssid" ] && [ "$current_ssid" != "off/any" ]; then
        # 从wpa_supplicant配置文件中查找对应网络的密码
        if [ -f "$CONFIG_FILE" ]; then
            psk=$(awk -v ssid="$current_ssid" 'BEGIN{RS="network={";FS="\n"} $0 ~ "ssid=\"" ssid "\"" {for(i=1;i<=NF;i++) if($i ~ "psk=") {print $i; exit}}' "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d '"')
            
            if [ -n "$psk" ]; then
                echo -e "${GREEN}已经连接到WiFi网络${NC}"
                echo -e "${BLUE}当前连接的WiFi网络信息：${NC}"
                echo -e "网络名称(SSID): $current_ssid"
                echo -e "密码: $psk"
                
                # 显示IP地址
                ip_addr=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}' 2>/dev/null || echo "无IP地址")
                echo -e "IP地址: $ip_addr"
                return 0
            fi
        fi
    fi
    return 1
}

# 启动无线网卡
start_wireless_interface() {
    echo -e "${YELLOW}正在启动无线网卡 $INTERFACE...${NC}"
    ip link set "$INTERFACE" up
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}无线网卡 $INTERFACE 已成功启动。${NC}"
        
        # 等待无线网卡完全启动
        echo -e "${YELLOW}等待无线网卡初始化...${NC}"
        sleep 3
        return 0
    else
        echo -e "${RED}无线网卡 $INTERFACE 启动失败，请检查硬件或驱动。${NC}"
        return 1
    fi
}

# 扫描WiFi网络
scan_wifi_networks() {
    echo -e "${YELLOW}正在扫描附近的WiFi网络...${NC}"
    
    # 尝试不同的扫描方法
    echo -e "${BLUE}方法1: 使用iw命令扫描...${NC}"
    scan_output=$(timeout 30 iw dev "$INTERFACE" scan 2>&1)
    scan_result=$?
    
    if [ $scan_result -ne 0 ] || [ -z "$scan_output" ]; then
        echo -e "${YELLOW}iw扫描失败或没有结果，尝试方法2...${NC}"
        echo -e "${BLUE}方法2: 使用iwlist命令扫描...${NC}"
        
        if command_exists iwlist; then
            scan_output=$(timeout 30 iwlist "$INTERFACE" scan 2>&1)
            scan_result=$?
        else
            echo -e "${RED}iwlist命令不存在${NC}"
            scan_result=1
        fi
    fi
    
    if [ $scan_result -ne 0 ] || [ -z "$scan_output" ]; then
        echo -e "${RED}无法扫描网络，请检查无线网卡状态${NC}"
        echo -e "${YELLOW}扫描输出:${NC}"
        echo "$scan_output"
        return 1
    fi
    
    # 提取网络名称(SSID)和信号强度
    echo -e "${GREEN}可用的WiFi网络列表：${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # 解析扫描结果
    if echo "$scan_output" | grep -q "Cell"; then
        # iwlist格式
        echo "$scan_output" | awk -F':' '
        /Cell/ {cell = $0; getline; if($0 ~ /ESSID:/) {essid = $0; gsub(/.*ESSID:\"/, "", essid); gsub(/\"/, "", essid); print "网络名称: " essid}}'
    elif echo "$scan_output" | grep -q "SSID"; then
        # iw格式
        ssid=""
        signal=""
        echo "$scan_output" | while read -r line; do
            if echo "$line" | grep -q "SSID:"; then
                ssid=$(echo "$line" | awk -F': ' '{print $2}')
                # 跳过空SSID(隐藏网络)
                if [ -z "$ssid" ]; then
                    ssid="[隐藏网络]"
                fi
            elif echo "$line" | grep -q "signal:"; then
                signal=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
                if [ -n "$ssid" ] && [ -n "$signal" ]; then
                    printf "网络名称: %-30s 信号强度: %s dBm\n" "$ssid" "$signal"
                    ssid=""
                    signal=""
                fi
            fi
        done
    else
        echo -e "${YELLOW}无法解析扫描结果，显示原始输出:${NC}"
        echo "$scan_output" | head -20
    fi
    
    echo -e "${BLUE}========================================${NC}"
    return 0
}

# 配置WiFi网络
configure_wifi() {
    # 创建或备份配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" > "$CONFIG_FILE"
        echo "update_config=1" >> "$CONFIG_FILE"
        echo "country=CN" >> "$CONFIG_FILE"  # 设置国家代码，根据需要修改
    else
        # 备份原有配置
        backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        echo -e "${YELLOW}已备份原有配置: $backup_file${NC}"
    fi
    
    # 添加网络配置
    while true; do
        echo
        read -p "请输入要连接的WiFi网络名称(输入 'q' 退出): " ssid
        if [ "$ssid" = "q" ]; then
            break
        fi
        
        # 检查是否已存在该网络的配置
        if grep -q "ssid=\"$ssid\"" "$CONFIG_FILE"; then
            echo -e "${YELLOW}该网络已存在配置中，跳过添加${NC}"
            continue
        fi
        
        read -s -p "请输入该WiFi网络的密码: " password
        echo
        
        # 使用wpa_passphrase生成配置
        wpa_passphrase "$ssid" "$password" >> "$CONFIG_FILE"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}已成功添加网络配置${NC}"
        else
            echo -e "${RED}添加网络配置失败${NC}"
        fi
    done
}

# 连接WiFi网络
connect_wifi() {
    # 重启网络服务
    echo -e "${YELLOW}正在重新启动网络服务...${NC}"
    
    # 停止正在运行的wpa_supplicant进程
    pkill -f "wpa_supplicant -i $INTERFACE" || true
    
    # 等待进程停止
    sleep 2
    
    # 删除控制接口文件
    rm -f /var/run/wpa_supplicant/"$INTERFACE"
    
    # 启动wpa_supplicant服务
    wpa_supplicant -B -i "$INTERFACE" -c "$CONFIG_FILE" > /dev/null 2>&1
    
    # 检查wpa_supplicant是否启动成功
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}wpa_supplicant已成功启动${NC}"
        
        # 获取IP地址
        echo -e "${YELLOW}正在尝试获取IP地址...${NC}"
        
        # 释放现有租约
        dhclient -r "$INTERFACE" > /dev/null 2>&1
        
        # 请求新IP
        if timeout 30 dhclient -v "$INTERFACE" 2>/dev/null; then
            echo -e "${GREEN}已成功获取IP地址${NC}"
            
            # 显示IP信息
            ip_addr=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}')
            echo -e "${BLUE}IP地址: $ip_addr${NC}"
            
            # 测试网络连接
            echo -e "${YELLOW}测试网络连接...${NC}"
            if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
                echo -e "${GREEN}网络连接正常${NC}"
            else
                echo -e "${YELLOW}可以获取IP地址，但互联网连接可能有问题${NC}"
            fi
        else
            echo -e "${RED}获取IP地址失败，请检查网络设置${NC}"
        fi
    else
        echo -e "${RED}wpa_supplicant启动失败，请检查配置文件或网络环境${NC}"
    fi
}

# 主逻辑
main() {
    # 检查无线网卡状态
    check_interface_status
    
    # 检查是否已连接WiFi
    if check_wifi_connection; then
        exit 0
    fi
    
    # 如果网卡未启动，则启动它
    if ! ip link show "$INTERFACE" | grep -q "state UP"; then
        if ! start_wireless_interface; then
            exit 1
        fi
    fi
    
    # 扫描WiFi网络
    if ! scan_wifi_networks; then
        exit 1
    fi
    
    # 配置WiFi网络
    configure_wifi
    
    # 连接WiFi网络
    connect_wifi
    
    echo -e "${GREEN}脚本执行完成${NC}"
}

# 执行主函数
main