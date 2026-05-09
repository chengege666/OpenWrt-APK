#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
    echo "================================"
    echo ""

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

    local apk_url
    apk_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.apk$" | head -1)

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn.*\.apk$" | head -1)

    if [ -z "$apk_url" ]; then
        echo "[重试] 未找到 APK，尝试 IPK..."
        apk_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.ipk$" | head -1)
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn.*\.ipk$" | head -1)
    fi

    if [ -z "$apk_url" ]; then
        echo "[错误] 未找到 AdGuardHome 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    mkdir -p "$download_dir"

    local filename
    filename=$(basename "$apk_url")
    echo "[下载] $filename"
    if ! wget -q --timeout=60 -O "${download_dir}/${filename}" "$apk_url" 2>/dev/null; then
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
