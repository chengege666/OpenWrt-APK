#!/bin/sh
# plugins/daed.sh - Daed 插件模块（基于 eBPF 的高性能透明代理）

install_daed() {
    echo ""
    echo "================================"
    echo " 安装 Daed"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    local pkg_ext="ipk"
    [ "$is_apk" -eq 1 ] && pkg_ext="apk"

    # 架构映射：detect_arch → release 命名
    local daed_arch
    case "$arch" in
        x86_64)    daed_arch="x86_64" ;;
        aarch64)   daed_arch="aarch64_generic" ;;
        *)
            echo "[错误] Daed 暂不支持 $arch 架构"
            echo "[提示] 目前支持的架构: x86_64, aarch64"
            return 1
            ;;
    esac

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

    # 查找 daed 核心包（匹配文件名以 daed 开头，不匹配路径中的 luci-app-daed）
    local daed_url
    daed_url=$(echo "$all_urls" | grep -E "/daed[-_][^/]+${daed_arch}[^/]*\.${pkg_ext}$" | head -1)

    # 如果精确匹配失败，尝试模糊匹配（去掉 _generic 后缀等）
    if [ -z "$daed_url" ]; then
        echo "[重试] 未找到 ${daed_arch} 的 ${pkg_ext} 包，尝试模糊匹配..."
        local base_arch="${daed_arch%_generic}"
        daed_url=$(echo "$all_urls" | grep -E "/daed[-_][^/]+${base_arch}[^/]*\.${pkg_ext}$" | head -1)
    fi

    if [ -z "$daed_url" ]; then
        echo "[错误] 未找到 ${arch} 架构的 Daed 核心包"
        echo "[调试] 架构: ${arch}, daed_arch: ${daed_arch}, 扩展: ${pkg_ext}"
        echo "[调试] 可用文件:"
        echo "$all_urls"
        return 1
    fi

    # 查找 luci-app-daed 界面包（匹配文件名以 luci-app-daed 开头）
    local luci_url
    luci_url=$(echo "$all_urls" | grep -E "/luci-app-daed[-_][^/]*\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-daed 界面包"
        return 1
    fi

    local daed_name
    daed_name=$(basename "$daed_url")

    local luci_name
    luci_name=$(basename "$luci_url")

    if ! download_file "$daed_url" "${CACHE_DIR}/${plugin_name}/${daed_name}"; then
        echo "[错误] Daed 核心下载失败"
        return 1
    fi

    if ! download_file "$luci_url" "${CACHE_DIR}/${plugin_name}/${luci_name}"; then
        echo "[错误] LuCI 界面下载失败"
        return 1
    fi

    echo "[安装] 正在安装 Daed 核心..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>&1 || {
            echo "[错误] Daed 核心安装失败"
            return 1
        }
    else
        opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>&1 || {
            echo "[错误] Daed 核心安装失败"
            return 1
        }
    fi
    echo "[成功] Daed 核心安装完成"

    echo "[安装] 正在安装 LuCI 界面..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${luci_name}" 2>&1 || {
            echo "[错误] LuCI 界面安装失败"
            return 1
        }
    else
        opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${luci_name}" 2>&1 || {
            echo "[错误] LuCI 界面安装失败"
            return 1
        }
    fi
    echo "[成功] LuCI 界面安装完成"

    echo "[修复] 修复依赖..."
    fix_dependencies

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

    uninstall_plugin "luci-app-daed"
    uninstall_plugin "daed"

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
