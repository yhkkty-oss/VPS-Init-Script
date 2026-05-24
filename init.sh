#!/usr/bin/env bash

set -e

GREEN="\033[32m"YELLOW="\033[33m"RED="\033[31m"RESET="\033[0m"

clear

echo -e "${GREEN}"echo "=================================="echo "         VPS INIT SCRIPT          "echo "=================================="echo -e "${RESET}"

=========================

Detect OS

=========================

if [ -f /etc/alpine-release ]; thenOS="alpine"elif [ -f /etc/debian_version ]; thenOS="debian"elseecho -e "${RED}Unsupported OS${RESET}"exit 1fi

echo -e "${GREEN}Detected OS:${RESET} $OS"

=========================

Update packages

=========================

echoread -p "Update system packages? (y/n): " update_system

if [ "$update_system" = "y" ]; then

if [ "$OS" = "alpine" ]; then
    apk update && apk upgrade
    apk add bash curl wget sudo tzdata
else
    apt update && apt upgrade -y
    apt install -y curl wget sudo tzdata
fi

echo -e "${GREEN}System updated.${RESET}"

fi

=========================

SSH Public Key

=========================

echoread -p "Install SSH public key? (y/n): " install_key

if [ "$install_key" = "y" ]; then

mkdir -p ~/.ssh
chmod 700 ~/.ssh

echo
echo "Paste your SSH public key:"
read -r PUBKEY

echo "$PUBKEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo -e "${GREEN}SSH key installed.${RESET}"

echo
read -p "Disable password login? (y/n): " disable_pass

if [ "$disable_pass" = "y" ]; then

    if [ -f /etc/ssh/sshd_config ]; then

        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart ssh || systemctl restart sshd
        else
            service ssh restart || service sshd restart
        fi

        echo -e "${GREEN}Password login disabled.${RESET}"
    fi
fi

fi

=========================

Hostname

=========================

echoread -p "Change hostname? (y/n): " change_host

if [ "$change_host" = "y" ]; then

read -p "New hostname: " NEW_HOSTNAME

if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
else
    echo "$NEW_HOSTNAME" > /etc/hostname
    hostname "$NEW_HOSTNAME"
fi

echo -e "${GREEN}Hostname changed.${RESET}"

fi

=========================

Timezone

=========================

echoecho "Timezone options:"echo "1) Asia/Shanghai"echo "2) Keep current"

read -p "Choose: " tz_choice

if [ "$tz_choice" = "1" ]; then

if [ "$OS" = "alpine" ]; then
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" > /etc/timezone
else
    timedatectl set-timezone Asia/Shanghai
fi

echo -e "${GREEN}Timezone updated.${RESET}"

fi

=========================

WARP Option

=========================

echoecho "WARP options:"echo "1) Keep current network"echo "2) Reserved for future WARP install"

read -p "Choose: " warp_choice

currently keep-only

=========================

Swap

=========================

echoecho "Swap options:"echo "1) 512M"echo "2) 1G"echo "3) 2G"echo "4) Skip"

read -p "Choose: " swap_choice

case $swap_choice in1) SWAPSIZE=512M ;;2) SWAPSIZE=1G ;;3) SWAPSIZE=2G ;;*) SWAPSIZE="" ;;esac

if [ -n "$SWAPSIZE" ]; then

if [ "$OS" = "alpine" ]; then
    apk add --no-cache util-linux
fi

fallocate -l $SWAPSIZE /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024

chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

grep -q "/swapfile" /etc/fstab || \
echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo -e "${GREEN}Swap created: $SWAPSIZE${RESET}"

fi

=========================

Alias

=========================

echoread -p "Install common aliases? (y/n): " install_alias

if [ "$install_alias" = "y" ]; then

cat >> ~/.bashrc << 'EOF'

alias ll='ls -alF'alias la='ls -A'alias l='ls -CF'

alias cls='clear'

alias dps='docker ps -a'alias di='docker images'

EOF

echo -e "${GREEN}Aliases installed.${RESET}"

fi

=========================

VPS Summary

=========================

IPV4=$(curl -4 -s ip.sb || true)IPV6=$(curl -6 -s ip.sb || true)HOSTNAME=$(hostname)TIMEZONE=$(cat /etc/timezone 2>/dev/null || timedatectl | grep "Time zone" | awk '{print $3}')MEMORY=$(free -h | awk '/Mem:/ {print $2}')SWAP=$(free -h | awk '/Swap:/ {print $2}')

echoecho -e "${GREEN}=================================="echo "           VPS SUMMARY           "echo "=================================="echo -e "${RESET}"

echo "Hostname : $HOSTNAME"echo "OS       : $OS"echo "IPv4     : $IPV4"echo "IPv6     : $IPV6"echo "Timezone : $TIMEZONE"echo "Memory   : $MEMORY"echo "Swap     : $SWAP"

echoecho -e "${GREEN}Initialization Complete.${RESET}"