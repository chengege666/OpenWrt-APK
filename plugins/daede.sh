#!/bin/sh
# plugins/daede.sh - luci-app-daede (dae/daed LuCI 界面) 插件模块
# 来源: https://github.com/kenzok8/openwrt-daede
# Release 为散装单架构 apk/ipk（非 tarball），需按架构逐个下载

install_daede() {
    echo ""
    echo "================================"
    echo " 安装 Daede (dae/daed 界面)"
    echo "================================"
    echo ""

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    echo "[系统] OpenWrt $DISTRIB_RELEASE ($([ "$is_apk" -eq 1 ] && echo 'APK' || echo 'OPKG'))"

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    # 架构名映射为 Release 文件名格式
    local file_arch
    case "$arch" in
        x86_64)  file_arch="x86_64" ;;
        aarch64) file_arch="aarch64_generic" ;;
        *)
            echo "[错误] 暂不支持架构 $arch（Release 提供 x86_64 / aarch64 / arm 等）"
            return 1
            ;;
    esac

    local owner="kenzok8"
    local repo="openwrt-daede"
    local plugin_name="daede"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || true

    local tag=""
    if [ -n "$release_json" ]; then
        tag=$(get_release_tag "$release_json")
    fi

    # API 失败时从 HTML 页面回退获取 tag
    if [ -z "$tag" ]; then
        echo "[回退] 从 GitHub 页面获取版本信息..."
        local releases_page
        releases_page=$(wget -q --timeout=15 --user-agent="$_GITHUB_UA" -O- "https://github.com/${owner}/${repo}/releases" 2>/dev/null)
        tag=$(echo "$releases_page" | grep -o '/releases/tag/[^"]*' | head -1 | sed 's|/releases/tag/||')
    fi

    if [ -z "$tag" ]; then
        echo "[错误] 无法获取版本信息（API 与页面均失败）"
        return 1
    fi
    echo "[版本] $tag"

    local all_urls=""
    if [ -n "$release_json" ]; then
        all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")
    fi

    # API 取不到 URL 时从 expanded_assets 页面解析
    if [ -z "$all_urls" ]; then
        echo "[回退] 从 Release 页面解析下载链接..."
        all_urls=$(_fetch_asset_urls_fallback "$owner" "$repo" "$tag")
    fi

    if [ -z "$all_urls" ]; then
        echo "[错误] 无法获取下载链接"
        return 1
    fi

    # 解析 manifest 辅助定位（可选）
    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    # 按架构筛选下载 URL
    local daed_url luci_url btf_url
    if [ "$is_apk" -eq 1 ]; then
        daed_url=$(echo "$all_urls" | grep "^.*daed-.*-${file_arch}\.apk$" | head -1)
        luci_url=$(echo "$all_urls" | grep "^.*luci-app-daede-.*-${file_arch}\.apk$" | head -1)
        btf_url=$(echo "$all_urls"  | grep "^.*vmlinux-btf-.*-${file_arch}\.apk$" | head -1)
    else
        daed_url=$(echo "$all_urls" | grep "^.*daed_.*_${file_arch}\.ipk$" | head -1)
        luci_url=$(echo "$all_urls" | grep "^.*luci-app-daede_.*_all\.ipk$" | head -1)
        btf_url=$(echo "$all_urls"  | grep "^.*vmlinux-btf_.*_${file_arch}\.ipk$" | head -1)
    fi

    if [ -z "$daed_url" ] || [ -z "$luci_url" ]; then
        echo "[错误] 未找到架构 ${file_arch} 的 daed / luci-app-daede 包"
        echo "[调试] 该版本可用链接(前 10):"
        echo "$all_urls" | head -10
        rm -rf "$download_dir"
        return 1
    fi

    # 逐个下载（vmlinux-btf 缺失只警告不阻断，部分内核已内置 BTF）
    local f_daed f_luci f_btf
    f_daed="${download_dir}/$(basename "$daed_url")"
    f_luci="${download_dir}/$(basename "$luci_url")"

    echo "[下载] $(basename "$daed_url")"
    download_file "$daed_url" "$f_daed" || { echo "[错误] daed 下载失败"; rm -rf "$download_dir"; return 1; }

    echo "[下载] $(basename "$luci_url")"
    download_file "$luci_url" "$f_luci" || { echo "[错误] luci-app-daede 下载失败"; rm -rf "$download_dir"; return 1; }

    if [ -n "$btf_url" ]; then
        f_btf="${download_dir}/$(basename "$btf_url")"
        echo "[下载] $(basename "$btf_url")"
        download_file "$btf_url" "$f_btf" || { echo "[警告] vmlinux-btf 下载失败，尝试继续"; f_btf=""; }
    else
        echo "[提示] 未找到匹配内核的 vmlinux-btf，依赖系统自带 BTF"
    fi

    # 按依赖顺序安装：vmlinux-btf -> daed -> luci-app-daede
    local install_ok=0
    if [ "$is_apk" -eq 1 ]; then
        echo "[安装] 批量安装 APK 包..."
        local pkgs=""
        [ -n "$f_btf" ] && pkgs="$f_btf "
        pkgs="${pkgs}${f_daed} ${f_luci}"
        if apk add --allow-untrusted --force-overwrite $pkgs; then
            install_ok=1
        else
            echo "[提示] 批量安装失败，改为逐个安装..."
            [ -n "$f_btf" ] && apk add --allow-untrusted --force-overwrite "$f_btf" 2>/dev/null
            apk add --allow-untrusted --force-overwrite "$f_daed" && \
            apk add --allow-untrusted --force-overwrite "$f_luci" && install_ok=1
        fi

        # 核心包校验
        if apk info -e daed >/dev/null 2>&1 && apk info -e luci-app-daede >/dev/null 2>&1; then
            install_ok=1
        else
            install_ok=0
        fi
    else
        echo "[安装] 逐个安装 IPK 包..."
        [ -n "$f_btf" ] && opkg install --force-overwrite "$f_btf" 2>/dev/null
        if opkg install --force-overwrite "$f_daed" && \
           opkg install --force-overwrite "$f_luci"; then
            install_ok=1
        fi
    fi

    rm -rf "$download_dir"

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    # 启用 daed 服务
    if [ -f "/etc/init.d/daed" ]; then
        echo "[启用] 启用 daed 服务..."
        /etc/init.d/daed enable 2>/dev/null
    fi

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_daede() {
    echo ""
    echo "================================"
    echo " 卸载 Daede (dae/daed 界面)"
    echo "================================"
    echo ""

    for s in daed dae; do
        if [ -f "/etc/init.d/$s" ]; then
            echo "[停止] 停止 ${s} 服务..."
            /etc/init.d/"$s" stop 2>/dev/null
            /etc/init.d/"$s" disable 2>/dev/null
        fi
    done

    uninstall_plugin "luci-app-daede"
    uninstall_plugin "luci-i18n-daede-zh-cn"
    uninstall_plugin "daed"
    uninstall_plugin "dae"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_daede() {
    echo ""
    echo "================================"
    echo " 更新 Daede (dae/daed 界面)"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_daede
}
