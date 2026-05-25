#!/bin/sh

# ==================================================
# VPS 初始化脚本 Pro
# 兼容 Alpine / Debian / Ubuntu / CentOS
# ==================================================

set -eu

LOGFILE="/root/init.log"
exec > >(tee -a "$LOGFILE") 2>&1

clear

echo "=============================="
echo "VPS 初始化脚本 Pro"
echo "=============================="
echo

# ==================================================
# 系统检测
# ==================================================

if [ -f /etc/alpine-release ]; then
    OS="alpine"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
else
    OS="unknown"
fi

echo "系统类型: $OS"
echo

# ==================================================
# 容器检测
# ==================================================

VIRT="unknown"

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt || true)
fi

echo "虚拟化类型: $VIRT"
echo

# ==================================================
# SSH 公钥
# ==================================================

NAT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLqn9LgwkGOhWBvqRnMg7NGo3z/3nV1qFm7dsuueGKm Generated-By-NeoServer'

ROOT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE23Oz0PWi6phUxz0AylhhKMniWY9FA/WKlmEUpbVwpV Generated-By-NeoServer'

# ==================================================
# 函数
# ==================================================

pause() {
    echo
}

exit_script() {
    echo
    echo "用户退出脚本"
    exit 0
}

restart_sshd() {

    echo
    echo "重启 SSH 服务..."

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh

    elif [ -f /etc/init.d/sshd ]; then
        /etc/init.d/sshd restart

    elif [ -f /etc/init.d/ssh ]; then
        /etc/init.d/ssh restart

    else
        echo "无法自动重启 SSH"
    fi
}

set_sshd_option() {

    KEY="$1"
    VALUE="$2"

    sed -i "/^${KEY}/d" /etc/ssh/sshd_config

    echo "${KEY} ${VALUE}" >> /etc/ssh/sshd_config
}

# ==================================================
# 创建 SSH 目录
# ==================================================

mkdir -p ~/.ssh

touch ~/.ssh/authorized_keys

chmod 700 ~/.ssh

chmod 600 ~/.ssh/authorized_keys

# ==================================================
# 查看已有公钥
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
# SSH 公钥菜单
# ==================================================

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

    read keychoice

    case "$keychoice" in

        1)
            grep -qxF "$NAT_KEY" ~/.ssh/authorized_keys || echo "$NAT_KEY" >> ~/.ssh/authorized_keys
            echo "已写入 nat 公钥"
            break
            ;;

        2)
            grep -qxF "$ROOT_KEY" ~/.ssh/authorized_keys || echo "$ROOT_KEY" >> ~/.ssh/authorized_keys
            echo "已写入 root 公钥"
            break
            ;;

        3)
            grep -qxF "$NAT_KEY" ~/.ssh/authorized_keys || echo "$NAT_KEY" >> ~/.ssh/authorized_keys
            grep -qxF "$ROOT_KEY" ~/.ssh/authorized_keys || echo "$ROOT_KEY" >> ~/.ssh/authorized_keys
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
            echo
            echo "输入无效，请重新输入"
            echo
            ;;
    esac

done

# ==================================================
# SSH 配置
# ==================================================

echo
echo "配置 SSH..."

if [ -f /etc/ssh/sshd_config ]; then

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    set_sshd_option PasswordAuthentication no
    set_sshd_option PubkeyAuthentication yes
    set_sshd_option PermitRootLogin yes

    echo
    echo "检测 SSH 配置..."

    if sshd -t 2>/tmp/sshd_test.log; then

        echo "SSH 配置正常"

        restart_sshd

    else

        echo
        echo "SSH 配置错误："
        cat /tmp/sshd_test.log

        echo
        echo "恢复备份配置..."

        cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config

        restart_sshd
    fi

else

    echo "未找到 sshd_config"

fi

# ==================================================
# 修改主机名
# ==================================================

while true
do

    echo
    printf "是否修改主机名？(y/n/0退出): "

    read hostchoice

    case "$hostchoice" in

        y|Y)

            printf "请输入新的主机名: "

            read NEWHOST

            if [ -n "$NEWHOST" ]; then

                hostname "$NEWHOST"

                echo "$NEWHOST" > /etc/hostname

                echo "主机名已修改为: $NEWHOST"
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
            echo "输入无效"
            ;;
    esac

done

# ==================================================
# 时区菜单
# ==================================================

while true
do

    echo
    echo "时区选项："
    echo "1) Asia/Shanghai"
    echo "2) 保持当前"
    echo "0) 退出脚本"
    echo

    printf "请选择: "

    read tzchoice

    case "$tzchoice" in

        1)

            if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then

                ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

                echo "Asia/Shanghai" > /etc/timezone 2>/dev/null || true

                echo "时区已修改为 Asia/Shanghai"

            else

                echo "系统缺少 zoneinfo"

            fi

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

            echo "输入无效"

            ;;
    esac

done

# ==================================================
# Swap 菜单
# ==================================================

SWAPSIZE=0

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

    read swapchoice

    case "$swapchoice" in

        1)
            SWAPSIZE=512
            break
            ;;

        2)
            SWAPSIZE=1024
            break
            ;;

        3)
            SWAPSIZE=2048
            break
            ;;

        4)
            SWAPSIZE=0
            break
            ;;

        0)
            exit_script
            ;;

        *)
            echo "输入无效"
            ;;
    esac

done

# ==================================================
# 创建 Swap
# ==================================================

if [ "$SWAPSIZE" -gt 0 ]; then

    if [ "$VIRT" = "lxc" ] || [ "$VIRT" = "openvz" ]; then

        echo
        echo "当前容器类型不支持 Swap"

    else

        echo
        echo "创建 ${SWAPSIZE}M Swap..."

        dd if=/dev/zero of=/swapfile bs=1M count="$SWAPSIZE"

        chmod 600 /swapfile

        mkswap /swapfile

        if swapon /swapfile; then

            echo "/swapfile none swap sw 0 0" >> /etc/fstab

            echo "Swap 创建成功"

        else

            echo "Swap 启用失败"

        fi
    fi
fi

# ==================================================
# 完成
# ==================================================

echo
echo "=============================="
echo "初始化完成"
echo "=============================="
echo
echo "日志文件: $LOGFILE"
echo
echo "SSH 已关闭密码登录"
echo "请确认公钥登录正常"
echo