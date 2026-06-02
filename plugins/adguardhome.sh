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

    local openwrt_ver="24.10"
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release 2>/dev/null
        case "$DISTRIB_RELEASE" in
            25*|snapshot*)
                openwrt_ver="25.12"
                ;;
        esac
    fi
    echo "[系统] OpenWrt $openwrt_ver"

    local owner="sirpdboy"
    local repo="luci-app-adguardhome"
    local plugin_name="adguardhome"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local main_url
    main_url=$(echo "$all_urls" | grep "luci-app-adguardhome" | grep -v "i18n" | grep "\.apk$" | head -1)

    if [ -z "$main_url" ]; then
        echo "[错误] 未找到主包下载链接"
        return 1
    fi

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn" | grep "\.apk$" | head -1)

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local main_name
    main_name=$(basename "$main_url")

    echo "[下载] $main_name"
    if ! wget -q --timeout=60 -O "${download_dir}/${main_name}" "$main_url" 2>/dev/null; then
        echo "[错误] 主包下载失败"
        rm -f "${download_dir}/${main_name}"
        return 1
    fi

    local apk_list="${download_dir}/${main_name}"

    if [ -n "$i18n_url" ]; then
        local i18n_name
        i18n_name=$(basename "$i18n_url")
        echo "[下载] $i18n_name"
        if wget -q --timeout=60 -O "${download_dir}/${i18n_name}" "$i18n_url" 2>/dev/null; then
            apk_list="$apk_list ${download_dir}/${i18n_name}"
        else
            echo "[警告] 中文包下载失败，继续安装主包"
        fi
    fi

    echo "[安装] 安装 APK 包..."
    if ! apk add --allow-untrusted --force-overwrite $apk_list 2>/dev/null; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[成功] 安装完成"

    echo "[配置] 配置核心下载链接..."
    setup_adguardhome_links

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

setup_adguardhome_links() {
    mkdir -p /usr/share/AdGuardHome

    local link_file="/usr/share/AdGuardHome/links.txt"

    cat <<EOF > "$link_file"
https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_arm64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_armv7.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_mipsle_softfloat.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_mips_softfloat.tar.gz
EOF
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
