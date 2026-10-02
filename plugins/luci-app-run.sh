#!/bin/sh
# plugins/luci-app-run.sh - Run 脚本执行器插件模块

install_run() {
    echo ""
    echo "================================"
    echo " 安装 Run"
    echo "================================"
    echo ""

    # 仅支持 APK 系统（OpenWrt 25.x / snapshot）
    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    if [ "$is_apk" -ne 1 ]; then
        echo "[错误] Run 仅提供 APK 安装包，需要 OpenWrt 25.x / snapshot"
        return 1
    fi
    echo "[系统] OpenWrt $DISTRIB_RELEASE (APK)"

    local owner="chengege666"
    local repo="apk-run"
    local plugin_name="run"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    local apk_url
    apk_url=$(echo "$all_urls" | grep "luci-app-run" | grep '\.apk$' | head -1)

    if [ -z "$apk_url" ]; then
        echo "[错误] 未找到 luci-app-run APK 包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local apk_file
    apk_file=$(basename "$apk_url")
    echo "[下载] $apk_file ..."
    if ! download_file "$apk_url" "${download_dir}/${apk_file}"; then
        echo "[错误] 下载失败"
        rm -rf "$download_dir"
        return 1
    fi

    if [ ! -s "${download_dir}/${apk_file}" ]; then
        echo "[错误] 下载文件为空"
        rm -rf "$download_dir"
        return 1
    fi

    echo "[安装] 正在安装..."
    local _out="/tmp/_run_install.log"
    apk add --allow-untrusted --force-overwrite "${download_dir}/${apk_file}" >"$_out" 2>&1
    local _rc=$?
    [ -s "$_out" ] && tail -5 "$_out"
    rm -f "$_out"

    if [ $_rc -ne 0 ]; then
        echo "[错误] 安装失败"
        rm -rf "$download_dir"
        return 1
    fi

    rm -rf "$download_dir"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_run() {
    echo ""
    echo "================================"
    echo " 卸载 Run"
    echo "================================"
    echo ""

    echo "[卸载] 正在卸载 luci-app-run..."
    apk del --purge luci-app-run 2>&1

    echo "[清理] 正在清理残留文件..."
    rm -rf /usr/share/luci/menu.d/*run* 2>/dev/null
    rm -rf /usr/share/rpcd/acl.d/*run* 2>/dev/null
    rm -rf /www/luci-static/resources/view/run 2>/dev/null
    rm -rf /www/luci-static/resources/*run* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_run() {
    echo ""
    echo "================================"
    echo " 更新 Run"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_run
}
