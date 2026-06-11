#!/bin/sh
# core/manager.sh - 统一安装/更新/卸载引擎
# 提供通用的构建块，各插件可直接组合使用

# ============================================================
# 预检：打印安装标题 + 架构检测
# ============================================================
manager_print_header() {
    local plugin_id="$1"
    echo ""
    echo "================================"
    echo " 安装 $(get_plugin_name "$plugin_id")"
    echo "================================"
    echo ""
}

manager_print_update_header() {
    local plugin_id="$1"
    local old_ver="$2"
    local new_ver="$3"
    local name
    name=$(get_plugin_name "$plugin_id")
    echo ""
    echo "================================"
    if [ -n "$old_ver" ]; then
        echo " 更新 $name: $old_ver → $new_ver"
    else
        echo " 安装 $name"
    fi
    echo "================================"
    echo ""
}

# ============================================================
# 通用：从 GitHub Releases 获取远程版本号
# ============================================================
manager_get_remote_tag() {
    local owner="$1"
    local repo="$2"
    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1
    get_release_tag "$release_json"
}

# ============================================================
# 通用：APK 类型安装（下载最新单个 .apk → 安装）
# 支持 i18n 中文包自动匹配
#   manager_install_apk <plugin_id> <owner> <repo> [initd_service]
# ============================================================
manager_install_apk() {
    local plugin_id="$1"
    local owner="$2"
    local repo="$3"
    local initd_service="$4"

    local release_json tag all_urls
    release_json=$(get_latest_release "$owner" "$repo") || return 1
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"
    all_urls=$(get_download_urls "$release_json")

    # 找主包
    local main_url
    main_url=$(echo "$all_urls" | grep "\.apk$" | grep -iv "i18n" | head -1)

    # 如果没找到，降级取第一个 .apk
    if [ -z "$main_url" ]; then
        main_url=$(echo "$all_urls" | grep "\.apk$" | head -1)
    fi

    if [ -z "$main_url" ]; then
        echo "[错误] 未找到 APK 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_id}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local main_file
    main_file=$(basename "$main_url")
    if ! download_file "$main_url" "${download_dir}/${main_file}"; then
        echo "[错误] 下载失败: $main_file"
        return 1
    fi

    # 尝试下载中文包
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "i18n.*zh-cn.*\.apk$" | head -1)
    if [ -n "$i18n_url" ]; then
        local i18n_file
        i18n_file=$(basename "$i18n_url")
        download_file "$i18n_url" "${download_dir}/${i18n_file}" 2>/dev/null || echo "[提示] 中文包下载失败，仅安装主包"
    fi

    echo "[安装] 正在安装..."
    cd "$download_dir" || return 1
    if apk add --allow-untrusted --force-overwrite *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败"
        return 1
    fi

    # 后置处理
    manager_post_install "$plugin_id" "$initd_service"
    save_version "$plugin_id" "$tag"
    return 0
}

