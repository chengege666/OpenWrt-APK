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
    local download_dir="${CACHE_DIR}/${plugin_name}"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    if [ -z "$all_urls" ]; then
        echo "[错误] 未获取到下载链接"
        return 1
    fi

    # 收集全部 APK 链接
    local apk_urls
    apk_urls=$(echo "$all_urls" | grep "\.apk$" 2>/dev/null)

    if [ -z "$apk_urls" ]; then
        echo "[错误] Release 中未找到 APK 文件"
        return 1
    fi

    # 确认包含主题本体
    if ! echo "$apk_urls" | grep -q "luci-theme-argon"; then
        echo "[错误] Release 中未包含 luci-theme-argon 主题本体包"
        return 1
    fi

    # 清理旧缓存，准备下载目录
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    # 逐个下载 APK
    echo "$apk_urls" | while IFS= read -r url; do
        [ -z "$url" ] && continue
        local filename
        filename=$(basename "$url")
        download_file "$url" "${download_dir}/${filename}" || true
    done

    # 统计实际下载成功的 APK 文件
    local apk_files
    apk_files=$(find "$download_dir" -maxdepth 1 -name "*.apk" -type f 2>/dev/null)
    local apk_count=0
    [ -n "$apk_files" ] && apk_count=$(echo "$apk_files" | wc -l)

    if [ "$apk_count" -eq 0 ]; then
        echo "[错误] 没有成功下载任何 APK 包"
        return 1
    fi
    echo "[下载] 完成 $apk_count 个 APK 包"

    # 按依赖顺序安装：先 theme 本体，再 config，再 i18n，最后其他
    echo "[安装] 正在安装 $apk_count 个 APK 包..."
    cd "$download_dir" || return 1

    local theme_apk=$(find . -maxdepth 1 -name "luci-theme-argon-*.apk" -type f | head -1)
    local config_apk=$(find . -maxdepth 1 -name "luci-app-argon-config-*.apk" -type f | head -1)
    local i18n_apk=$(find . -maxdepth 1 -name "luci-i18n-argon-config*.apk" -type f | head -1)
    local other_apks=$(find . -maxdepth 1 -name "*.apk" -type f \
        | grep -v "luci-theme-argon-" \
        | grep -v "luci-app-argon-config-" \
        | grep -v "luci-i18n-argon-config" \
        || true)

    local install_list=""
    [ -n "$theme_apk" ]  && install_list="$install_list $theme_apk"
    [ -n "$config_apk" ] && install_list="$install_list $config_apk"
    [ -n "$i18n_apk" ]   && install_list="$install_list $i18n_apk"
    [ -n "$other_apks" ] && install_list="$install_list $other_apks"

    local install_log="${download_dir}/install.log"
    : > "$install_log"

    if apk add --allow-untrusted --force-overwrite $install_list >>"$install_log" 2>&1; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败，详细日志:"
        sed 's/^/  /' "$install_log" | tail -30
        return 1
    fi

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* /tmp/.luci* 2>/dev/null

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
    uninstall_plugin "argon-config"

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
