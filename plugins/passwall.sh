#!/bin/sh
# plugins/passwall.sh - PassWall 插件模块

install_passwall() {
    echo ""
    echo "================================"
    echo " 安装 PassWall"
    echo "================================"
    echo ""

    local openwrt_ver_prefix="23.05-24.10"
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release 2>/dev/null
        case "$DISTRIB_RELEASE" in
            25*|snapshot*)
                openwrt_ver_prefix="25.12+"
                ;;
        esac
    fi
    echo "[系统] OpenWrt $openwrt_ver_prefix"

    local owner="Openwrt-Passwall"
    local repo="openwrt-passwall"
    local plugin_name="passwall"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local luci_url
    local i18n_url

    if echo "$openwrt_ver_prefix" | grep -q "25.12"; then
        luci_url=$(echo "$all_urls" | grep "luci-app-passwall.*\.apk$" | head -1)
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-passwall-zh-cn.*\.apk$" | head -1)
    else
        luci_url=$(echo "$all_urls" | grep "luci-app-passwall.*\.ipk$" | head -1)
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-passwall-zh-cn.*\.ipk$" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 PassWall 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local filename
    filename=$(basename "$luci_url")
    echo "[下载] $filename"
    if ! wget -q --timeout=60 -O "${download_dir}/${filename}" "$luci_url" 2>/dev/null; then
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
    case "$filename" in
        *.apk)
            if apk add --allow-untrusted --force-overwrite *.apk 2>/dev/null; then
                echo "[成功] APK 安装完成"
            else
                echo "[错误] APK 安装失败"
                return 1
            fi
            ;;
        *.ipk)
            if opkg install --force-overwrite *.ipk 2>/dev/null; then
                echo "[成功] IPK 安装完成"
            else
                echo "[错误] IPK 安装失败"
                return 1
            fi
            ;;
    esac

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_passwall() {
    echo ""
    echo "================================"
    echo " 卸载 PassWall"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-passwall"
    uninstall_plugin "luci-i18n-passwall-zh-cn"

    show_success
}

update_passwall() {
    echo ""
    echo "================================"
    echo " 更新 PassWall"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_passwall
}
