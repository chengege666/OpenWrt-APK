#!/bin/sh
# plugins/openclash.sh - OpenClash 插件模块

install_openclash_deps() {
    echo "[依赖] 检查 OpenClash 运行依赖..."

    local common_pkgs="bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag kmod-nft-tproxy unzip luci-compat luci luci-base"

    echo "[依赖] 安装基础依赖..."
    apk add --allow-untrusted $common_pkgs 2>/dev/null

    local firewall
    firewall=$(uci get firewall.@defaults[0].fw4_forward 2>/dev/null && echo "nftables" || echo "iptables")

    if [ "$firewall" = "nftables" ]; then
        echo "[依赖] 检测到 nftables 防火墙..."
        if modprobe nft_tproxy 2>/dev/null; then
            echo "[依赖] nft_tproxy 模块已加载"
            echo "nft_tproxy" >> /etc/modules.d/nft-tproxy.conf 2>/dev/null
        else
            echo "[警告] nft_tproxy 模块加载失败，增强模式可能不可用"
        fi
    else
        echo "[依赖] 检测到 iptables 防火墙，安装 iptables 模块..."
        apk add --allow-untrusted iptables ipset iptables-mod-tproxy iptables-mod-extra 2>/dev/null
    fi

    echo "[依赖] 依赖安装完成"
}

install_openclash() {
    manager_print_header "openclash"

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    install_openclash_deps

    local owner repo
    owner=$(get_plugin_owner "openclash")
    repo=$(get_plugin_repo "openclash")

    cleanup_old_cache
    manager_install_apk "openclash" "$owner" "$repo" "openclash"
}

uninstall_openclash() {
    manager_uninstall "openclash" "luci-app-openclash" "openclash" "luci-i18n-openclash-zh-cn"
}

update_openclash() {
    local owner repo
    owner=$(get_plugin_owner "openclash")
    repo=$(get_plugin_repo "openclash")
    manager_update "openclash" "$owner" "$repo" install_openclash
}
