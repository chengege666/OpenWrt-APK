#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
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

    local install_ok=1
    if [ "$is_apk" -eq 1 ]; then
        apk update 2>/dev/null
        apk add --allow-untrusted luci-app-adguardhome luci-i18n-adguardhome-zh-cn adguardhome 2>/dev/null && install_ok=0
    else
        opkg update 2>/dev/null
        opkg install luci-app-adguardhome luci-i18n-adguardhome-zh-cn adguardhome 2>/dev/null && install_ok=0
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[成功] AdGuardHome 安装完成"
        fix_dependencies
        restart_luci
        show_success
        return
    fi

    echo "[重试] 系统软件源中未找到，从 GitHub 下载..."

    local owner="stevenjoezhang"
    local repo="luci-app-adguardhome"
    local plugin_name="adguardhome"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local pkg_url
    pkg_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.${pkg_ext}$" | head -1)

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn.*\.${pkg_ext}$" | head -1)

    if [ -z "$pkg_url" ]; then
        pkg_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.\(apk\|ipk\)$" | head -1)
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn.*\.\(apk\|ipk\)$" | head -1)
    fi

    if [ -z "$pkg_url" ]; then
        echo "[错误] 未找到 AdGuardHome 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    mkdir -p "$download_dir"

    local filename
    filename=$(basename "$pkg_url")
    echo "[下载] $filename"
    if ! wget -q --timeout=60 -O "${download_dir}/${filename}" "$pkg_url" 2>/dev/null; then
        echo "[错误] 下载失败"
        rm -f "${download_dir}/${filename}"
        return 1
    fi

    if [ -n "$i18n_url" ]; then
        local i18n_file
        i18n_file=$(basename "$i18n_url")
        echo "[下载] $i18n_file"
        wget -q --timeout=60 -O "${download_dir}/${i18n_file}" "$i18n_url" 2>/dev/null
    fi

    echo "[安装] 正在安装..."
    cd "$download_dir" || return 1
    install_ok=1
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite *.apk 2>/dev/null && install_ok=0
    else
        opkg install --force-overwrite *.ipk 2>/dev/null && install_ok=0
    fi

    if [ "$install_ok" -ne 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[成功] AdGuardHome 安装完成"
    fix_dependencies
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
