#!/bin/sh
# plugins/luci-theme-argon.sh - luci-theme-argon 插件模块

install_luci_theme_argon() {
    echo ""
    echo "================================"
    echo " 安装 luci-theme-argon"
    echo "================================"
    echo ""

    local owner="jerrykuku"
    local repo="luci-theme-argon"
    local plugin_name="luci-theme-argon"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local apk_url
    apk_url=$(echo "$all_urls" | grep "\.apk$" | head -1)

    if [ -z "$apk_url" ]; then
        echo "[错误] 未找到 APK 文件"
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

    echo "[安装] 正在安装..."
    cd "$download_dir" || return 1
    if apk add --allow-untrusted --force-overwrite *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败"
        return 1
    fi

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_luci_theme_argon() {
    echo ""
    echo "================================"
    echo " 卸载 luci-theme-argon"
    echo "================================"
    echo ""

    uninstall_plugin "luci-theme-argon"

    show_success
}

update_luci_theme_argon() {
    echo ""
    echo "================================"
    echo " 更新 luci-theme-argon"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_luci_theme_argon
}
