#!/bin/sh
# plugins/smartdns.sh - SmartDNS 插件模块

install_smartdns() {
    echo ""
    echo "================================"
    echo " 安装 SmartDNS"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    local owner="pymumu"
    local repo="smartdns"
    local plugin_name="smartdns"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local core_file=""
    case "$arch" in
        x86_64)
            core_file=$(echo "$all_urls" | grep "smartdns-x86_64$" | head -1)
            ;;
        aarch64)
            core_file=$(echo "$all_urls" | grep "smartdns-aarch64$" | head -1)
            ;;
        arm)
            core_file=$(echo "$all_urls" | grep "smartdns-arm$" | head -1)
            ;;
        mipsel)
            core_file=$(echo "$all_urls" | grep "smartdns-mipsel$" | head -1)
            ;;
        mips)
            core_file=$(echo "$all_urls" | grep "smartdns-mips$" | head -1)
            ;;
        *)
            echo "[错误] 不支持的架构: $arch"
            return 1
            ;;
    esac

    if [ -z "$core_file" ]; then
        echo "[重试] 尝试通用包..."
        core_file=$(echo "$all_urls" | grep "smartdns-all$" | head -1)
    fi

    if [ -z "$core_file" ]; then
        echo "[错误] 未找到适合 $arch 架构的核心包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local core_name
    core_name=$(basename "$core_file")

    echo "[下载] 核心: $core_name"
    if ! wget -q --timeout=120 -O "${download_dir}/${core_name}" "$core_file" 2>/dev/null; then
        echo "[错误] 核心下载失败"
        rm -f "${download_dir}/${core_name}"
        return 1
    fi

    if [ ! -f "${download_dir}/${core_name}" ] || [ ! -s "${download_dir}/${core_name}" ]; then
        echo "[错误] 核心下载文件为空"
        rm -f "${download_dir}/${core_name}"
        return 1
    fi

    echo "[安装] 正在安装核心..."
    chmod +x "${download_dir}/${core_name}"
    cp -f "${download_dir}/${core_name}" /usr/bin/smartdns 2>/dev/null || {
        mv -f "${download_dir}/${core_name}" /usr/bin/smartdns 2>/dev/null || {
            echo "[错误] 核心安装失败"
            return 1
        }
    }
    chmod +x /usr/bin/smartdns
    echo "[成功] 核心安装完成"

    echo "[步骤 2/2] 安装 LuCI 界面..."
    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local luci_pkg
    luci_pkg=$(echo "$all_urls" | grep "luci-app-smartdns\..*\.${pkg_ext}$" | grep -iv "lite" | grep -iv "compat" | head -1)

    if [ -n "$luci_pkg" ]; then
        local luci_name
        luci_name=$(basename "$luci_pkg")
        echo "[下载] LuCI: $luci_name"
        if wget -q --timeout=60 -O "${download_dir}/${luci_name}" "$luci_pkg" 2>/dev/null; then
            if [ -f "${download_dir}/${luci_name}" ] && [ -s "${download_dir}/${luci_name}" ]; then
                if [ "$is_apk" -eq 1 ]; then
                    apk add --allow-untrusted --force-overwrite "${download_dir}/${luci_name}" 2>/dev/null && {
                        echo "[成功] LuCI 界面安装完成"
                    } || echo "[警告] LuCI 界面安装失败"
                else
                    opkg install --force-overwrite "${download_dir}/${luci_name}" 2>/dev/null && {
                        echo "[成功] LuCI 界面安装完成"
                    } || echo "[警告] LuCI 界面安装失败"
                fi
            else
                echo "[警告] LuCI 下载文件为空"
            fi
        else
            echo "[警告] LuCI 下载失败"
        fi
    else
        echo "[警告] 未找到 LuCI 界面包"
    fi

    if [ -f /etc/init.d/smartdns ]; then
        /etc/init.d/smartdns enable 2>/dev/null
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_smartdns() {
    echo ""
    echo "================================"
    echo " 卸载 SmartDNS"
    echo "================================"
    echo ""

    echo "[停止] 停止 SmartDNS 服务..."
    if [ -f /etc/init.d/smartdns ]; then
        /etc/init.d/smartdns stop 2>/dev/null
        /etc/init.d/smartdns disable 2>/dev/null
    fi

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    uninstall_plugin "luci-app-smartdns"
    uninstall_plugin "luci-i18n-smartdns-zh-cn"
    uninstall_plugin "smartdns"

    rm -f /usr/bin/smartdns 2>/dev/null
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_smartdns() {
    echo ""
    echo "================================"
    echo " 更新 SmartDNS"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_smartdns
}
