#!/bin/sh
# store.sh - OpenWrt APK Store 主安装器
#
# SPDX-FileCopyrightText: 2025 ChenGege
#
# SPDX-License-Identifier: GPL-3.0-only
#
# OpenWrt APK Store is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# OpenWrt APK Store is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OpenWrt APK Store. If not, see <https://www.gnu.org/licenses/>.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "${SCRIPT_DIR}/core/network.sh"
. "${SCRIPT_DIR}/core/github.sh"
. "${SCRIPT_DIR}/core/install.sh"
. "${SCRIPT_DIR}/core/ui.sh"
. "${SCRIPT_DIR}/core/system-init.sh"
. "${SCRIPT_DIR}/core/expand-overlay.sh"
. "${SCRIPT_DIR}/core/doctor.sh"
. "${SCRIPT_DIR}/core/repo.sh"

. "${SCRIPT_DIR}/plugins/openclash.sh"
. "${SCRIPT_DIR}/plugins/mosdns.sh"
. "${SCRIPT_DIR}/plugins/docker.sh"
. "${SCRIPT_DIR}/plugins/luci-theme-aurora.sh"
. "${SCRIPT_DIR}/plugins/lucky.sh"
. "${SCRIPT_DIR}/plugins/luci-theme-argon.sh"
. "${SCRIPT_DIR}/plugins/taskplan.sh"
. "${SCRIPT_DIR}/plugins/passwall2.sh"
. "${SCRIPT_DIR}/plugins/daed.sh"
[ -f "${SCRIPT_DIR}/plugins/smartdns.sh" ] && . "${SCRIPT_DIR}/plugins/smartdns.sh"
[ -f "${SCRIPT_DIR}/plugins/istore.sh" ] && . "${SCRIPT_DIR}/plugins/istore.sh"
[ -f "${SCRIPT_DIR}/plugins/luci-app-diskman.sh" ] && . "${SCRIPT_DIR}/plugins/luci-app-diskman.sh"
[ -f "${SCRIPT_DIR}/plugins/luci-app-wechatpush.sh" ] && . "${SCRIPT_DIR}/plugins/luci-app-wechatpush.sh"
. "${SCRIPT_DIR}/plugins/passwall.sh"
. "${SCRIPT_DIR}/plugins/nikki.sh"
. "${SCRIPT_DIR}/plugins/adguardhome.sh"
. "${SCRIPT_DIR}/plugins/oxidns.sh"


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
                install_plugin_menu
                ;;
            2)
                uninstall_menu
                ;;
            3)
                update_menu
                ;;
            4)
                shortcut_config
                ;;
            5)
                system_init
                wait_for_enter
                ;;
            6)
                expand_overlay
                wait_for_enter
                ;;
            7)
                show_system_info
                wait_for_enter
                ;;
            8)
                sh "${SCRIPT_DIR}/core/apk-opts.sh"
                wait_for_enter
                ;;
            9)
                modify_repo
                ;;
            10)
                mirror_config_menu
                ;;
            00)
                uninstall_store
                ;;
            000)
                update_store
                ;;
            0)
                echo "退出 OpenWrt APK安装脚本 （CGG）"
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

