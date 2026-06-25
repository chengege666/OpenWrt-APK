#!/bin/sh
# store.sh - OpenWrt APK Store 主安装器

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "${SCRIPT_DIR}/core/network.sh"
. "${SCRIPT_DIR}/core/github.sh"
. "${SCRIPT_DIR}/core/install.sh"
. "${SCRIPT_DIR}/core/ui.sh"
. "${SCRIPT_DIR}/core/system-init.sh"
. "${SCRIPT_DIR}/core/expand-overlay.sh"
. "${SCRIPT_DIR}/core/doctor.sh"

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
    update_lucky
    update_smartdns
    update_daed
    update_istore
    update_diskman
    update_wechatpush
    update_passwall
    update_nikki

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
    echo " 更新 OpenWrt APK安装脚本 （CGG）"
    echo "================================"
    echo ""

    local tmp_dir="/tmp/apk-store-update"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    echo "[下载] 正在获取最新版本..."

    local zip_url="https://github.com/chengege666/OpenWrt-APK/archive/main.zip"

    if ! download_file "$zip_url" "${tmp_dir}/repo.zip"; then
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

# ============================================================
# 软件源修改模块
# ============================================================
modify_repo() {
    while true; do
        show_repo_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                repo_ustc
                wait_for_enter
                ;;
            2)
                repo_tsinghua
                wait_for_enter
                ;;
            3)
                repo_official
                wait_for_enter
                ;;
            4)
                repo_restore
                wait_for_enter
                ;;
            5)
                repo_show_current
                wait_for_enter
                ;;
            6)
                repo_test_latency
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

REPO_DISTFEEDS="/etc/apk/repositories.d/distfeeds.list"
REPO_BACKUP="/etc/apk-store-repo.backup"

# 切换前备份原始源文件（仅首次备份）
repo_backup_first() {
    if [ ! -f "$REPO_BACKUP" ] && [ -f "$REPO_DISTFEEDS" ]; then
        cp -f "$REPO_DISTFEEDS" "$REPO_BACKUP"
        echo "[备份] 原始源文件已备份至 ${REPO_BACKUP}"
    fi
}

# 检测目标源文件是否存在
repo_check_file() {
    if [ ! -f "$REPO_DISTFEEDS" ]; then
        echo "[错误] 未找到源文件: ${REPO_DISTFEEDS}"
        return 1
    fi
    return 0
}

repo_ustc() {
    repo_check_file || return
    repo_backup_first

    echo ""
    echo "[修改] 正在切换至中科大源..."
    sed -i 's|downloads.openwrt.org|mirrors.ustc.edu.cn/openwrt|g' "$REPO_DISTFEEDS"
    echo "[完成] 已切换至中科大源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_tsinghua() {
    repo_check_file || return
    repo_backup_first

    echo ""
    echo "[修改] 正在切换至清华源..."
    sed -i 's|downloads.openwrt.org|mirrors.tuna.tsinghua.edu.cn/openwrt|g' "$REPO_DISTFEEDS"
    echo "[完成] 已切换至清华源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_official() {
    repo_check_file || return
    repo_backup_first

    echo ""
    echo "[修改] 正在切换至官方源..."
    sed -i 's|mirrors.ustc.edu.cn/openwrt|downloads.openwrt.org|g' "$REPO_DISTFEEDS"
    sed -i 's|mirrors.tuna.tsinghua.edu.cn/openwrt|downloads.openwrt.org|g' "$REPO_DISTFEEDS"
    echo "[完成] 已切换至官方源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_restore() {
    if [ ! -f "$REPO_BACKUP" ]; then
        echo ""
        echo "[错误] 未找到备份文件，无法恢复"
        echo ""
        return
    fi

    echo ""
    echo "[恢复] 正在从备份恢复原始源文件..."
    cp -f "$REPO_BACKUP" "$REPO_DISTFEEDS"
    echo "[完成] 已恢复为默认源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_show_current() {
    echo ""
    echo "================================"
    echo " 当前软件源"
    echo "================================"
    if [ ! -f "$REPO_DISTFEEDS" ]; then
        echo "[提示] 未找到源文件: ${REPO_DISTFEEDS}"
        echo ""
        return
    fi

    local name="未知源"
    if grep -q "mirrors.ustc.edu.cn" "$REPO_DISTFEEDS" 2>/dev/null; then
        name="中科大源 (USTC)"
    elif grep -q "mirrors.tuna.tsinghua.edu.cn" "$REPO_DISTFEEDS" 2>/dev/null; then
        name="清华源 (Tsinghua)"
    elif grep -q "downloads.openwrt.org" "$REPO_DISTFEEDS" 2>/dev/null; then
        name="官方源 (Official)"
    fi
    echo "当前源: ${name}"
    echo ""
    cat "$REPO_DISTFEEDS"
    echo ""
}

# 测试源延迟（ms）
repo_test_url() {
    local url="$1"
    local name="$2"
    local timeout=3

    # 从 URL 提取域名
    local domain
    domain=$(echo "$url" | sed 's|https\?://||;s|/.*$||')

    # 先用 ping 测 ICMP 延迟
    local result
    result=$(ping -c 1 -W "$timeout" "$domain" 2>/dev/null)
    local rc=$?

    if [ $rc -eq 0 ] && [ -n "$result" ]; then
        local time_val
        time_val=$(echo "$result" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -1)
        if [ -n "$time_val" ]; then
            local int_ms
            int_ms=$(echo "$time_val" | awk '{print int($1)}')
            if [ "$int_ms" -ge 1000 ] 2>/dev/null; then
                echo "  ${name}: ${time_val} ms (ping)"
            else
                echo "  ${name}: ${int_ms} ms (ping)"
            fi
            return
        fi
    fi

    # ping 失败时用 curl 兜底（绕过代理直连测试 HTTP 延迟）
    local curl_result
    curl_result=$(curl --noproxy '*' -o /dev/null -s -w '%{time_total}' --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null)
    local curl_rc=$?

    if [ $curl_rc -eq 0 ] && [ -n "$curl_result" ]; then
        local curl_ms
        curl_ms=$(echo "$curl_result" | awk '{printf "%.1f", $1 * 1000}')
        local int_curl_ms
        int_curl_ms=$(echo "$curl_result" | awk '{print int($1 * 1000)}')
        if [ "$int_curl_ms" -eq 0 ] 2>/dev/null; then
            echo "  ${name}: < 1 ms (curl)"
        elif [ "$int_curl_ms" -ge 1000 ] 2>/dev/null; then
            local sec
            sec=$(echo "$curl_result" | awk '{printf "%.2f", $1}')
            echo "  ${name}: ${sec} s (curl)"
        else
            echo "  ${name}: ${int_curl_ms} ms (curl)"
        fi
    else
        echo "  ${name}: 超时 / 不可达"
    fi
}

repo_test_latency() {
    echo ""
    echo "================================"
    echo " 测试源延迟"
    echo "================================"
    echo ""

    echo "正在测试以下源延迟:"
    echo ""

    repo_test_url "https://mirrors.ustc.edu.cn/openwrt/" "中科大源 (USTC)"
    repo_test_url "https://mirrors.tuna.tsinghua.edu.cn/openwrt/" "清华源 (Tsinghua)"
    repo_test_url "https://downloads.openwrt.org/" "官方源 (Official)"

    echo ""
}

repo_update() {
    echo ""
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
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
