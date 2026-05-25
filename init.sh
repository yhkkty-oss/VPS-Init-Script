#!/bin/sh

# ==================================================
# VPS 初始化脚本 Pro Max
# 支持:
# Debian / Ubuntu / CentOS / AlmaLinux / Rocky
# ==================================================

# =========================
# 颜色
# =========================

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

# =========================
# 日志
# =========================

LOG_FILE="/root/init.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# =========================
# Ctrl+C 捕获
# =========================

trap 'echo; echo "${RED}脚本已中断${NC}"; exit 1' INT

# =========================
# 基础函数
# =========================

clear_screen() {
    clear
}

header() {

    clear

    echo "=================================================="
    echo "$1"
    echo "=================================================="
    echo
}

log() {
    echo "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo "${RED}[ERROR]${NC} $1"
}

pause() {
    echo
    read -p "按回车继续..." temp
}

exit_script() {

    echo
    warn "脚本已退出"

    exit 0
}

check_root() {

    if [ "$(id -u)" != "0" ]; then

        error "请使用 root 运行"

        exit 1

    fi
}

confirm() {

    while true
    do

        printf "%s (y/n): " "$1"

        read ans

        case "$ans" in

        y|Y)
            return 0
            ;;

        n|N)
            return 1
            ;;

        *)
            echo "请输入 y 或 n"
            ;;
        esac

    done
}

# =========================
# SSH 服务检测
# =========================

detect_ssh_service() {

    if systemctl list-unit-files 2>/dev/null | grep -q "^ssh.service"; then

        SSH_SERVICE="ssh"

    else

        SSH_SERVICE="sshd"

    fi
}

# =========================
# SSH 配置修改
# =========================

set_sshd_option() {

    KEY="$1"
    VALUE="$2"

    SSHD_CONFIG="/etc/ssh/sshd_config"

    if grep -q "^#*$KEY" "$SSHD_CONFIG"; then

        sed -i "s|^#*$KEY.*|$KEY $VALUE|g" "$SSHD_CONFIG"

    else

        echo "$KEY $VALUE" >> "$SSHD_CONFIG"

    fi
}

# =========================
# 防锁死恢复
# =========================

start_ssh_recovery() {

(
sleep 600

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then

    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    systemctl restart "$SSH_SERVICE" 2>/dev/null

fi

) &

RECOVERY_PID=$!

echo "$RECOVERY_PID" > /tmp/ssh_recovery.pid

warn "已启用 10 分钟 SSH 自动恢复机制"

}

cancel_ssh_recovery() {

if [ -f /tmp/ssh_recovery.pid ]; then

    PID=$(cat /tmp/ssh_recovery.pid)

    kill "$PID" 2>/dev/null

    rm -f /tmp/ssh_recovery.pid

    log "SSH 自动恢复机制已取消"

fi

}

# =========================
# 初始化
# =========================

check_root

header "VPS 初始化脚本 Pro Max"

# =========================
# 系统检测
# =========================

if [ -f /etc/debian_version ]; then

    OS="debian"

elif [ -f /etc/redhat-release ]; then

    OS="redhat"

else

    OS="unknown"

fi

log "系统类型: $OS"

# =========================
# 虚拟化检测
# =========================

VIRT=$(systemd-detect-virt 2>/dev/null)

[ -z "$VIRT" ] && VIRT="unknown"

log "虚拟化类型: $VIRT"

# =========================
# SSH 服务
# =========================

detect_ssh_service

log "SSH 服务: $SSH_SERVICE"

# =========================
# SSH 文件
# =========================

SSH_DIR="$HOME/.ssh"

AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"

touch "$AUTHORIZED_KEYS"

chmod 700 "$SSH_DIR"

chmod 600 "$AUTHORIZED_KEYS"

# =========================
# 备份 SSH 配置
# =========================

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

log "已备份 sshd_config"

# =========================
# 公钥
# =========================

NAT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLqn9LgwkGOhWBvqRnMg7NGo3z/3nV1qFm7dsuueGKm Generated-By-NeoServer'

ROOT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE23Oz0PWi6phUxz0AylhhKMniWY9FA/WKlmEUpbVwpV Generated-By-NeoServer'

# =========================
# 查看已有公钥
# =========================

echo
echo "当前 authorized_keys 内容："
echo "--------------------------------------------------"

if [ -s "$AUTHORIZED_KEYS" ]; then

    cat "$AUTHORIZED_KEYS"

else

    warn "暂无公钥"

fi

echo "--------------------------------------------------"

# =========================
# 写入公钥
# =========================

while true
do

echo
echo "请选择要写入的 SSH 公钥："
echo "1) nat 公钥"
echo "2) root 公钥"
echo "3) 两个都写入"
echo "4) 跳过"
echo "0) 退出脚本"
echo

printf "请输入选项: "

read key_choice

case "$key_choice" in

1)

grep -qxF "$NAT_KEY" "$AUTHORIZED_KEYS" || echo "$NAT_KEY" >> "$AUTHORIZED_KEYS"

log "已写入 nat 公钥"

break
;;

2)

