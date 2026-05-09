#!/bin/sh
# plugins/mosdns.sh - MosDNS 插件模块

install_mosdns() {
    echo ""
    echo "================================"
    echo " 安装 MosDNS"
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

    local owner="sbwml"
    local repo="luci-app-mosdns"
    local plugin_name="mosdns"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local tarball_url
    tarball_url=$(echo "$all_urls" | grep "openwrt-${openwrt_ver}\.tar\.gz$" | grep -i "${arch}" | head -1)

    if [ -z "$tarball_url" ]; then
        echo "[重试] 未找到 ${arch} 匹配包，尝试模糊匹配..."
        tarball_url=$(echo "$all_urls" | grep "openwrt-${openwrt_ver}\.tar\.gz$" | grep -i "$(uname -m)" | head -1)
    fi

    if [ -z "$tarball_url" ]; then
        tarball_url=$(echo "$all_urls" | grep "\.tar\.gz$" | grep -i "${arch}" | head -1)
    fi

    if [ -z "$tarball_url" ]; then
        echo "[错误] 未找到匹配架构 ${arch} 的下载包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local tarball_name
    tarball_name=$(basename "$tarball_url")

    echo "[下载] $tarball_name"
    if ! wget -q --timeout=60 -O "${download_dir}/${tarball_name}" "$tarball_url" 2>/dev/null; then
        echo "[错误] 下载失败"
        rm -f "${download_dir}/${tarball_name}"
        return 1
    fi

    echo "[解压] 正在解压..."
    if ! tar xzf "${download_dir}/${tarball_name}" -C "$download_dir" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -f "${download_dir}/${tarball_name}"
        return 1
    fi

    rm -f "${download_dir}/${tarball_name}"

    local apk_files
    apk_files=$(find "$download_dir" -name "*.apk" 2>/dev/null)

    if [ -z "$apk_files" ]; then
        echo "[错误] 未找到 APK 文件"
        return 1
    fi

    local apk_count
    apk_count=$(echo "$apk_files" | wc -l)
    echo "[安装] 正在安装 $apk_count 个 APK..."

    if apk add --allow-untrusted --force-overwrite $apk_files 2>/dev/null; then
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

uninstall_mosdns() {
    echo ""
    echo "================================"
    echo " 卸载 MosDNS"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-mosdns"
    uninstall_plugin "mosdns"
    uninstall_plugin "luci-i18n-mosdns-zh-cn"

    show_success
}

update_mosdns() {
    echo ""
    echo "================================"
    echo " 更新 MosDNS"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_mosdns
}
