#!/bin/sh
# store.sh - OpenWrt APK Store 主安装器

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "${SCRIPT_DIR}/core/network.sh"
. "${SCRIPT_DIR}/core/github.sh"
. "${SCRIPT_DIR}/core/install.sh"
. "${SCRIPT_DIR}/core/ui.sh"

. "${SCRIPT_DIR}/plugins/openclash.sh"
. "${SCRIPT_DIR}/plugins/passwall.sh"
. "${SCRIPT_DIR}/plugins/mosdns.sh"
. "${SCRIPT_DIR}/plugins/adguardhome.sh"
. "${SCRIPT_DIR}/plugins/docker.sh"
. "${SCRIPT_DIR}/plugins/ddns.sh"
. "${SCRIPT_DIR}/plugins/tailscale.sh"

TTY="/dev/tty"

read_input() {
    read -r choice < "$TTY" 2>/dev/null || read -r choice
    choice=$(echo "$choice" | tr -d '\r\n ')
}

main_menu() {
    while true; do
        show_main_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                install_openclash
                wait_for_enter
                ;;
            2)
                install_passwall
                wait_for_enter
                ;;
            3)
                install_mosdns
                wait_for_enter
                ;;
            4)
                install_adguardhome
                wait_for_enter
                ;;
            5)
                install_docker
                wait_for_enter
                ;;
            6)
                install_ddns
                wait_for_enter
                ;;
            7)
                install_tailscale
                wait_for_enter
                ;;
            8)
                uninstall_menu
                ;;
            9)
                update_menu
                ;;
            0)
                echo "退出 OpenWrt APK Store"
                exit 0
                ;;
            *)
                echo "[错误] 无效输入，请重新选择"
                sleep 1
                ;;
        esac
    done
}

uninstall_menu() {
    while true; do
        show_uninstall_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                uninstall_openclash
                wait_for_enter
                ;;
            2)
                uninstall_passwall
                wait_for_enter
                ;;
            3)
                uninstall_mosdns
                wait_for_enter
                ;;
            4)
                uninstall_adguardhome
                wait_for_enter
                ;;
            5)
                uninstall_docker
                wait_for_enter
                ;;
            6)
                uninstall_ddns
                wait_for_enter
                ;;
            7)
                uninstall_tailscale
                wait_for_enter
                ;;
            0)
                return
                ;;
            *)
                echo "[错误] 无效输入，请重新选择"
                sleep 1
                ;;
        esac
    done
}

update_menu() {
    while true; do
        show_update_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                update_openclash
                wait_for_enter
                ;;
            2)
                update_passwall
                wait_for_enter
                ;;
            3)
                update_mosdns
                wait_for_enter
                ;;
            4)
                update_adguardhome
                wait_for_enter
                ;;
            5)
                update_docker
                wait_for_enter
                ;;
            6)
                update_ddns
                wait_for_enter
                ;;
            7)
                update_tailscale
                wait_for_enter
                ;;
            8)
                update_all
                wait_for_enter
                ;;
            0)
                return
                ;;
            *)
                echo "[错误] 无效输入，请重新选择"
                sleep 1
                ;;
        esac
    done
}

update_all() {
    echo ""
    echo "================================"
    echo " 更新全部插件"
    echo "================================"
    echo ""

    cleanup_old_cache

    update_openclash
    update_passwall
    update_mosdns
    update_adguardhome
    update_docker
    update_ddns
    update_tailscale

    echo ""
    echo "================================"
    echo " 全部更新完成"
    echo "================================"
    echo ""
}

init() {
    echo "================================"
    echo " OpenWrt APK Store"
    echo "================================"
    echo ""

    if ! check_internet; then
        echo "[错误] 网络连接失败，请检查网络"
        exit 1
    fi

    echo "[检查] 网络连接正常"

    local arch
    arch=$(detect_arch) || {
        echo "[错误] 不支持的架构"
        exit 1
    }
    echo "[架构] $arch"

    init_cache
    echo "[初始化] 缓存目录就绪"
    echo ""
}

init
main_menu
