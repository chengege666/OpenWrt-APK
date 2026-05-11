#!/bin/sh
# plugins/taskplan.sh - luci-app-taskplan 插件模块

install_taskplan() {
    echo ""
    echo "================================"
    echo " 安装 TaskPlan"
    echo "================================"
    echo ""

    local owner="sirpdboy"
    local repo="luci-app-taskplan"
    local plugin_name="taskplan"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local app_url
    app_url=$(echo "$all_urls" | grep "luci-app-taskplan-" | grep "\.apk$" | head -1)

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-taskplan-zh-cn-" | grep "\.apk$" | head -1)

    if [ -z "$app_url" ]; then
        echo "[错误] 未找到 luci-app-taskplan 安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local apk_files=""

    if [ -n "$app_url" ]; then
        local app_name
        app_name=$(basename "$app_url")
        echo "[下载] $app_name"
        if ! wget -q --timeout=60 -O "${download_dir}/${app_name}" "$app_url" 2>/dev/null; then
            echo "[错误] 下载失败: $app_name"
            rm -f "${download_dir}/${app_name}"
            return 1
        fi
        apk_files="$apk_files ${download_dir}/${app_name}"
    fi

    if [ -n "$i18n_url" ]; then
        local i18n_name
        i18n_name=$(basename "$i18n_url")
        echo "[下载] $i18n_name"
        if ! wget -q --timeout=60 -O "${download_dir}/${i18n_name}" "$i18n_url" 2>/dev/null; then
            echo "[警告] 中文包下载失败，仅安装主程序"
        else
            apk_files="$apk_files ${download_dir}/${i18n_name}"
        fi
    fi

    if [ -z "$apk_files" ]; then
        echo "[错误] 未找到安装包文件"
        return 1
    fi

    local pkg_count
    pkg_count=$(echo "$apk_files" | wc -w)
    echo "[安装] 正在安装 $pkg_count 个包..."

    if apk add --allow-untrusted --force-overwrite $apk_files 2>/dev/null; then
        echo "[成功] 安装完成"
    else
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_taskplan() {
    echo ""
    echo "================================"
    echo " 卸载 TaskPlan"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-taskplan"
    uninstall_plugin "luci-i18n-taskplan-zh-cn"

    show_success
}

update_taskplan() {
    echo ""
    echo "================================"
    echo " 更新 TaskPlan"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_taskplan
}
