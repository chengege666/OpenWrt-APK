#!/bin/sh
# plugins/luci-app-uninstall.sh - 高级卸载插件模块
# 插件来源: https://xz.vumstar.com/ （由 GitHub Actions 转发到本仓库 Release）

install_uninstall_plugin() {
    echo ""
    echo "================================"
    echo " 安装 高级卸载"
    echo "================================"
    echo ""

    # 判断系统类型（APK 为 OpenWrt 25.x / snapshot，否则为 opkg）
    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    local owner="chengege666"
    local repo="OpenWrt-APK"
    local plugin_name="uninstall"

    # 本仓库可能存在其他插件 Release，按 uninstall- 前缀过滤 tag，
    # 避免 /releases/latest 取错版本（仓库无 Release 时该接口会 404）
    local releases_json
    releases_json=$(_fetch_github_api "https://api.github.com/repos/${owner}/${repo}/releases?per_page=30" "Releases: $owner/$repo") || return 1

    local tag
    tag=$(echo "$releases_json" | sed -n 's/.*"tag_name": *"\(uninstall-[^"]*\)".*/\1/p' | head -1)
    if [ -z "$tag" ]; then
        echo "[错误] 未找到 高级卸载 Release（请先在 GitHub Actions 运行 Fetch Uninstall Plugin）"
        return 1
    fi
    echo "[版本] $tag"

    local release_json
    release_json=$(_fetch_github_api "https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}" "Release: $tag") || return 1

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")
    all_urls=$(echo "$all_urls" | grep "luci-app-uninstall")

    if [ -z "$all_urls" ]; then
        echo "[错误] 未找到 高级卸载 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    if [ "$is_apk" -eq 1 ]; then
        # APK 系统（OpenWrt 25.x）：安装 .apk 包
        echo "[系统] OpenWrt $DISTRIB_RELEASE (APK)"

        local apk_url
        apk_url=$(echo "$all_urls" | grep '\.apk$' | head -1)
        if [ -z "$apk_url" ]; then
            echo "[错误] 未找到 APK 安装包"
            rm -rf "$download_dir"
            return 1
        fi

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
        local _out="/tmp/_uninstall_install.log"
        apk add --allow-untrusted --force-overwrite "${download_dir}/${apk_file}" >"$_out" 2>&1
        local _rc=$?
        [ -s "$_out" ] && tail -5 "$_out"
        rm -f "$_out"

        if [ $_rc -ne 0 ]; then
            echo "[错误] 安装失败"
            rm -rf "$download_dir"
            return 1
        fi
    else
        # opkg 系统（iStoreOS / OpenWrt 21-23）：执行 .run 自解压安装器
        echo "[系统] OpenWrt $DISTRIB_RELEASE (opkg)"

        local run_url
        run_url=$(echo "$all_urls" | grep '\.run$' | head -1)
        if [ -z "$run_url" ]; then
            echo "[错误] 未找到 RUN 安装包"
            rm -rf "$download_dir"
            return 1
        fi

        local run_file
        run_file=$(basename "$run_url")
        echo "[下载] $run_file ..."
        if ! download_file "$run_url" "${download_dir}/${run_file}"; then
            echo "[错误] 下载失败"
            rm -rf "$download_dir"
            return 1
        fi

        if [ ! -s "${download_dir}/${run_file}" ]; then
            echo "[错误] 下载文件为空"
            rm -rf "$download_dir"
            return 1
        fi

        echo "[安装] 正在执行 .run 安装器（约 1-2 分钟）..."
        sh "${download_dir}/${run_file}"
        local _rc=$?

        if [ $_rc -ne 0 ]; then
            echo "[错误] 安装失败（退出码 $_rc）"
            rm -rf "$download_dir"
            return 1
        fi
    fi

    rm -rf "$download_dir"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_uninstall_plugin() {
    echo ""
    echo "================================"
    echo " 卸载 高级卸载"
    echo "================================"
    echo ""

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    echo "[卸载] 正在卸载 luci-app-uninstall..."
    if [ "$is_apk" -eq 1 ]; then
        apk del --purge luci-app-uninstall 2>&1
    else
        opkg remove luci-app-uninstall 2>&1
    fi

    echo "[清理] 正在清理残留文件..."
    rm -rf /usr/share/luci/menu.d/*uninstall* 2>/dev/null
    rm -rf /usr/share/rpcd/acl.d/*uninstall* 2>/dev/null
    rm -rf /www/luci-static/resources/view/*uninstall* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_uninstall_plugin() {
    echo ""
    echo "================================"
    echo " 更新 高级卸载"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_uninstall_plugin
}
