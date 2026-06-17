#!/bin/sh
# plugins/nikki.sh - Nikki 科学上网插件模块

install_nikki() {
    echo ""
    echo "================================"
    echo " 安装 Nikki"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local openwrt_ver
    local ver_suffix="openwrt-24.10"
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release 2>/dev/null
        case "$DISTRIB_RELEASE" in
            25.*) ver_suffix="openwrt-25.12" ;;
            snapshot*) ver_suffix="SNAPSHOT" ;;
        esac
    fi
    echo "[系统] OpenWrt $ver_suffix"

    . /etc/openwrt_release 2>/dev/null
    local dist_arch="${DISTRIB_ARCH:-$arch}"

    local owner="nikkinikki-org"
    local repo="OpenWrt-nikki"
    local plugin_name="nikki"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    local tarball_url
    tarball_url=$(echo "$all_urls" | grep "nikki_${dist_arch}-${ver_suffix}\.tar\.gz$" | head -1)

    if [ -z "$tarball_url" ]; then
        echo "[重试] 未找到 ${dist_arch} 匹配包，尝试模糊匹配..."
        tarball_url=$(echo "$all_urls" | grep "${ver_suffix}\.tar\.gz$" | grep -i "${arch}" | head -1)
    fi

    if [ -z "$tarball_url" ]; then
        tarball_url=$(echo "$all_urls" | grep "\.tar\.gz$" | grep -i "${arch}" | head -1)
    fi

    if [ -z "$tarball_url" ]; then
        echo "[错误] 未找到匹配架构 ${arch} 的下载包"
        return 1
    fi

    local tarball_name
    tarball_name=$(basename "$tarball_url")

    if ! download_file "$tarball_url" "${CACHE_DIR}/${plugin_name}/${tarball_name}"; then
        echo "[错误] 下载失败"
        return 1
    fi

    echo "[解压] 正在解压..."
    if ! tar xzf "${CACHE_DIR}/${plugin_name}/${tarball_name}" -C "${CACHE_DIR}/${plugin_name}" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -f "${CACHE_DIR}/${plugin_name}/${tarball_name}"
        return 1
    fi

    rm -f "${CACHE_DIR}/${plugin_name}/${tarball_name}"

    local pkg_files
    pkg_files=$(find "${CACHE_DIR}/${plugin_name}" -name "*.apk" -o -name "*.ipk" 2>/dev/null)

    if [ -z "$pkg_files" ]; then
        echo "[错误] 未找到安装包文件"
        return 1
    fi

    local pkg_count
    pkg_count=$(echo "$pkg_files" | wc -l)
    echo "[安装] 正在安装 $pkg_count 个包..."

    local apk_files=""
    local ipk_files=""
    for f in $pkg_files; do
        case "$f" in
            *.apk) apk_files="$apk_files $f" ;;
            *.ipk) ipk_files="$ipk_files $f" ;;
        esac
    done

    local install_ok=0
    if [ -n "$apk_files" ]; then
        echo "[安装] 批量安装 APK 包..."
        if apk add --allow-untrusted --force-overwrite $apk_files; then
            install_ok=1
        else
            echo "[错误] 批量安装失败，尝试逐个安装..."
            for f in $apk_files; do
                echo "[安装] 安装 $(basename "$f")..."
                if apk add --allow-untrusted --force-overwrite "$f"; then
                    install_ok=1
                fi
            done
        fi
    fi
    if [ -n "$ipk_files" ]; then
        for f in $ipk_files; do
            echo "[安装] 安装 $(basename "$f")..."
            if opkg install --force-overwrite "$f"; then
                install_ok=1
            fi
        done
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_nikki() {
    echo ""
    echo "================================"
    echo " 卸载 Nikki"
    echo "================================"
    echo ""

    uninstall_plugin "nikki"
    uninstall_plugin "luci-app-nikki"
    uninstall_plugin "luci-i18n-nikki-zh-cn"

    show_success
}

update_nikki() {
    echo ""
    echo "================================"
    echo " 更新 Nikki"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_nikki
}