install_plugin_menu() {
    while true; do
        show_install_plugin_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                install_openclash
                wait_for_enter
                ;;
            2)
                install_mosdns
                wait_for_enter
                ;;
            3)
                install_docker
                wait_for_enter
                ;;
            4)
                install_luci_theme_aurora
                wait_for_enter
                ;;
            5)
                install_lucky
                wait_for_enter
                ;;
            6)
                install_luci_theme_argon
                wait_for_enter
                ;;
            7)
                install_taskplan
                wait_for_enter
                ;;
            8)
                install_passwall2
                wait_for_enter
                ;;
            9)
                install_smartdns
                wait_for_enter
                ;;
            10)
                install_daed
                wait_for_enter
                ;;
            11)
                install_istore
                wait_for_enter
                ;;
            12)
                install_diskman
                wait_for_enter
                ;;
            13)
                install_wechatpush
                wait_for_enter
                ;;
            14)
                install_passwall
                wait_for_enter
                ;;
            15)
                install_nikki
                wait_for_enter
                ;;
            16)
                install_adguardhome
                wait_for_enter
                ;;
            17)
                install_oxidns
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
                uninstall_mosdns
                wait_for_enter
                ;;
            3)
                uninstall_docker
                wait_for_enter
                ;;
            4)
                uninstall_luci_theme_aurora
                wait_for_enter
                ;;
            5)
                uninstall_lucky
                wait_for_enter
                ;;
            6)
                uninstall_luci_theme_argon
                wait_for_enter
                ;;
            7)
                uninstall_taskplan
                wait_for_enter
                ;;
            8)
                uninstall_passwall2
                wait_for_enter
                ;;
            9)
                uninstall_smartdns
                wait_for_enter
                ;;
            10)
                uninstall_daed
                wait_for_enter
                ;;
            11)
                uninstall_istore
                wait_for_enter
                ;;
            12)
                uninstall_diskman
                wait_for_enter
                ;;
            13)
                uninstall_wechatpush
                wait_for_enter
                ;;
            14)
                uninstall_passwall
                wait_for_enter
                ;;
            15)
                uninstall_nikki
                wait_for_enter
                ;;
            16)
                uninstall_adguardhome
                wait_for_enter
                ;;
            17)
                uninstall_oxidns
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
                update_mosdns
                wait_for_enter
                ;;
            3)
                update_docker
                wait_for_enter
                ;;
            4)
                update_luci_theme_aurora
                wait_for_enter
                ;;
            5)
                update_lucky
                wait_for_enter
                ;;
            6)
                update_luci_theme_argon
                wait_for_enter
                ;;
            7)
                update_taskplan
                wait_for_enter
                ;;
            8)
                update_passwall2
                wait_for_enter
                ;;
            9)
                update_smartdns
                wait_for_enter
                ;;
            10)
                update_daed
                wait_for_enter
                ;;
            11)
                update_istore
                wait_for_enter
                ;;
            12)
                update_diskman
                wait_for_enter
                ;;
            13)
                update_wechatpush
                wait_for_enter
                ;;
            14)
                update_passwall
                wait_for_enter
                ;;
            15)
                update_nikki
                wait_for_enter
                ;;
            17)
                update_adguardhome
                wait_for_enter
                ;;
            18)
                update_oxidns
                wait_for_enter
                ;;
            16)
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
    update_mosdns
    update_docker
    update_luci_theme_aurora
    update_luci_theme_argon
    update_lucky
    update_taskplan
    update_passwall2
    update_smartdns
    update_daed
    update_istore
    update_diskman
    update_wechatpush
    update_passwall
    update_nikki
    update_adguardhome
    update_oxidns

    echo ""
    echo "================================"
    echo " 全部更新完成"
    echo "================================"
    echo ""
}

