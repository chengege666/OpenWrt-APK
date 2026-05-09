#!/bin/sh
# plugins/tailscale.sh - Tailscale 插件模块

install_tailscale() {
    echo ""
    echo "================================"
    echo " 安装 Tailscale"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local owner="tailscale"
    local repo="tailscale"
    local plugin_name="tailscale"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local luci_urls
    luci_urls=$(filter_luci_apk "$all_urls" "$plugin_name")

    local i18n_urls
    i18n_urls=$(filter_i18n_apk "$all_urls")

    local arch_urls
    arch_urls=$(filter_apk_by_arch "$all_urls" "$arch")

    local all_apk_urls
    all_apk_urls=$(printf "%s\n%s\n%s" "$luci_urls" "$i18n_urls" "$arch_urls" | sort -u | grep -v '^$')

    if [ -z "$all_apk_urls" ]; then
        echo "[错误] 未找到可用的 APK 文件"
        return 1
    fi

    echo "[下载] 正在下载 APK 文件..."
    download_apks "$all_apk_urls" "$plugin_name" || return 1

    echo "[安装] 正在安装..."
    install_apks "$plugin_name" || return 1

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_tailscale() {
    echo ""
    echo "================================"
    echo " 卸载 Tailscale"
    echo "================================"
    echo ""

    uninstall_plugin "tailscale"
    uninstall_plugin "luci-app-tailscale"
    uninstall_plugin "luci-i18n-tailscale-zh-cn"

    show_success
}

update_tailscale() {
    echo ""
    echo "================================"
    echo " 更新 Tailscale"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_tailscale
}
