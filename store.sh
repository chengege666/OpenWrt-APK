#!/bin/sh
# store.sh - OpenWrt APK Store 主安装器

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "${SCRIPT_DIR}/core/network.sh"
. "${SCRIPT_DIR}/core/github.sh"
. "${SCRIPT_DIR}/core/install.sh"
. "${SCRIPT_DIR}/core/ui.sh"

. "${SCRIPT_DIR}/plugins/openclash.sh"
. "${SCRIPT_DIR}/plugins/mosdns.sh"
. "${SCRIPT_DIR}/plugins/adguardhome.sh"
. "${SCRIPT_DIR}/plugins/docker.sh"
. "${SCRIPT_DIR}/plugins/luci-theme-aurora.sh"
. "${SCRIPT_DIR}/plugins/lucky.sh"
. "${SCRIPT_DIR}/plugins/luci-theme-argon.sh"

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
                install_adguardhome
                wait_for_enter
                ;;
            4)
                install_docker
                wait_for_enter
                ;;
            5)
                install_luci_theme_aurora
                wait_for_enter
                ;;
            6)
                install_lucky
                wait_for_enter
                ;;
            7)
                install_luci_theme_argon
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
                uninstall_adguardhome
                wait_for_enter
                ;;
            4)
                uninstall_docker
                wait_for_enter
                ;;
            5)
                uninstall_luci_theme_aurora
                wait_for_enter
                ;;
            6)
                uninstall_lucky
                wait_for_enter
                ;;
            7)
                uninstall_luci_theme_argon
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
                update_luci_theme_aurora
                wait_for_enter
                ;;
            7)
                update_lucky
                wait_for_enter
                ;;
            8)
                update_luci_theme_argon
                wait_for_enter
                ;;
            9)
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
    update_adguardhome
    update_docker
    update_luci_theme_aurora
    update_lucky

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

    local commit_sha
    commit_sha=$(get_latest_commit_sha "chengege666" "OpenWrt-APK" "main")

    local ref="main"
    if [ -n "$commit_sha" ] && [ ${#commit_sha} -eq 40 ]; then
        ref="$commit_sha"
        echo "[SHA] $commit_sha"
    else
        echo "[提示] 获取最新提交失败，使用 main 分支"
    fi

    echo "[下载] 正在获取最新版本..."

    local raw_url="https://raw.githubusercontent.com/chengege666/OpenWrt-APK/${ref}"
    local fail=0

    wget -q --timeout=30 -O "${tmp_dir}/store.sh" "${raw_url}/store.sh" 2>/dev/null || fail=1
    wget -q --timeout=30 -O "${tmp_dir}/install.sh" "${raw_url}/install.sh" 2>/dev/null || true

    for f in network.sh github.sh install.sh ui.sh; do
        wget -q --timeout=30 -O "${tmp_dir}/core/${f}" "${raw_url}/core/${f}" 2>/dev/null || true
    done

    for f in openclash.sh passwall.sh mosdns.sh adguardhome.sh docker.sh luci-theme-aurora.sh lucky.sh luci-theme-argon.sh; do
        wget -q --timeout=30 -O "${tmp_dir}/plugins/${f}" "${raw_url}/plugins/${f}" 2>/dev/null || true
    done

    if [ "$fail" -eq 1 ] || [ ! -s "${tmp_dir}/store.sh" ]; then
        echo "[错误] 核心文件下载失败"
        rm -rf "$tmp_dir"
        sleep 2
        return
    fi

    echo "[安装] 正在替换文件..."

    for f in store.sh install.sh; do
        cp -f "${tmp_dir}/${f}" "${SCRIPT_DIR}/${f}" 2>/dev/null || { echo "[错误] ${f} 复制失败"; rm -rf "$tmp_dir"; sleep 2; return; }
    done

    for f in network.sh github.sh install.sh ui.sh; do
        cp -f "${tmp_dir}/core/${f}" "${SCRIPT_DIR}/core/${f}" 2>/dev/null || { echo "[错误] core/${f} 复制失败"; rm -rf "$tmp_dir"; sleep 2; return; }
    done

    for f in openclash.sh mosdns.sh adguardhome.sh docker.sh luci-theme-aurora.sh lucky.sh luci-theme-argon.sh; do
        cp -f "${tmp_dir}/plugins/${f}" "${SCRIPT_DIR}/plugins/${f}" 2>/dev/null || { echo "[错误] plugins/${f} 复制失败"; rm -rf "$tmp_dir"; sleep 2; return; }
    done

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