grep -qxF "$ROOT_KEY" "$AUTHORIZED_KEYS" || echo "$ROOT_KEY" >> "$AUTHORIZED_KEYS"

log "已写入 root 公钥"

break
;;

3)

grep -qxF "$NAT_KEY" "$AUTHORIZED_KEYS" || echo "$NAT_KEY" >> "$AUTHORIZED_KEYS"

grep -qxF "$ROOT_KEY" "$AUTHORIZED_KEYS" || echo "$ROOT_KEY" >> "$AUTHORIZED_KEYS"

log "已写入两个公钥"

break
;;

4)

warn "跳过写入公钥"

break
;;

0)

exit_script
;;

*)

error "无效选项"
;;

esac

done

chmod 700 "$SSH_DIR"

chmod 600 "$AUTHORIZED_KEYS"

# =========================
# SSH 配置
# =========================

echo
log "配置 SSH..."

set_sshd_option PubkeyAuthentication yes
set_sshd_option AuthorizedKeysFile .ssh/authorized_keys
set_sshd_option PermitRootLogin yes

# =========================
# SSH 登录模式
# =========================

while true
do

echo
echo "SSH 安全选项："
echo "1) 保持密码登录（推荐）"
echo "2) 关闭密码登录"
echo "0) 退出脚本"
echo

printf "请选择: "

read sshmode

case "$sshmode" in

1)

set_sshd_option PasswordAuthentication yes

log "已保留密码登录"

break
;;

2)

if [ ! -s "$AUTHORIZED_KEYS" ]; then

    error "未检测到公钥"

    continue

fi

set_sshd_option PasswordAuthentication no

log "已关闭密码登录"

start_ssh_recovery

break
;;

0)

exit_script
;;

*)

error "无效选项"
;;

esac

done

# =========================
# SSH 配置检测
# =========================

echo
log "检测 SSH 配置..."

if sshd -t 2>/tmp/sshd_error.log; then

    log "SSH 配置正常"

else

    error "SSH 配置错误"

    cat /tmp/sshd_error.log

    cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config

    error "已恢复原 SSH 配置"

    exit 1

fi

# =========================
# 重启 SSH
# =========================

echo
log "重启 SSH 服务..."

if command -v systemctl >/dev/null 2>&1; then

    systemctl restart "$SSH_SERVICE"

else

    service "$SSH_SERVICE" restart

fi

# =========================
# 主机名
# =========================

while true
do

echo
printf "是否修改主机名？(y/n/0退出): "

read hostname_choice

case "$hostname_choice" in

y|Y)

printf "请输入新的主机名: "

read new_hostname

if [ -n "$new_hostname" ]; then

    hostnamectl set-hostname "$new_hostname" 2>/dev/null || hostname "$new_hostname"

    echo "$new_hostname" > /etc/hostname

    log "主机名已修改为: $new_hostname"

fi

break
;;

n|N)

warn "跳过主机名修改"

break
;;

0)

exit_script
;;

*)

error "无效选项"
;;

esac

done

# =========================
# 时区
# =========================

while true
do

echo
echo "时区选项："
echo "1) Asia/Shanghai"
echo "2) 保持当前"
echo "0) 退出脚本"
echo

printf "请选择: "

read timezone_choice

case "$timezone_choice" in

1)

timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

log "时区已修改为 Asia/Shanghai"

break
;;

2)

warn "保持当前时区"

break
;;

0)

exit_script
;;

*)

error "无效选项"
;;

esac

done

# =========================
# Swap
# =========================

while true
do

echo
echo "Swap 选项："
echo "1) 512M"
echo "2) 1G"
echo "3) 2G"
echo "4) 跳过"
echo "0) 退出脚本"
echo

printf "请选择: "

read swap_choice

case "$swap_choice" in

1)
SWAP_SIZE=512M
break
;;

2)
SWAP_SIZE=1G
break
;;

3)
SWAP_SIZE=2G
break
;;

4)
SWAP_SIZE=""
break
;;

0)

exit_script
;;

*)

error "无效选项"
;;

esac

done

if [ -n "$SWAP_SIZE" ]; then

echo
log "创建 Swap: $SWAP_SIZE"

fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null || \
dd if=/dev/zero of=/swapfile bs=1M count=$(echo "$SWAP_SIZE" | sed 's/G/*1024/' | sed 's/M//g' | bc)

chmod 600 /swapfile

mkswap /swapfile

swapon /swapfile

grep -q "/swapfile" /etc/fstab || \
echo "/swapfile none swap sw 0 0" >> /etc/fstab

log "Swap 创建完成"

fi

# =========================
# 完成
# =========================

echo
echo "=================================================="
echo "初始化完成"
echo "=================================================="
echo

echo "日志文件: $LOG_FILE"

echo
echo "当前 SSH 配置："
echo

grep -E 'PermitRootLogin|PasswordAuthentication|PubkeyAuthentication' /etc/ssh/sshd_config

echo
warn "请务必测试 SSH 公钥登录"

echo
echo "如果确认公钥登录正常："
echo "可再次运行脚本关闭密码登录"

echo