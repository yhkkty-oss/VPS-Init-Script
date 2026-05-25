#!/bin/sh

# ==================================================
# VPS 初始化脚本
# 兼容：
# Alpine / Debian / Ubuntu / CentOS / BusyBox
# ==================================================

clear

echo "=============================="
echo "VPS 初始化脚本"
echo "=============================="
echo

# ==================================================
# SSH 公钥
# ==================================================

NAT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLqn9LgwkGOhWBvqRnMg7NGo3z/3nV1qFm7dsuueGKm Generated-By-NeoServer'

ROOT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE23Oz0PWi6phUxz0AylhhKMniWY9FA/WKlmEUpbVwpV Generated-By-NeoServer'

# ==================================================
# 创建 SSH 目录
# ==================================================

mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys

chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# ==================================================
# 显示已有公钥
# ==================================================

echo "当前 authorized_keys 内容："
echo "------------------------------"

if [ -s ~/.ssh/authorized_keys ]; then
    cat ~/.ssh/authorized_keys
else
    echo "暂无公钥"
fi

echo "------------------------------"
echo

# ==================================================
# 询问写入公钥
# ==================================================

echo "请选择要写入的 SSH 公钥："
echo "1) nat 公钥"
echo "2) root 公钥"
echo "3) 两个都写入"
echo "4) 跳过"
echo

printf "请输入选项: "
read keychoice

case "$keychoice" in
    1)
        grep -qF "$NAT_KEY" ~/.ssh/authorized_keys || echo "$NAT_KEY" >> ~/.ssh/authorized_keys
        echo "已写入 nat 公钥"
        ;;
    2)
        grep -qF "$ROOT_KEY" ~/.ssh/authorized_keys || echo "$ROOT_KEY" >> ~/.ssh/authorized_keys
        echo "已写入 root 公钥"
        ;;
    3)
        grep -qF "$NAT_KEY" ~/.ssh/authorized_keys || echo "$NAT_KEY" >> ~/.ssh/authorized_keys
        grep -qF "$ROOT_KEY" ~/.ssh/authorized_keys || echo "$ROOT_KEY" >> ~/.ssh/authorized_keys
        echo "已写入两个公钥"
        ;;
    4)
        echo "跳过写入公钥"
        ;;
    *)
        echo "无效选项"
        exit 1
        ;;
esac

echo

# ==================================================
# SSH 配置
# ==================================================

echo "正在配置 SSH..."

SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then

    sed -i 's/^#PermitRootLogin./PermitRootLogin yes/g' "$SSHD_CONFIG"

    sed -i 's/^#PubkeyAuthentication./PubkeyAuthentication yes/g' "$SSHD_CONFIG"

    sed -i 's/^#PasswordAuthentication./PasswordAuthentication no/g' "$SSHD_CONFIG"

    echo "SSH 配置完成"
else
    echo "未找到 sshd_config"
fi

echo

# ==================================================
# 重启 SSH
# ==================================================

echo "重启 SSH 服务..."

if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh || systemctl restart sshd

elif command -v service >/dev/null 2>&1; then
    service ssh restart || service sshd restart

elif [ -f /etc/init.d/sshd ]; then
    /etc/init.d/sshd restart

elif [ -f /etc/init.d/ssh ]; then
    /etc/init.d/ssh restart

else
    echo "无法自动重启 SSH"
fi

echo

# ==================================================
# 修改主机名
# ==================================================

printf "是否修改主机名？(y/n): "
read changehost

if [ "$changehost" = "y" ] || [ "$changehost" = "Y" ]; then

    printf "请输入新的主机名: "
    read newhost

    if [ -n "$newhost" ]; then

        hostname "$newhost"

        echo "$newhost" > /etc/hostname

        echo "主机名已修改为: $newhost"
    fi
fi

echo

# ==================================================
# 时区设置
# ==================================================

echo "时区选项："
echo "1) Asia/Shanghai"
echo "2) 保持当前"
echo

printf "请选择: "
read tzchoice

case "$tzchoice" in
    1)
        if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
            ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
            echo "Asia/Shanghai" > /etc/timezone 2>/dev/null
            echo "时区已修改为 Asia/Shanghai"
        else
            echo "系统没有 zoneinfo"
        fi
        ;;
    *)
        echo "保持当前时区"
        ;;
esac

echo

# ==================================================
# Swap 设置
# ==================================================

echo "Swap 选项："
echo "1) 512M"
echo "2) 1G"
echo "3) 2G"
echo "4) 跳过"
echo

printf "请选择: "
read swapchoice

case "$swapchoice" in
    1)
        SWAPSIZE=512
        ;;
    2)
        SWAPSIZE=1024
        ;;
    3)
        SWAPSIZE=2048
        ;;
    *)
        SWAPSIZE=0
        ;;
esac

if [ "$SWAPSIZE" -gt 0 ]; then

    if grep -q "swap" /proc/filesystems; then

        echo "创建 ${SWAPSIZE}M Swap..."

        dd if=/dev/zero of=/swapfile bs=1M count="$SWAPSIZE"

        chmod 600 /swapfile

        mkswap /swapfile

        swapon /swapfile

        if [ $? -eq 0 ]; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
            echo "Swap 创建成功"
        else
            echo "Swap 启用失败"
            echo "可能是 OpenVZ / LXC 不支持"
        fi

    else
        echo "系统不支持 swap"
    fi
fi

echo

# ==================================================
# 完成
# ==================================================

echo "=============================="
echo "初始化完成"
echo "=============================="
echo
echo "SSH 密码登录已关闭"
echo "请确认公钥可以登录后再退出"
echo