mirror_config_menu() {
    while true; do
        show_mirror_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                set_github_mirror
                wait_for_enter
                ;;
            2)
                echo ""
                printf "请输入镜像地址（含 https://）: "
                read -r custom_url < "$TTY" 2>/dev/null || read -r custom_url
                custom_url=$(echo "$custom_url" | tr -d '\r\n ')

                if [ -z "$custom_url" ]; then
                    echo "[取消] 已取消"
                else
                    set_github_mirror "$custom_url"
                fi
                wait_for_enter
                ;;
            3)
                disable_github_mirror
                wait_for_enter
                ;;
            4)
                echo ""
                echo "================================"
                echo " GitHub 镜像加速状态"
                echo "================================"
                if [ -n "$GITHUB_MIRROR" ]; then
                    echo "  状态: 已启用"
                    echo "  镜像: ${GITHUB_MIRROR}"
                else
                    echo "  状态: 未启用"
                fi
                echo ""
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
    echo " 更新 OpenWrt APK安装脚本 （CGG）"
    echo "================================"
    echo ""

    local tmp_dir="/tmp/apk-store-update"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    echo "[下载] 正在获取最新版本..."

    local zip_url="https://github.com/chengege666/OpenWrt-APK/archive/main.zip"

    if ! wget -q --timeout=60 -O "${tmp_dir}/repo.zip" "$zip_url" 2>/dev/null; then
        echo "[错误] 仓库下载失败"
        rm -rf "$tmp_dir"
        sleep 2
        return
    fi

    echo "[解压] 正在解压..."
    if ! unzip -o -q "${tmp_dir}/repo.zip" -d "$tmp_dir" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -rf "$tmp_dir"
        sleep 2
        return
    fi

    local src_dir="${tmp_dir}/OpenWrt-APK-main"

    if [ ! -f "${src_dir}/store.sh" ]; then
        echo "[错误] 核心文件缺失，更新失败"
        rm -rf "$tmp_dir"
        sleep 2
        return
    fi

    echo "[安装] 正在替换文件..."

    cp -f "${src_dir}/store.sh" "${SCRIPT_DIR}/store.sh"
    cp -f "${src_dir}/install.sh" "${SCRIPT_DIR}/install.sh" 2>/dev/null || true
    cp -rf "${src_dir}/core/"* "${SCRIPT_DIR}/core/"
    cp -rf "${src_dir}/plugins/"* "${SCRIPT_DIR}/plugins/"

    chmod +x "${SCRIPT_DIR}/store.sh" "${SCRIPT_DIR}/core/"*.sh "${SCRIPT_DIR}/plugins/"*.sh 2>/dev/null

    rm -rf "$tmp_dir"
    echo "[成功] 文件更新完成"

    echo ""
    echo "[重启] 正在重新启动脚本..."
    echo ""

    exec sh "${SCRIPT_DIR}/store.sh" || {
        echo "[错误] 重启失败，请手动运行: sh ${SCRIPT_DIR}/store.sh"
        exit 1
    }
}

shortcut_config() {
    echo ""
    echo "================================"
    echo " 一键配置启动快捷键"
    echo "================================"
    echo ""

    show_shortcut_list
    echo ""

    printf "输入快捷键 (单个字母，回车取消): "
    read -r key < "$TTY" 2>/dev/null || read -r key
    key=$(echo "$key" | tr -d '\r\n ')

    if [ -z "$key" ]; then
        echo "[取消] 已取消"
        sleep 1
        return
    fi

    if [ ${#key} -gt 1 ]; then
        echo "[错误] 快捷键必须为单个字符"
        sleep 2
        return
    fi

    case "$key" in
        1|2|3|4|0)
            echo "[错误] 该快捷键已被系统占用"
            sleep 2
            return
            ;;
    esac

    local target="/usr/bin/${key}"
    local store_script="${SCRIPT_DIR}/store.sh"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$store_script" ] 2>/dev/null; then
        rm -f "$target"
        echo "[删除] 快捷键 ${key} 已删除"
        sleep 2
        return
    fi

    if [ -f "$target" ] || [ -L "$target" ]; then
        local detected
        detected=$(head -1 "$target" 2>/dev/null | grep -o "store.sh" || echo "")
        if [ -n "$detected" ]; then
            rm -f "$target"
            echo "[删除] 快捷键 ${key} 已删除"
            sleep 2
            return
        fi
        echo "[错误] ${target} 已被其他命令占用，不能覆盖"
        sleep 2
        return
    fi

    cat > "$target" << EOF
#!/bin/sh
sh ${store_script}
EOF
    chmod +x "$target"

    echo "[成功] 快捷键 ${key} 已设置"
    echo "在终端输入 ${key} 即可启动 APK Store"
    sleep 2
}


run_custom_shortcut() {
    local key="$1"
    local target="/usr/bin/${key}"

    [ -e "$target" ] || return 1

    if [ -L "$target" ] && [ "$(readlink "$target")" = "${SCRIPT_DIR}/store.sh" ] 2>/dev/null; then
        echo "[重启] 重新启动 APK Store..."
        exec sh "${SCRIPT_DIR}/store.sh"
    fi

    if [ -f "$target" ] && head -1 "$target" 2>/dev/null | grep -q "${SCRIPT_DIR}/store.sh"; then
        echo "[重启] 重新启动 APK Store..."
        exec sh "${SCRIPT_DIR}/store.sh"
    fi

    return 1
}

init() {
    echo "========================================"
    echo " OpenWrt APK安装脚本 （CGG）"
    echo "========================================"
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
