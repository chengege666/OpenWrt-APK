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
            10)
                custom_menu
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
                if ! run_custom_shortcut "$choice"; then
                    echo "[错误] 无效输入，请重新选择"
                    sleep 1
                fi
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

    if [ ! -d "${SCRIPT_DIR}/.git" ]; then
        echo "[错误] 未检测到 Git 仓库"
        echo "[提示] 请使用以下方式安装："
        echo "  git clone https://github.com/chengege666/OpenWrt-APK.git /root/apk-store"
        echo "  sh /root/apk-store/store.sh"
        sleep 3
        return
    fi

    echo "[检测] 检测到 Git 仓库"
    echo "[更新] 正在执行 git pull..."

    cd "${SCRIPT_DIR}" || {
        echo "[错误] 无法进入脚本目录"
        sleep 2
        return
    }

    if git pull --ff-only 2>/dev/null; then
        echo "[成功] Git 更新成功"
    else
        local status
        status=$(git status --porcelain 2>/dev/null)
        if [ -z "$status" ]; then
            echo "[提示] 已经是最新的"
        else
            echo "[错误] Git 更新失败"
            sleep 2
            return
        fi
    fi

    echo ""
    echo "[重启] 正在重新启动脚本..."
    echo ""

    exec sh "${SCRIPT_DIR}/store.sh"
}

CUSTOM_CONFIG="${SCRIPT_DIR}/.custom_shortcuts"

custom_menu() {
    while true; do
        show_custom_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                set_shortcut
                ;;
            2)
                list_shortcuts
                ;;
            3)
                delete_shortcut
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

set_shortcut() {
    echo ""
    echo "================================"
    echo " 设置快捷键"
    echo "================================"
    echo ""
    printf "输入快捷键 (单个字母或数字): "
    read -r key < "$TTY" 2>/dev/null || read -r key
    key=$(echo "$key" | tr -d '\r\n ')

    if [ -z "$key" ] || [ ${#key} -gt 1 ]; then
        echo "[错误] 快捷键必须为单个字符"
        sleep 2
        return
    fi

    case "$key" in
        0|8|9)
            echo "[错误] 该快捷键已被系统占用"
            sleep 2
            return
            ;;
    esac

    printf "输入要执行的命令: "
    read -r cmd < "$TTY" 2>/dev/null || read -r cmd
    cmd=$(echo "$cmd" | tr -d '\r')

    if [ -z "$cmd" ]; then
        echo "[错误] 命令不能为空"
        sleep 2
        return
    fi

    if [ -f "$CUSTOM_CONFIG" ]; then
        sed -i "/^${key}=/d" "$CUSTOM_CONFIG" 2>/dev/null
    fi
    echo "${key}=${cmd}" >> "$CUSTOM_CONFIG"

    echo "[成功] 快捷键 ${key} 已设置"
    sleep 2
}

list_shortcuts() {
    echo ""
    echo "================================"
    echo " 已设置的快捷键"
    echo "================================"
    echo ""

    if [ ! -f "$CUSTOM_CONFIG" ] || [ ! -s "$CUSTOM_CONFIG" ]; then
        echo "[提示] 暂无已设置的快捷键"
    else
        while IFS='=' read -r key cmd; do
            echo "  ${key} -> ${cmd}"
        done < "$CUSTOM_CONFIG"
    fi

    echo ""
    printf "按回车键继续..."
    read -r dummy
}

delete_shortcut() {
    echo ""
    echo "================================"
    echo " 删除快捷键"
    echo "================================"
    echo ""

    if [ ! -f "$CUSTOM_CONFIG" ] || [ ! -s "$CUSTOM_CONFIG" ]; then
        echo "[提示] 暂无已设置的快捷键"
        sleep 2
        return
    fi

    echo "当前快捷键："
    while IFS='=' read -r key cmd; do
        echo "  ${key} -> ${cmd}"
    done < "$CUSTOM_CONFIG"
    echo ""

    printf "输入要删除的快捷键: "
    read -r key < "$TTY" 2>/dev/null || read -r key
    key=$(echo "$key" | tr -d '\r\n ')

    if [ -z "$key" ]; then
        echo "[取消] 未输入"
        sleep 1
        return
    fi

    if grep -q "^${key}=" "$CUSTOM_CONFIG" 2>/dev/null; then
        sed -i "/^${key}=/d" "$CUSTOM_CONFIG" 2>/dev/null
        echo "[成功] 快捷键 ${key} 已删除"
    else
        echo "[错误] 未找到快捷键 ${key}"
    fi
    sleep 2
}

run_custom_shortcut() {
    local key="$1"

    if [ ! -f "$CUSTOM_CONFIG" ]; then
        return 1
    fi

    local cmd
    cmd=$(grep "^${key}=" "$CUSTOM_CONFIG" 2>/dev/null | head -1 | cut -d'=' -f2-)

    if [ -n "$cmd" ]; then
        echo ""
        echo "================================"
        echo " 执行自定义脚本 [${key}]"
        echo "================================"
        echo ""
        echo "[执行] ${cmd}"
        echo "--------------------------------"
        eval "$cmd"
        echo "--------------------------------"
        echo "[完成] 执行完毕"
        echo ""
        printf "按回车键继续..."
        read -r dummy
        return 0
    fi

    return 1
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
