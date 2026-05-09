#!/bin/sh
# core/ui.sh - 用户界面模块

show_main_menu() {
    echo "================================"
    echo " OpenWrt APK Store"
    echo "================================"
    echo ""
    echo "1.   OpenClash"
    echo "2.   PassWall"
    echo "3.   MosDNS"
    echo "4.   AdGuardHome"
    echo "5.   Docker"
    echo "6.   DDNS"
    echo "7.   Tailscale"
    echo "8.   卸载插件"
    echo "9.   更新插件"
    echo "k.   自定义命令"
    echo "00.  卸载脚本"
    echo "000. 更新脚本"
    echo "0.   退出"
    echo ""
}

show_uninstall_menu() {
    echo "================================"
    echo " 卸载插件"
    echo "================================"
    echo ""
    echo "1. 卸载 OpenClash"
    echo "2. 卸载 PassWall"
    echo "3. 卸载 MosDNS"
    echo "4. 卸载 AdGuardHome"
    echo "5. 卸载 Docker"
    echo "6. 卸载 DDNS"
    echo "7. 卸载 Tailscale"
    echo "0. 返回上级"
    echo ""
}

show_update_menu() {
    echo "================================"
    echo " 更新插件"
    echo "================================"
    echo ""
    echo "1. 更新 OpenClash"
    echo "2. 更新 PassWall"
    echo "3. 更新 MosDNS"
    echo "4. 更新 AdGuardHome"
    echo "5. 更新 Docker"
    echo "6. 更新 DDNS"
    echo "7. 更新 Tailscale"
    echo "8. 更新全部"
    echo "0. 返回上级"
    echo ""
}

show_success() {
    echo ""
    echo "================================"
    echo " 安装成功！"
    echo "================================"
    echo ""
}

show_error() {
    echo ""
    echo "================================"
    echo " 操作失败"
    echo "================================"
    echo ""
}

show_progress() {
    local message="$1"
    echo "[进度] $message"
}

confirm_action() {
    local message="$1"
    echo ""
    echo "$message"
    printf "确认继续？(y/n): "
    read -r confirm
    case "$confirm" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_enter() {
    echo ""
    printf "按回车键继续..."
    read -r dummy
}
