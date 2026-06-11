#!/bin/sh
# core/version.sh - 版本管理模块
# 记录每个插件的已安装版本，支持版本对比、跳过重复安装

VERSION_DIR="/root/apk-store/versions"

init_version_db() {
    mkdir -p "$VERSION_DIR"
}

# 保存插件版本
save_version() {
    local plugin="$1"
    local version="$2"
    echo "$version" > "${VERSION_DIR}/${plugin}"
    date '+%Y-%m-%d %H:%M:%S' > "${VERSION_DIR}/${plugin}.time"
}

# 读取本地版本
get_local_version() {
    local plugin="$1"
    if [ -f "${VERSION_DIR}/${plugin}" ]; then
        cat "${VERSION_DIR}/${plugin}"
    fi
}

# 读取本地安装时间
get_local_version_time() {
    local plugin="$1"
    if [ -f "${VERSION_DIR}/${plugin}.time" ]; then
        cat "${VERSION_DIR}/${plugin}.time"
    fi
}

# 删除版本记录
remove_version() {
    local plugin="$1"
    rm -f "${VERSION_DIR}/${plugin}" "${VERSION_DIR}/${plugin}.time"
}

# 检查是否已是最新
is_latest() {
    local plugin="$1"
    local remote_version="$2"
    local local_version
    local_version=$(get_local_version "$plugin")
    [ -n "$local_version" ] && [ "$local_version" = "$remote_version" ]
}

# 显示版本对比信息
show_version_info() {
    local plugin="$1"
    local remote_version="$2"
    local local_version
    local_version=$(get_local_version "$plugin")

    echo "[版本] 远程: $remote_version"
    if [ -n "$local_version" ]; then
        echo "[版本] 本地: $local_version ($(get_local_version_time "$plugin"))"
        if [ "$local_version" = "$remote_version" ]; then
            echo "[状态] 已是最新"
        else
            echo "[状态] 可更新: $local_version → $remote_version"
        fi
    else
        echo "[版本] 本地: 未安装"
    fi
}

# 显示更新前后的版本变化
show_update_banner() {
    local plugin="$1"
    local new_version="$2"
    local old_version
    old_version=$(get_local_version "$plugin")

    echo ""
    echo "================================"
    if [ -n "$old_version" ]; then
        echo " 更新 $(get_plugin_name "$plugin"): $old_version → $new_version"
    else
        echo " 安装 $(get_plugin_name "$plugin") $new_version"
    fi
    echo "================================"
    echo ""
}
