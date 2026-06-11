#!/bin/sh
# plugins/lucky.sh - Lucky 插件模块

install_lucky() {
    echo ""
    echo "================================"
    echo " 安装 Lucky"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

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

    local owner repo
    owner=$(get_plugin_owner "lucky")
    repo=$(get_plugin_repo "lucky")

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

    local tarball_name
    tarball_name=$(basename "$tarball_url")

    if ! download_file "$tarball_url" "${CACHE_DIR}/lucky/${tarball_name}"; then
        echo "[错误] 下载失败"
        return 1
    fi

    echo "[解压] 正在解压..."
    if ! tar xzf "${CACHE_DIR}/lucky/${tarball_name}" -C "${CACHE_DIR}/lucky" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -f "${CACHE_DIR}/lucky/${tarball_name}"
        return 1
    fi

    rm -f "${CACHE_DIR}/lucky/${tarball_name}"

    local pkg_files
    pkg_files=$(find "${CACHE_DIR}/lucky" \( -name "*.apk" -o -name "*.ipk" \) 2>/dev/null)

    if [ -z "$pkg_files" ]; then
        echo "[错误] 未找到安装包文件"
        return 1
    fi

    local pkg_count
    pkg_count=$(echo "$pkg_files" | wc -l)
    echo "[安装] 正在安装 $pkg_count 个包..."

    local apk_list=""
    local ipk_list=""
    for f in $pkg_files; do
        case "$f" in
            *.apk) apk_list="$apk_list $f" ;;
            *.ipk) ipk_list="$ipk_list $f" ;;
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

    restart_luci
    save_version "lucky" "$tag"
    show_success
}

uninstall_lucky() {
    manager_uninstall "lucky" "luci-app-lucky" "lucky"
}

update_lucky() {
    local owner repo
    owner=$(get_plugin_owner "lucky")
    repo=$(get_plugin_repo "lucky")
    manager_update "lucky" "$owner" "$repo" install_lucky
}
