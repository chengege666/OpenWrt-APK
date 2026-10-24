#!/bin/sh
# plugins/momo.sh - Momo 科学上网插件模块（nikkinikki-org/OpenWrt-momo）

install_momo() {
    echo ""
    echo "================================"
    echo " 安装 Momo"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

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
    local repo="OpenWrt-momo"
    local plugin_name="momo"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    local tarball_url
    tarball_url=$(echo "$all_urls" | grep "momo_${dist_arch}-${ver_suffix}\.tar\.gz$" | head -1)

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

    # 按依赖顺序排列：momo 核心 -> luci-app-momo -> i18n
    local core_pkgs="" luci_pkg="" i18n_pkgs=""
    local apk_files="" ipk_files=""
    for f in $pkg_files; do
        case "$(basename "$f")" in
            *.apk) apk_files="$apk_files $f" ;;
            *.ipk) ipk_files="$ipk_files $f" ;;
        esac
        case "$(basename "$f")" in
            luci-i18n-*) i18n_pkgs="$i18n_pkgs $f" ;;
            luci-app-*)  luci_pkg="$f" ;;
            *)           core_pkgs="$core_pkgs $f" ;;
        esac
    done

    local ordered_pkgs="$core_pkgs $luci_pkg $i18n_pkgs"

    local install_ok=0
    if [ -n "$apk_files" ]; then
        echo "[安装] 批量安装 APK 包（按依赖顺序）..."
        if apk add --allow-untrusted --force-overwrite $ordered_pkgs; then
            install_ok=1
        else
            echo "[提示] 批量安装失败，改为按依赖顺序逐个安装..."
            for f in $ordered_pkgs; do
                echo "[安装] 安装 $(basename "$f")..."
                apk add --allow-untrusted --force-overwrite "$f" || echo "[警告] $(basename "$f") 安装失败，继续后续包"
            done
        fi

        # 核心包校验（i18n 语言包缺失不算失败）
        if apk info -e momo >/dev/null 2>&1 && apk info -e luci-app-momo >/dev/null 2>&1; then
            install_ok=1
        else
            install_ok=0
        fi
    fi
    if [ -n "$ipk_files" ]; then
        echo "[安装] 按依赖顺序逐个安装 IPK 包..."
        for f in $ordered_pkgs; do
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

uninstall_momo() {
    echo ""
    echo "================================"
    echo " 卸载 Momo"
    echo "================================"
    echo ""

    uninstall_plugin "momo"
    uninstall_plugin "luci-app-momo"
    uninstall_plugin "luci-i18n-momo-zh-cn"

    show_success
}

update_momo() {
    echo ""
    echo "================================"
    echo " 更新 Momo"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_momo
}
