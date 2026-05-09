#!/bin/sh
# plugins/lucky.sh - luci-app-lucky 插件模块

install_lucky() {
    echo ""
    echo "================================"
    echo " 安装 Lucky"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local openwrt_ver
    local ver_prefix="openwrt-24.10"
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release 2>/dev/null
        case "$DISTRIB_RELEASE" in
            25*|snapshot*)
                ver_prefix="SNAPSHOT"
                ;;
        esac
    fi
    echo "[系统] OpenWrt $ver_prefix"

    local owner="sirpdboy"
    local repo="luci-app-lucky"
    local plugin_name="lucky"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local tarball_url
    tarball_url=$(echo "$all_urls" | grep "${ver_prefix}-${arch}\.tar\.gz$" | head -1)

    if [ -z "$tarball_url" ]; then
        echo "[重试] 未找到 ${arch} 匹配包，尝试模糊匹配..."
        tarball_url=$(echo "$all_urls" | grep "${ver_prefix}-" | grep -i "$(uname -m)" | grep "\.tar\.gz$" | head -1)
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

    local ipk_files
    ipk_files=$(find "$download_dir" -name "*.apk" -o -name "*.ipk" 2>/dev/null)

    if [ -z "$ipk_files" ]; then
        echo "[错误] 未找到安装包文件"
        return 1
    fi

    local pkg_count
    pkg_count=$(echo "$ipk_files" | wc -l)
    echo "[安装] 正在安装 $pkg_count 个包..."

    local apk_list=""
    local ipk_list=""
    for f in $ipk_files; do
        case "$f" in
            *.apk)
                apk_list="$apk_list $f"
                ;;
            *.ipk)
                ipk_list="$ipk_list $f"
                ;;
        esac
    done

    local install_ok=0
    if [ -n "$apk_list" ]; then
        echo "[安装] 安装 APK 包..."
        if apk add --allow-untrusted --force-overwrite $apk_list 2>/dev/null; then
            install_ok=1
        fi
    fi

    if [ -n "$ipk_list" ]; then
        echo "[安装] 安装 IPK 包..."
        if opkg install --force-overwrite $ipk_list 2>/dev/null; then
            install_ok=1
        fi
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[成功] 安装完成"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_lucky() {
    echo ""
    echo "================================"
    echo " 卸载 Lucky"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-lucky"
    uninstall_plugin "lucky"

    show_success
}

update_lucky() {
    echo ""
    echo "================================"
    echo " 更新 Lucky"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_lucky
}
