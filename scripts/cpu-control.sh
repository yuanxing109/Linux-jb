#!/bin/sh

# 脚本功能：每过6秒检测一次CPU温度
# 当CPU温度低于42℃时，调整CPU频率为400MHz-1540MHz
# 当CPU温度高于46℃时，调整CPU频率为400MHz-800MHz

# 日志文件设置
LOG_FILE="/var/log/cpu_temp_monitor.log"
MAX_LOG_SIZE=5242880  # 5MB in bytes (5 * 1024 * 1024)

# 引入状态变量，防止重复执行调频命令
i=1  # 低温提高主频状态标志
j=0  # 高温降低主频状态标志

# 检查并清空日志文件函数
check_log_size() {
    if [ -f "$LOG_FILE" ] && [ $(wc -c < "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        > "$LOG_FILE"  # 清空日志文件
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 日志文件已清空" >> "$LOG_FILE"
    fi
}

# 日志记录函数
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    echo "$message"  # 同时输出到控制台
}

# 主循环
while true; do
    # 检查日志大小
    check_log_size
    
    # 读取CPU温度和当前调速器
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    
    # 温度低于42℃且使用ondemand调速器且未处于升频状态
    if [ "$TEMP" -le 42000 ] && [ "$GOVERNOR" = "ondemand" ] && [ $i -eq 1 ]; then
        cpufreq-set -d 400MHz -u 1540MHz
        log_message "已升频 (400MHz-1540MHz)"
        i=0
        j=0
    fi
    
    # 温度高于46℃且使用ondemand调速器且未处于降频状态
    if [ "$TEMP" -ge 46000 ] && [ "$GOVERNOR" = "ondemand" ] && [ $j -eq 0 ]; then
        cpufreq-set -d 400MHz -u 800MHz
        log_message "已降频 (400MHz-800MHz)"
        i=1
        j=1
    fi
    
    # 根据状态变量直接显示当前状态
    if [ $i -eq 1 ] && [ $j -eq 1 ]; then
        STATE="降频状态 (400MHz-800MHz)"
    elif [ $i -eq 0 ] && [ $j -eq 0 ]; then
        STATE="升频状态 (400MHz-1540MHz)"
    else
        STATE="初始状态 (等待温度变化)"
    fi
    
    # 简洁显示当前状态
    log_message "CPU温度: $(($TEMP / 1000))℃ | 状态: $STATE"
    
    # 等待6秒后再次检测
    sleep 6
done