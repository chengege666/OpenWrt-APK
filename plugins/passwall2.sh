#!/bin/sh
# plugins/passwall2.sh - luci-app-passwall2 插件模块

install_passwall2() {
    echo ""
    echo "================================"
    echo " 安装 PassWall2"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local owner="Openwrt-Passwall"
    local repo="openwrt-passwall2"
    local plugin_name="passwall2"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    local luci_url
    luci_url=$(echo "$all_urls" | grep "luci-app-passwall2" | grep "\.apk$" | head -1)

    if [ -z "$luci_url" ]; then
        luci_url=$(echo "$all_urls" | grep "luci-app-passwall2" | grep "\.ipk$" | head -1)
    fi

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-passwall2-zh-cn" | grep "\.apk$" | head -1)

    if [ -z "$i18n_url" ]; then
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-passwall2-zh-cn" | grep "\.ipk$" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-passwall2 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"

    local pkg_zip_url
    pkg_zip_url=$(echo "$all_urls" | grep "passwall_packages_apk_${arch}\.zip$" | head -1)

    if [ -z "$pkg_zip_url" ]; then
        pkg_zip_url=$(echo "$all_urls" | grep "passwall_packages_apk_" | grep "${arch}" | grep "\.zip$" | head -1)
    fi

    if [ -z "$pkg_zip_url" ]; then
        pkg_zip_url=$(echo "$all_urls" | grep "passwall_packages_ipk_${arch}\.zip$" | head -1)
    fi

    if [ -z "$pkg_zip_url" ]; then
        pkg_zip_url=$(echo "$all_urls" | grep "passwall_packages_ipk_" | grep "${arch}" | grep "\.zip$" | head -1)
    fi

    if [ -z "$pkg_zip_url" ]; then
        local avail_archs
        avail_archs=$(echo "$all_urls" | grep "passwall_packages_" | grep "\.zip$" | sed 's/.*passwall_packages_[a-z]*_//' | sed 's/\.zip//' | sort -u | tr '\n' ' ')
        echo "[错误] 未找到匹配架构 ${arch} 的依赖包"
        echo "[提示] 当前架构: $arch"
        echo "[提示] 可用架构: $avail_archs"
        return 1
    fi

    local luci_name
    luci_name=$(basename "$luci_url")
    if ! download_file "$luci_url" "${download_dir}/${luci_name}"; then
        echo "[错误] 下载失败: $luci_name"
        return 1
    fi

    if [ -n "$i18n_url" ]; then
        local i18n_name
        i18n_name=$(basename "$i18n_url")
        download_file "$i18n_url" "${download_dir}/${i18n_name}" || echo "[警告] 中文包下载失败"
    fi

    local zip_name
    zip_name=$(basename "$pkg_zip_url")
    if ! download_file "$pkg_zip_url" "${download_dir}/${zip_name}"; then
        echo "[错误] 下载失败: $zip_name"
        return 1
    fi

    echo "[解压] 正在解压依赖包..."
    if ! unzip -o -q "${download_dir}/${zip_name}" -d "${download_dir}/packages" 2>/dev/null; then
        echo "[错误] 解压失败: $zip_name"
        rm -f "${download_dir}/${zip_name}"
        return 1
    fi

    rm -f "${download_dir}/${zip_name}"

    local is_apk=0
    case "$luci_name" in *.apk) is_apk=1 ;; esac

    if [ "$is_apk" -eq 1 ]; then
        local apk_files
        apk_files=$(find "${download_dir}/packages" -name "*.apk" 2>/dev/null)

        if [ -z "$apk_files" ]; then
            echo "[警告] 解压后未找到 APK 依赖包，尝试查找 IPK..."
            apk_files=$(find "${download_dir}/packages" -name "*.ipk" 2>/dev/null)
        fi

        if [ -n "$apk_files" ]; then
            local pkg_count
            pkg_count=$(echo "$apk_files" | wc -l)
            echo "[安装] 正在安装 $pkg_count 个依赖包..."
            apk add --allow-untrusted --force-overwrite $apk_files 2>/dev/null || echo "[警告] 部分依赖包安装失败"
        fi

        echo "[安装] 安装 LuCI 主程序..."
        apk add --allow-untrusted "${download_dir}/${luci_name}" 2>/dev/null

        if [ -f "${download_dir}/${i18n_name:-__empty__}" ] && [ -n "$i18n_name" ]; then
            echo "[安装] 安装中文包..."
            apk add --allow-untrusted "${download_dir}/${i18n_name}" 2>/dev/null
        fi
    else
        local ipk_files
        ipk_files=$(find "${download_dir}/packages" -name "*.ipk" 2>/dev/null)

        if [ -n "$ipk_files" ]; then
            local pkg_count
            pkg_count=$(echo "$ipk_files" | wc -l)
            echo "[安装] 正在安装 $pkg_count 个依赖包..."
            opkg install --force-reinstall --force-overwrite $ipk_files 2>/dev/null || echo "[警告] 部分依赖包安装失败"
        fi

        echo "[安装] 安装 LuCI 主程序..."
        opkg install --force-overwrite "${download_dir}/${luci_name}" 2>/dev/null

        if [ -f "${download_dir}/${i18n_name:-__empty__}" ] && [ -n "$i18n_name" ]; then
            echo "[安装] 安装中文包..."
            opkg install --force-overwrite "${download_dir}/${i18n_name}" 2>/dev/null
        fi
    fi

    echo "[成功] 安装完成"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_passwall2() {
    echo ""
    echo "================================"
    echo " 卸载 PassWall2"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-passwall2"
    uninstall_plugin "luci-i18n-passwall2-zh-cn"

    show_success
}

update_passwall2() {
    echo ""
    echo "================================"
    echo " 更新 PassWall2"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_passwall2
}
