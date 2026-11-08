#!/bin/sh
# plugins/adzero.sh - AdZero 广告过滤与 DNS 分流插件模块

install_adzero() {
    echo ""
    echo "================================"
    echo " 安装 AdZero"
    echo "================================"
    echo ""

    local owner="slobys"
    local repo="AdZero"
    local plugin_name="adzero"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")
    if [ -z "$all_urls" ]; then
        echo "[错误] 无法获取下载链接"
        return 1
    fi

    # 发布页提供 noarch 通用 apk
    local apk_url
    apk_url=$(echo "$all_urls" | grep 'luci-app-adzero_.*_noarch\.apk$' | head -1)
    if [ -z "$apk_url" ]; then
        echo "[错误] 发布页未找到 luci-app-adzero noarch apk"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    if ! download_file "$apk_url" "${download_dir}/luci-app-adzero.apk"; then
        echo "[错误] 下载失败"
        return 1
    fi

    echo "[安装] 正在安装..."
    cd "$download_dir" || return 1
    if apk add --allow-untrusted --force-overwrite --clean-protected *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo ""
    echo "[提示] 安装后请打开 LuCI：服务 → AdZero"
    echo "[提示] 页面未更新请按 Ctrl+F5 刷新"
    show_success
    return 0
}

uninstall_adzero() {
    echo ""
    echo "================================"
    echo " 卸载 AdZero"
    echo "================================"
    echo ""

    # 先 disable 恢复 AdZero 接管的 DNS 设置
    if [ -x /usr/libexec/adzero/ctl ]; then
        echo "[恢复] 正在恢复 AdZero 接管的网络设置..."
        /usr/libexec/adzero/ctl disable 2>/dev/null || true
    fi

    echo "[卸载] 正在移除 luci-app-adzero 包..."
    if command -v apk >/dev/null 2>&1 && apk info --installed luci-app-adzero >/dev/null 2>&1; then
        apk del luci-app-adzero 2>/dev/null || true
    elif command -v opkg >/dev/null 2>&1 && opkg list-installed 2>/dev/null | grep -q "^luci-app-adzero"; then
        opkg remove luci-app-adzero --autoremove 2>/dev/null || true
    else
        echo "[提示] 包管理器中未找到 luci-app-adzero，可能已卸载"
    fi

    echo "[清理] 清理残留文件..."
    rm -rf /usr/libexec/adzero 2>/dev/null
    rm -rf /usr/share/adzero 2>/dev/null
    rm -f /etc/init.d/adzero 2>/dev/null
    rm -rf /tmp/luci-indexcache 2>/dev/null
    rm -rf /tmp/luci-modulecache 2>/dev/null

    echo "[提示] 配置文件 /etc/adzero 已保留，如需彻底清理请手动删除"

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] AdZero 卸载完成"
}

update_adzero() {
    echo ""
    echo "================================"
    echo " 更新 AdZero"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_adzero
}
