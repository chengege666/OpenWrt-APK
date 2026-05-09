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
            k|K)
                custom_command
                ;;
            00)
                uninstall_store
                ;;
            000)
                update_store
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

uninstall_store() {
    echo ""
    echo "================================"
    echo " 卸载 OpenWrt APK Store"
    echo "================================"
    echo ""
    echo "将删除以下内容："
    echo "  - 脚本目录: ${SCRIPT_DIR}"
    echo "  - 缓存目录: ${CACHE_DIR}"
    echo "  - 快捷命令: /usr/bin/apk-store"
    echo ""
    printf "确认卸载？(y/n): "
    read_input
    case "$choice" in
        y|Y|yes|YES)
            rm -rf "${SCRIPT_DIR}"
            rm -rf "${CACHE_DIR}"
            rm -f /usr/bin/apk-store
            echo "[成功] 脚本已卸载"
            exit 0
            ;;
        *)
            echo "[取消] 已取消卸载"
            sleep 1
            ;;
    esac
}

update_store() {
    echo ""
    echo "================================"
    echo " 更新 OpenWrt APK Store"
    echo "================================"
    echo ""

    local tmp_dir="/tmp/apk-store-update"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir/core" "$tmp_dir/plugins"

    echo "[下载] 正在获取最新版本..."

    local fail=0

    wget -q --timeout=30 -O "${tmp_dir}/store.sh" "https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/store.sh" 2>/dev/null || fail=1
    wget -q --timeout=30 -O "${tmp_dir}/install.sh" "https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh" 2>/dev/null || true

    for f in network.sh github.sh install.sh ui.sh; do
        wget -q --timeout=30 -O "${tmp_dir}/core/${f}" "https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/core/${f}" 2>/dev/null || true
    done

    for f in openclash.sh passwall.sh mosdns.sh adguardhome.sh docker.sh ddns.sh tailscale.sh; do
        wget -q --timeout=30 -O "${tmp_dir}/plugins/${f}" "https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/plugins/${f}" 2>/dev/null || true
    done

    if [ "$fail" -eq 1 ] || [ ! -s "${tmp_dir}/store.sh" ]; then
        echo "[错误] 核心文件下载失败"
        rm -rf "$tmp_dir"
        sleep 2
        return
    fi

    echo "[安装] 正在替换文件..."

    cp -f "${tmp_dir}/store.sh" "${SCRIPT_DIR}/store.sh"
    cp -f "${tmp_dir}/install.sh" "${SCRIPT_DIR}/install.sh" 2>/dev/null

    for f in network.sh github.sh install.sh ui.sh; do
        cp -f "${tmp_dir}/core/${f}" "${SCRIPT_DIR}/core/${f}" 2>/dev/null
    done

    for f in openclash.sh passwall.sh mosdns.sh adguardhome.sh docker.sh ddns.sh tailscale.sh; do
        cp -f "${tmp_dir}/plugins/${f}" "${SCRIPT_DIR}/plugins/${f}" 2>/dev/null
    done

    rm -rf "$tmp_dir"

    echo "[成功] 脚本更新完成"
    echo ""
    echo "[重启] 正在启动新版本..."
    echo ""

    exec sh "${SCRIPT_DIR}/store.sh"
}

custom_command() {
    echo ""
    echo "================================"
    echo " 自定义命令"
    echo "================================"
    echo ""
    printf "输入命令: "
    read_input
    if [ -n "$choice" ]; then
        echo ""
        echo "[执行] $choice"
        echo "--------------------------------"
        eval "$choice"
        echo "--------------------------------"
        echo "[完成] 命令执行完毕"
    else
        echo "[取消] 未输入命令"
    fi
    echo ""
    printf "按回车键继续..."
    read -r dummy
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
