#!/bin/sh
# core/ui.sh - 用户界面模块

show_main_menu() {
    echo "================================"
    echo " OpenWrt APK Store"
    echo "================================"
    echo ""
    echo "1.   安装插件"
    echo "2.   卸载插件"
    echo "3.   更新插件"
    echo "4.   一键配置启动快捷键"
    echo "00.  卸载脚本"
    echo "000. 更新脚本"
    echo "0.   退出"
    echo ""
}

show_install_plugin_menu() {
    echo "================================"
    echo " 安装插件"
    echo "================================"
    echo ""
    echo "1.   OpenClash"
    echo "2.   PassWall"
    echo "3.   MosDNS"
    echo "4.   AdGuardHome"
    echo "5.   Docker"
    echo "6.   Aurora 主题"
    echo "0.   返回上级"
    echo ""
}

show_shortcut_list() {
    if [ ! -f "${CUSTOM_CONFIG}" ] || [ ! -s "${CUSTOM_CONFIG}" ]; then
        echo "[提示] 暂无已设置的快捷键"
    else
        echo "当前快捷键:"
        while IFS='=' read -r key cmd; do
            echo "  ${key} -> ${cmd}"
        done < "$CUSTOM_CONFIG"
    fi
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
echo "6. 卸载 Aurora 主题"
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
echo "6. 更新 Aurora 主题"
echo "7. 更新全部"
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
