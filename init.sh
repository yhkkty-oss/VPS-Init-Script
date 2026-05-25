#!/bin/sh

# ==========================================
# VPS 初始化脚本 Pro
# 兼容:
# Debian / Ubuntu / CentOS / AlmaLinux / Rocky
# ==========================================

LOG_FILE="/root/init.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=============================="
echo "VPS 初始化脚本 Pro"
echo "=============================="
echo

# =========================
# 退出函数
# =========================

exit_script() {
    echo
    echo "脚本已退出"
    exit 0
}

# =========================
# 检测系统
# =========================

if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
else
    OS="unknown"
fi

echo "系统类型: $OS"
echo

# =========================
# 检测虚拟化
# =========================

VIRT=$(systemd-detect-virt 2>/dev/null)

[ -z "$VIRT" ] && VIRT="unknown"

echo "虚拟化类型: $VIRT"
echo

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
# 公钥
# =========================

NAT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLqn9LgwkGOhWBvqRnMg7NGo3z/3nV1qFm7dsuueGKm NAT'

ROOT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE23Oz0PWi6phUxz0AylhhKMniWY9FA/WKlmEUpbVwpV ROOT'

# =========================
# 查看已有公钥
# =========================

echo "当前 authorized_keys 内容："
echo "------------------------------"

if [ -s "$AUTHORIZED_KEYS" ]; then
    cat "$AUTHORIZED_KEYS"
else
    echo "暂无公钥"
fi

echo "------------------------------"
echo

# =========================
# 写入公钥
# =========================

while true
do

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

echo "已写入 nat 公钥"
break
;;

2)

grep -qxF "$ROOT_KEY" "$AUTHORIZED_KEYS" || echo "$ROOT_KEY" >> "$AUTHORIZED_KEYS"

echo "已写入 root 公钥"
break
;;

3)

grep -qxF "$NAT_KEY" "$AUTHORIZED_KEYS" || echo "$NAT_KEY" >> "$AUTHORIZED_KEYS"

grep -qxF "$ROOT_KEY" "$AUTHORIZED_KEYS" || echo "$ROOT_KEY" >> "$AUTHORIZED_KEYS"

echo "已写入两个公钥"
break
;;

4)

echo "跳过写入公钥"
break
;;

0)

exit_script
;;

*)

echo "无效选项"
echo
;;

esac

done

chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"

# =========================
# SSH 配置函数
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

echo
echo "配置 SSH..."
echo

# =========================
# SSH 基础配置
# =========================

set_sshd_option PubkeyAuthentication yes
set_sshd_option AuthorizedKeysFile .ssh/authorized_keys
set_sshd_option PermitRootLogin yes

# =========================
# SSH 密码登录选项
# =========================

while true
do

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

echo "已保留密码登录"
break
;;

2)

if [ ! -s "$AUTHORIZED_KEYS" ]; then

    echo
    echo "未检测到公钥"
    echo "禁止关闭密码登录"
    echo

    continue

fi

set_sshd_option PasswordAuthentication no

echo
echo "警告："
echo "请确认 SSH 公钥登录可用"
echo

break
;;

0)

exit_script
;;

*)

echo "无效选项"
echo
;;

esac

done

# =========================
# 检测 SSH 配置
# =========================

echo
echo "检测 SSH 配置..."
echo

if sshd -t 2>/tmp/sshd_error.log; then

    echo "SSH 配置正常"

else

    echo "SSH 配置错误："
    cat /tmp/sshd_error.log

    exit 1

fi

# =========================
# 重启 SSH
# =========================

echo
echo "重启 SSH 服务..."
echo

if command -v systemctl >/dev/null 2>&1; then

    systemctl restart ssh 2>/dev/null || \
    systemctl restart sshd 2>/dev/null

else

    service ssh restart 2>/dev/null || \
    service sshd restart 2>/dev/null

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

    hostnamectl set-hostname "$new_hostname" 2>/dev/null || \
    hostname "$new_hostname"

    echo "$new_hostname" > /etc/hostname

    echo "主机名已修改为: $new_hostname"

fi

break
;;

n|N)

echo "跳过主机名修改"
break
;;

0)

exit_script
;;

*)

echo "无效选项"
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

echo "时区已修改为 Asia/Shanghai"

break
;;

2)

echo "保持当前时区"

break
;;

0)

exit_script
;;

*)

echo "无效选项"
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

echo "无效选项"
;;

esac

done

if [ -n "$SWAP_SIZE" ]; then

echo
echo "创建 Swap: $SWAP_SIZE"

fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null || \
dd if=/dev/zero of=/swapfile bs=1M count=$(echo "$SWAP_SIZE" | sed 's/G/*1024/' | sed 's/M//g' | bc)

chmod 600 /swapfile

mkswap /swapfile

swapon /swapfile

grep -q "/swapfile" /etc/fstab || \
echo "/swapfile none swap sw 0 0" >> /etc/fstab

echo "Swap 创建完成"

fi

# =========================
# 完成
# =========================

echo
echo "=============================="
echo "初始化完成"
echo "=============================="
echo
echo "日志文件: $LOG_FILE"
echo
echo "当前 SSH 配置："

grep -E 'PermitRootLogin|PasswordAuthentication|PubkeyAuthentication' /etc/ssh/sshd_config

echo
echo "请务必测试 SSH 公钥登录"
echo
echo "建议："
echo "确认公钥登录正常后"
echo "再关闭密码登录"
echo