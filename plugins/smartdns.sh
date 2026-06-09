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

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    echo "[步骤 1/2] 下载 SmartDNS 核心..."
    local core_name="smartdns-${arch}"
    local core_url
    core_url=$(echo "$all_urls" | grep "smartdns-${arch}$" | head -1)

    if [ -z "$core_url" ]; then
        echo "[重试] 未找到 ${arch} 架构核心，尝试模糊匹配..."
        core_url=$(echo "$all_urls" | grep "smartdns-${arch}" | head -1)
    fi

    if [ -z "$core_url" ]; then
        echo "[重试] 使用通用核心 smartdns-all..."
        core_url=$(echo "$all_urls" | grep "smartdns-all$" | head -1)
    fi

    if [ -z "$core_url" ]; then
        echo "[错误] 未找到适合 ${arch} 架构的核心文件"
        return 1
    fi

    echo "[下载] SmartDNS 核心..."
    if ! download_file "$core_url" "${download_dir}/smartdns"; then
        echo "[错误] 核心下载失败"
        return 1
    fi

    if [ ! -s "${download_dir}/smartdns" ]; then
        echo "[错误] 下载文件为空"
        rm -f "${download_dir}/smartdns"
        return 1
    fi
    echo "[成功] 核心下载完成"

    echo "[步骤 2/2] 下载 LuCI 界面..."
    local pkg_ext
    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local luci_url
    luci_url=$(echo "$all_urls" | grep "luci-app-smartdns" | grep "all-luci-all" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[重试] 未找到 ${pkg_ext} 格式 LuCI 包，尝试 IPK..."
        luci_url=$(echo "$all_urls" | grep "luci-app-smartdns" | grep "all-luci-all" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[重试] 尝试查找兼容版 LuCI 包..."
        luci_url=$(echo "$all_urls" | grep "luci-app-smartdns" | grep "all-luci-compat" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[重试] 尝试查找 LuCI Lite 包..."
        luci_url=$(echo "$all_urls" | grep "luci-app-smartdns-lite" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 LuCI 界面包"
        rm -f "${download_dir}/smartdns"
        return 1
    fi

    local luci_file
    luci_file=$(basename "$luci_url")
    if ! download_file "$luci_url" "${download_dir}/${luci_file}"; then
        echo "[错误] LuCI 界面下载失败"
        rm -f "${download_dir}/smartdns"
        return 1
    fi

    if [ ! -s "${download_dir}/${luci_file}" ]; then
        echo "[错误] 下载文件为空"
        rm -f "${download_dir}/smartdns"
        rm -f "${download_dir}/${luci_file}"
        return 1
    fi
    echo "[成功] LuCI 下载完成"

    echo "[安装] 安装 SmartDNS 核心..."
    chmod +x "${download_dir}/smartdns"
    mkdir -p /usr/bin
    cp -f "${download_dir}/smartdns" /usr/bin/smartdns
    chmod +x /usr/bin/smartdns

    if [ -f /usr/bin/smartdns ]; then
        echo "[成功] 核心安装完成"
    else
        echo "[错误] 核心安装失败"
        rm -rf "$download_dir"
        return 1
    fi

    echo "[安装] 创建初始化脚本..."
    cat > /etc/init.d/smartdns << 'INITEOF'
#!/bin/sh /etc/rc.common

START=55

start() {
    service_start /usr/bin/smartdns
}

stop() {
    service_stop /usr/bin/smartdns
}
INITEOF
    chmod +x /etc/init.d/smartdns

    echo "[安装] 安装 LuCI 界面..."
    case "${luci_file}" in
        *.apk)
            apk add --allow-untrusted --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null
            ;;
        *.ipk)
            opkg install --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "[成功] LuCI 界面安装完成"
    else
        echo "[警告] LuCI 界面安装可能有问题，继续执行..."
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[启用] 启用 SmartDNS 服务..."
    if [ -f /etc/init.d/smartdns ]; then
        /etc/init.d/smartdns enable 2>/dev/null
    fi

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

    echo "[卸载] 正在卸载 SmartDNS..."
    uninstall_plugin "luci-app-smartdns"
    uninstall_plugin "luci-app-smartdns-lite"
    uninstall_plugin "luci-i18n-smartdns-zh-cn"

    echo "[清理] 清理核心文件..."
    rm -f /usr/bin/smartdns
    rm -f /etc/init.d/smartdns

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