# ============================================================
# 通用：Tarball 类型安装（下载 tar.gz → 解压 → 装所有 .apk）
#   manager_install_tarball <plugin_id> <owner> <repo> [arch_filter] [initd_service]
# ============================================================
manager_install_tarball() {
    local plugin_id="$1"
    local owner="$2"
    local repo="$3"
    local arch_filter="${4:-}"
    local initd_service="${5:-}"

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local release_json tag all_urls
    release_json=$(get_latest_release "$owner" "$repo") || return 1
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"
    all_urls=$(get_download_urls "$release_json")

    local tarball_url
    if [ -n "$arch_filter" ]; then
        # 自定义过滤
        tarball_url=$(echo "$all_urls" | grep "\.tar\.gz$" | grep "$arch_filter" | head -1)
    else
        # 自动按架构匹配
        tarball_url=$(echo "$all_urls" | grep "\.tar\.gz$" | grep -i "${arch}" | head -1)
    fi

    if [ -z "$tarball_url" ]; then
        # 兜底：随便取第一个 tar.gz
        tarball_url=$(echo "$all_urls" | grep "\.tar\.gz$" | head -1)
    fi

    if [ -z "$tarball_url" ]; then
        echo "[错误] 未找到压缩包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_id}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local tarball_name
    tarball_name=$(basename "$tarball_url")
    echo "[下载] $tarball_name"
    if ! download_file "$tarball_url" "${download_dir}/${tarball_name}"; then
        echo "[错误] 下载失败"
        return 1
    fi

    echo "[解压] 正在解压..."
    if ! tar xzf "${download_dir}/${tarball_name}" -C "$download_dir" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -f "${download_dir}/${tarball_name}"
        return 1
    fi
    rm -f "${download_dir}/${tarball_name}"

    # 安装所有 APK
    local apk_files
    apk_files=$(find "$download_dir" -name "*.apk" 2>/dev/null)
    if [ -z "$apk_files" ]; then
        echo "[错误] 未找到 APK 文件"
        return 1
    fi

    local apk_count
    apk_count=$(echo "$apk_files" | wc -l)
    echo "[安装] 正在安装 $apk_count 个 APK..."
    if apk add --allow-untrusted --force-overwrite $apk_files 2>/dev/null; then
        echo "[成功] 安装完成"
    else
        echo "[错误] 安装失败"
        return 1
    fi

    # 后置处理
    manager_post_install "$plugin_id" "$initd_service"
    save_version "$plugin_id" "$tag"
    return 0
}

# ============================================================
# 通用：后置处理（修复依赖 + 启用服务 + 重启 LuCI）
# ============================================================
manager_post_install() {
    local plugin_id="$1"
    local initd_service="$2"

    fix_dependencies

    if [ -n "$initd_service" ] && [ -f "/etc/init.d/${initd_service}" ]; then
        echo "[启用] 启用 ${initd_service} 服务..."
        /etc/init.d/"${initd_service}" enable 2>/dev/null
        /etc/init.d/"${initd_service}" start 2>/dev/null
    fi

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    restart_luci
}

# ============================================================
# 通用：版本对比更新
# 先查远程版本 → 对比本地 → 有更新才执行 install_func
#   manager_update <plugin_id> <owner> <repo> <install_func>
# ============================================================
manager_update() {
    local plugin_id="$1"
    local owner="$2"
    local repo="$3"
    local install_func="$4"

    local old_ver new_ver
    old_ver=$(get_local_version "$plugin_id")
    new_ver=$(manager_get_remote_tag "$owner" "$repo") || return 1

    if [ -z "$new_ver" ]; then
        echo "[错误] 无法获取远程版本"
        sleep 2
        return
    fi

    if [ -n "$old_ver" ] && [ "$old_ver" = "$new_ver" ]; then
        echo "[跳过] $(get_plugin_name "$plugin_id") 已是最新版本: $new_ver"
        sleep 1
        return 0
    fi

    manager_print_update_header "$plugin_id" "$old_ver" "$new_ver"

    # 调用真实的安装函数
    $install_func

    return $?
}

# ============================================================
# 通用：卸载（包名列表）
#   manager_uninstall <plugin_id> <pkg1> [pkg2] ...
# ============================================================
manager_uninstall() {
    local plugin_id="$1"
    shift

    echo ""
    echo "================================"
    echo " 卸载 $(get_plugin_name "$plugin_id")"
    echo "================================"
    echo ""

    # 停止服务
    local svc
    svc=$(get_plugin_service "$plugin_id")
    if [ -n "$svc" ] && [ -f "/etc/init.d/$svc" ]; then
        echo "[停止] 停止 ${svc} 服务..."
        /etc/init.d/"$svc" stop 2>/dev/null
        /etc/init.d/"$svc" disable 2>/dev/null
    fi

    # 卸载包
    for pkg in "$@"; do
        [ -n "$pkg" ] && uninstall_plugin "$pkg"
    done

    # 清理版本记录
    remove_version "$plugin_id"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

# ============================================================
# 通用：清理缓存 + 安装（旧版更新模式用）
# ============================================================
manager_reinstall() {
    local plugin_id="$1"
    local install_func="$2"

    cleanup_old_cache
    $install_func
}
