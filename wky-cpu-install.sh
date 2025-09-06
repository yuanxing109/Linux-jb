#!/bin/bash

# 玩客云 CPU 调频设置脚本
# 作者: 基于用户需求创建
# 日期: $(date +%Y-%m-%d)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查并设置 CPU 调频机制
setup_cpu_governor() {
    log_info "检查当前 CPU 调频机制..."
    
    # 检查是否存在调频机制文件
    if [ ! -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then
        log_error "CPU 调频机制文件不存在，可能不支持调频或需要加载模块"
        return 1
    fi
    
    # 获取当前调频机制
    CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    log_info "当前 CPU 调频机制: $CURRENT_GOVERNOR"
    
    # 检查是否为 ondemand
    if [ "$CURRENT_GOVERNOR" != "ondemand" ]; then
        log_info "设置 CPU 调频机制为 ondemand..."
        
        # 检查 cpufreq-set 命令是否存在
        if ! command -v cpufreq-set &> /dev/null; then
            log_error "cpufreq-set 命令未找到，尝试安装 cpufrequtils..."
            apt update && apt install -y cpufrequtils
        fi
        
        # 设置调频机制
        if cpufreq-set -g ondemand; then
            log_info "成功设置 CPU 调频机制为 ondemand"
        else
            log_error "设置 CPU 调频机制失败"
            return 1
        fi
    else
        log_info "CPU 调频机制已经是 ondemand，无需更改"
    fi
    
    return 0
}

# 下载并设置 CPU 控制脚本
setup_cpu_control_script() {
    log_info "下载 CPU 控制脚本..."
    
    # 创建目录（如果不存在）
    mkdir -p /usr/sbin/
    
    # 下载脚本
    if wget -O /usr/sbin/cpu-control.sh https://raw.githubusercontent.com/yuanxing109/WKY-Scripts/main/scripts/cpu-control.sh; then
        log_info "成功下载 CPU 控制脚本"
    else
        log_error "下载 CPU 控制脚本失败"
        return 1
    fi
    
    # 设置权限
    log_info "设置脚本权限..."
    chmod 755 /usr/sbin/cpu-control.sh
    
    return 0
}

# 创建并启用系统服务
setup_systemd_service() {
    log_info "创建系统服务..."
    
    # 创建服务文件
    cat > /lib/systemd/system/cpu-control.service << EOF
[Unit]
Description=CPU Governor Control by Temperature
After=multi-user.target

[Service]
Type=simple
ExecStart=/bin/sh /usr/sbin/cpu-control.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载系统守护进程
    log_info "重载系统守护进程..."
    systemctl daemon-reload
    
    # 启动服务
    log_info "启动 CPU 控制服务..."
    if systemctl start cpu-control.service; then
        log_info "成功启动 CPU 控制服务"
    else
        log_error "启动 CPU 控制服务失败"
        return 1
    fi
    
    # 启用开机自启动
    log_info "启用开机自启动..."
    if systemctl enable cpu-control.service; then
        log_info "成功启用开机自启动"
    else
        log_error "启用开机自启动失败"
        return 1
    fi
    
    # 检查服务状态
    log_info "检查服务状态..."
    systemctl status cpu-control.service --no-pager
    
    return 0
}

# 主函数
main() {
    log_info "开始玩客云 CPU 调频设置..."
    
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
    
    # 执行设置步骤
    if ! setup_cpu_governor; then
        log_error "CPU 调频设置失败"
        exit 1
    fi
    
    if ! setup_cpu_control_script; then
        log_error "CPU 控制脚本设置失败"
        exit 1
    fi
    
    if ! setup_systemd_service; then
        log_error "系统服务设置失败"
        exit 1
    fi
    
    log_info "玩客云 CPU 调频设置完成！"
    log_info "请运行 'systemctl status cpu-control.service' 检查服务状态"
}

# 执行主函数
main "$@"
