#!/bin/bash

# Armbian源公钥问题解决脚本
# 支持多镜像源选择，适用于Debian/Armbian系统
# 执行需root权限

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 镜像源列表
declare -A MIRRORS=(
    ["1"]="南京大学|https://mirrors.nju.edu.cn/armbian"
    ["2"]="清华大学|https://mirrors.tuna.tsinghua.edu.cn/armbian"
    ["3"]="中国科技大学|https://mirrors.ustc.edu.cn/armbian"
    ["4"]="上海交通大学|https://mirror.sjtu.edu.cn/armbian"
    ["5"]="华为云|https://mirrors.huaweicloud.com/armbian"
    ["6"]="腾讯云|https://mirrors.cloud.tencent.com/armbian"
)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Armbian源公钥问题解决脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用sudo或root用户运行此脚本${NC}"
    exit 1
fi

# 获取系统代号
CODENAME=$(lsb_release -cs)
echo -e "${BLUE}检测到系统代号: ${CODENAME}${NC}"

# 显示镜像源选择菜单
echo -e "${YELLOW}请选择镜像源:${NC}"
for key in "${!MIRRORS[@]}"; do
    IFS='|' read -ra MIRROR_INFO <<< "${MIRRORS[$key]}"
    echo -e "${BLUE}[${key}] ${MIRROR_INFO[0]}${NC}"
done

# 获取用户选择
read -p "请输入选项编号 (默认:1): " CHOICE
CHOICE=${CHOICE:-1}

# 验证选择有效性
if [[ -z "${MIRRORS[$CHOICE]}" ]]; then
    echo -e "${RED}错误: 无效的选择${NC}"
    exit 1
fi

# 解析选择的镜像源
IFS='|' read -ra SELECTED_MIRROR <<< "${MIRRORS[$CHOICE]}"
MIRROR_NAME="${SELECTED_MIRROR[0]}"
MIRROR_URL="${SELECTED_MIRROR[1]}"
KEY_URL="${MIRROR_URL}/armbian.key"

echo -e "${GREEN}已选择: ${MIRROR_NAME}${NC}"
echo -e "${BLUE}镜像地址: ${MIRROR_URL}${NC}"

# 1. 创建APT公钥存储目录
echo -e "${YELLOW}步骤1/5: 创建APT公钥存储目录...${NC}"
mkdir -p /etc/apt/keyrings
echo -e "${GREEN}已创建目录: /etc/apt/keyrings${NC}"

# 2. 下载Armbian公钥
echo -e "${YELLOW}步骤2/5: 下载Armbian公钥...${NC}"
KEY_PATH="./armbian.key"
echo -e "${BLUE}从${MIRROR_NAME}下载公钥...${NC}"

if ! curl -fsSL "$KEY_URL" -o "$KEY_PATH"; then
    echo -e "${RED}错误: 下载公钥失败，尝试备用方案...${NC}"
    # 尝试从官方源下载
    if ! curl -fsSL "https://apt.armbian.com/armbian.key" -o "$KEY_PATH"; then
        echo -e "${RED}错误: 所有公钥下载尝试均失败，请检查网络连接${NC}"
        exit 1
    fi
    echo -e "${YELLOW}警告: 使用官方源公钥，可能会影响下载速度${NC}"
fi

# 验证公钥完整性
if ! grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$KEY_PATH"; then
    echo -e "${RED}错误: 下载的公钥文件格式不正确${NC}"
    exit 1
fi
echo -e "${GREEN}公钥下载成功且验证通过${NC}"

# 3. 转换公钥格式
echo -e "${YELLOW}步骤3/5: 转换公钥格式...${NC}"
GPG_PATH="/etc/apt/keyrings/armbian.gpg"
cat "$KEY_PATH" | gpg --dearmor -o "$GPG_PATH"
if [ $? -ne 0 ]; then
    echo -e "${RED}错误: 公钥转换失败${NC}"
    exit 1
fi
echo -e "${GREEN}公钥已转换为二进制格式: ${GPG_PATH}${NC}"

# 清理临时文件
rm -f "$KEY_PATH"

# 4. 配置Armbian源
echo -e "${YELLOW}步骤4/5: 配置Armbian源...${NC}"
SOURCE_LIST="/etc/apt/sources.list.d/armbian.list"
# 备份原有配置
if [ -f "$SOURCE_LIST" ]; then
    BACKUP_PATH="${SOURCE_LIST}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$SOURCE_LIST" "$BACKUP_PATH"
    echo -e "${GREEN}已备份原有配置: ${BACKUP_PATH}${NC}"
fi

# 写入新配置
cat > "$SOURCE_LIST" << EOF
# Armbian镜像源 (${MIRROR_NAME})
deb [signed-by=${GPG_PATH}] ${MIRROR_URL} ${CODENAME} main ${CODENAME}-utils ${CODENAME}-desktop
EOF

echo -e "${GREEN}Armbian源配置完成: ${SOURCE_LIST}${NC}"

# 5. 更新APT缓存
echo -e "${YELLOW}步骤5/5: 更新APT缓存...${NC}"
if apt update; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}成功解决Armbian源公钥问题！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}验证信息:${NC}"
    echo -e "${BLUE}1. 镜像源: ${MIRROR_NAME}${NC}"
    echo -e "${BLUE}2. 公钥路径: ${GPG_PATH}${NC}"
    echo -e "${BLUE}3. 源配置: ${SOURCE_LIST}${NC}"
else
    echo -e "${RED}APT更新过程中出现错误，请检查配置${NC}"
    exit 1
fi

# 显示公钥信息（可选）
echo -e "${YELLOW}公钥详细信息:${NC}"
gpg --show-keys "$GPG_PATH"

echo -e "${GREEN}脚本执行完成！${NC}"