#!/bin/sh
# plugins/openclash.sh - OpenClash 插件模块

GITHUB_OWNER="vernesong"
GITHUB_REPO="OpenClash"
PLUGIN_NAME="openclash"

install_openclash() {
    echo ""
    echo "================================"
    echo " 安装 OpenClash"
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

    local apk_url
    apk_url="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${tag}/luci-app-openclash-${tag#v}.apk"
    echo "[下载] $apk_url"

    local download_dir="${CACHE_DIR}/${PLUGIN_NAME}"
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
    if apk add --allow-untrusted --force-overwrite *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

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

    uninstall_plugin "luci-app-openclash"
    uninstall_plugin "openclash"
    uninstall_plugin "luci-i18n-openclash-zh-cn"

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
