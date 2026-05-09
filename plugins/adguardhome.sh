#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块

GITHUB_OWNER="kenzok8"
GITHUB_REPO="luci-app-adguardhome"
PLUGIN_NAME="adguardhome"

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local release_json
    release_json=$(get_latest_release "$GITHUB_OWNER" "$GITHUB_REPO") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local main_urls
    main_urls=$(filter_main_apk "$all_urls" "$PLUGIN_NAME")

    local luci_urls
    luci_urls=$(filter_luci_apk "$all_urls" "$PLUGIN_NAME")

    local i18n_urls
    i18n_urls=$(filter_i18n_apk "$all_urls")

    local arch_urls
    arch_urls=$(filter_apk_by_arch "$all_urls" "$arch")

    local all_apk_urls
    all_apk_urls=$(printf "%s\n%s\n%s\n%s" "$main_urls" "$luci_urls" "$i18n_urls" "$arch_urls" | sort -u | grep -v '^$')

    if [ -z "$all_apk_urls" ]; then
        echo "[错误] 未找到可用的 APK 文件"
        return 1
    fi

    echo "[下载] 正在下载 APK 文件..."
    download_apks "$all_apk_urls" "$PLUGIN_NAME" || return 1

    echo "[安装] 正在安装..."
    install_apks "$PLUGIN_NAME" || return 1

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_adguardhome() {
    echo ""
    echo "================================"
    echo " 卸载 AdGuardHome"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-adguardhome"
    uninstall_plugin "adguardhome"
    uninstall_plugin "luci-i18n-adguardhome-zh-cn"

    show_success
}

update_adguardhome() {
    echo ""
    echo "================================"
    echo " 更新 AdGuardHome"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_adguardhome
}
