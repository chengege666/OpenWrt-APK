#!/bin/sh
# plugins/openclash.sh - OpenClash 插件模块

install_openclash_deps() {
    echo "[依赖] 检查 OpenClash 运行依赖..."

    local common_pkgs="bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml unzip luci-compat luci luci-base"

    echo "[依赖] 安装基础依赖..."
    apk add --allow-untrusted $common_pkgs 2>/dev/null

    echo "[依赖] 安装内核模块..."
    for kmod in kmod-tun kmod-inet-diag; do
        local pkg_name
        pkg_name=$(apk search -q "$kmod" 2>/dev/null | head -1)
        if [ -n "$pkg_name" ]; then
            apk add --allow-untrusted "$pkg_name" 2>/dev/null
        else
            echo "[警告] 未找到 $kmod 包"
        fi
    done

    local firewall
    firewall=$(uci get firewall.@defaults[0].fw4_forward 2>/dev/null && echo "nftables" || echo "iptables")

    if [ "$firewall" = "nftables" ]; then
        echo "[依赖] 检测到 nftables 防火墙，安装 nftables 模块..."
        local pkg_name
        pkg_name=$(apk search -q kmod-nft-tproxy 2>/dev/null | head -1)
        if [ -n "$pkg_name" ]; then
            apk add --allow-untrusted "$pkg_name" 2>/dev/null
        else
            echo "[警告] 未找到 kmod-nft-tproxy 包"
        fi
    else
        echo "[依赖] 检测到 iptables 防火墙，安装 iptables 模块..."
        apk add --allow-untrusted iptables ipset iptables-mod-tproxy iptables-mod-extra 2>/dev/null
    fi

    echo "[依赖] 依赖安装完成"
}

install_openclash() {
    echo ""
    echo "================================"
    echo " 安装 OpenClash"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    install_openclash_deps

    local owner="vernesong"
    local repo="OpenClash"
    local plugin_name="openclash"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local apk_url
    apk_url="https://github.com/${owner}/${repo}/releases/download/${tag}/luci-app-openclash-${tag#v}.apk"
    echo "[下载] $apk_url"

    local download_dir="${CACHE_DIR}/${plugin_name}"
    mkdir -p "$download_dir"

    local output="${download_dir}/luci-app-openclash.apk"
    if wget -q --timeout=60 -O "$output" "$apk_url" 2>/dev/null; then
        if [ -f "$output" ] && [ -s "$output" ]; then
            echo "[成功] 下载完成"
        else
            echo "[错误] 下载文件为空"
            rm -f "$output"
            return 1
        fi
    else
        echo "[错误] 下载失败"
        rm -f "$output"
        return 1
    fi

    echo "[安装] 正在安装..."
    cd "$download_dir" || return 1
    if apk add --allow-untrusted --force-overwrite --clean-protected *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[启用] 启用 OpenClash 服务..."
    if [ -f /etc/init.d/openclash ]; then
        /etc/init.d/openclash enable 2>/dev/null
        /etc/init.d/openclash start 2>/dev/null
    fi

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_openclash() {
    echo ""
    echo "================================"
    echo " 卸载 OpenClash"
    echo "================================"
    echo ""

    echo "[停止] 停止 OpenClash 服务..."
    if [ -f /etc/init.d/openclash ]; then
        /etc/init.d/openclash stop 2>/dev/null
        /etc/init.d/openclash disable 2>/dev/null
    fi

    uninstall_plugin "luci-app-openclash"
    uninstall_plugin "openclash"
    uninstall_plugin "luci-i18n-openclash-zh-cn"

    echo "[清理] 清理配置文件..."
    rm -rf /etc/config/openclash 2>/dev/null
    rm -rf /etc/openclash 2>/dev/null
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_openclash() {
    echo ""
    echo "================================"
    echo " 更新 OpenClash"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_openclash
}
