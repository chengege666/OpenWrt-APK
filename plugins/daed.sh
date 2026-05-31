#!/bin/sh
# plugins/daed.sh - Daed 插件模块

install_daed() {
    echo ""
    echo "================================"
    echo " 安装 Daed"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    local openwrt_ver="25.12"
    echo "[系统] OpenWrt $openwrt_ver"

    local owner="QiuSimons"
    local repo="luci-app-daed"
    local plugin_name="daed"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local core_url
    case "$arch" in
        x86_64)
            core_url=$(echo "$all_urls" | grep "daed-.*-x86_64-openwrt-25\.12\.apk$" | head -1)
            ;;
        aarch64)
            core_url=$(echo "$all_urls" | grep "daed-.*-aarch64_generic-openwrt-25\.12\.apk$" | head -1)
            ;;
        i386_pentium4)
            core_url=$(echo "$all_urls" | grep "daed-.*-i386_pentium4-openwrt-25\.12\.apk$" | head -1)
            ;;
        *)
            echo "[错误] 不支持的架构: $arch"
            return 1
            ;;
    esac

    if [ -z "$core_url" ]; then
        echo "[错误] 未找到匹配架构 ${arch} 的核心下载包"
        return 1
    fi

    local luci_url
    luci_url=$(echo "$all_urls" | grep "luci-app-daed.*-openwrt-25\.12\.apk$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 LuCI 界面下载包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    echo "[下载] 核心程序..."
    local core_file
    core_file=$(basename "$core_url")
    if ! wget -q --timeout=60 -O "${download_dir}/${core_file}" "$core_url" 2>/dev/null; then
        echo "[错误] 核心程序下载失败"
        rm -f "${download_dir}/${core_file}"
        return 1
    fi
    if [ ! -s "${download_dir}/${core_file}" ]; then
        echo "[错误] 核心程序文件为空"
        rm -f "${download_dir}/${core_file}"
        return 1
    fi

    echo "[下载] LuCI 界面..."
    local luci_file
    luci_file=$(basename "$luci_url")
    if ! wget -q --timeout=60 -O "${download_dir}/${luci_file}" "$luci_url" 2>/dev/null; then
        echo "[错误] LuCI 界面下载失败"
        rm -f "${download_dir}/${luci_file}"
        return 1
    fi
    if [ ! -s "${download_dir}/${luci_file}" ]; then
        echo "[错误] LuCI 界面文件为空"
        rm -f "${download_dir}/${luci_file}"
        return 1
    fi

    echo "[依赖] 尝试安装 vmlinux-btf..."
    apk add --allow-untrusted vmlinux-btf 2>/dev/null || echo "[提示] vmlinux-btf 不可用，将跳过依赖检查"

    echo "[安装] 正在安装..."
    if cd "$download_dir" && apk add --allow-untrusted --force-overwrite --clean-protected *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[重试] 完整安装失败，尝试跳过依赖检查..."
        if cd "$download_dir" && apk add --allow-untrusted --force-overwrite --clean-protected --no-deps *.apk 2>/dev/null; then
            echo "[成功] APK 安装完成（跳过依赖）"
        else
            echo "[错误] APK 安装失败"
            cd /
            return 1
        fi
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_daed() {
    echo ""
    echo "================================"
    echo " 卸载 Daed"
    echo "================================"
    echo ""

    uninstall_plugin "daed"
    uninstall_plugin "luci-app-daed"

    show_success
}

update_daed() {
    echo ""
    echo "================================"
    echo " 更新 Daed"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_daed
}
