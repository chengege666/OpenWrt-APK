#!/bin/sh
# plugins/daed.sh - Daed 插件模块（基于 eBPF 的高性能透明代理）

install_daed_deps() {
    echo "[依赖] 检查 Daed 运行依赖..."

    local common_pkgs="ca-bundle kmod-sched-core kmod-sched-bpf kmod-xdp-sockets-diag kmod-veth"

    echo "[依赖] 安装内核模块依赖..."
    if command -v apk >/dev/null 2>&1; then
        for pkg in $common_pkgs; do
            apk add --allow-untrusted "$pkg" 2>/dev/null && echo "[依赖] $pkg 安装成功" || echo "[警告] $pkg 安装失败（可能内核不支持）"
        done
        apk add --allow-untrusted v2ray-geoip v2ray-geosite 2>/dev/null && echo "[依赖] GeoIP/GeoSite 数据安装成功" || echo "[警告] GeoIP/GeoSite 数据安装失败"
    else
        for pkg in $common_pkgs; do
            opkg install "$pkg" 2>/dev/null && echo "[依赖] $pkg 安装成功" || echo "[警告] $pkg 安装失败（可能内核不支持）"
        done
        opkg install v2ray-geoip v2ray-geosite 2>/dev/null && echo "[依赖] GeoIP/GeoSite 数据安装成功" || echo "[警告] GeoIP/GeoSite 数据安装失败"
    fi

    echo "[依赖] 依赖检查完成"
}

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

    # 先装依赖
    install_daed_deps

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

    # 查找 daed 核心包
    local daed_url
    daed_url=$(echo "$all_urls" | grep -E "/daed[-_][^/]+${daed_arch}[^/]*\.${pkg_ext}$" | head -1)

    if [ -z "$daed_url" ]; then
        echo "[重试] 尝试模糊匹配架构..."
        local base_arch="${daed_arch%_generic}"
        daed_url=$(echo "$all_urls" | grep -E "/daed[-_][^/]+${base_arch}[^/]*\.${pkg_ext}$" | head -1)
    fi

    if [ -z "$daed_url" ]; then
        echo "[错误] 未找到 ${arch} 架构的 Daed 核心包"
        return 1
    fi

    # 查找 luci-app-daed 界面包
    local luci_url
    luci_url=$(echo "$all_urls" | grep -E "/luci-app-daed[-_][^/]*\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-daed 界面包"
        return 1
    fi

    # 查找中文包
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep -E "/luci-i18n-daed-zh-cn[-_][^/]*\.${pkg_ext}$" | head -1)

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

    if [ -n "$i18n_url" ]; then
        local i18n_name
        i18n_name=$(basename "$i18n_url")
        download_file "$i18n_url" "${CACHE_DIR}/${plugin_name}/${i18n_name}" || echo "[警告] 中文包下载失败"
    fi

    echo "[安装] 正在安装 Daed 核心..."
    local install_ok=0
    if [ "$is_apk" -eq 1 ]; then
        if apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>/dev/null; then
            install_ok=1
        else
            echo "[重试] 尝试强制安装（忽略依赖）..."
            apk add --allow-untrusted --force-overwrite --force-broken-world "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>/dev/null && install_ok=1 || echo "[警告] 强制安装也失败"
        fi
    else
        if opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>/dev/null; then
            install_ok=1
        else
            echo "[重试] 尝试强制安装（忽略依赖）..."
            opkg install --force-overwrite --force-depends "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>/dev/null && install_ok=1 || echo "[警告] 强制安装也失败"
        fi
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] Daed 核心安装失败"
        echo "[提示] 可能原因："
        echo "  1. 内核未开启 eBPF 支持，请确认固件包含以下选项："
        echo "     - CONFIG_DEVEL=y"
        echo "     - CONFIG_KERNEL_DEBUG_INFO_BTF=y"
        echo "     - CONFIG_KERNEL_BPF_EVENTS=y"
        echo "     - CONFIG_KERNEL_CGROUP_BPF=y"
        echo "  2. 当前固件版本与 daed 不兼容"
        return 1
    fi
    echo "[成功] Daed 核心安装完成"

    echo "[安装] 正在安装 LuCI 界面..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${luci_name}" 2>/dev/null || {
            echo "[错误] LuCI 界面安装失败"
            return 1
        }
    else
        opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${luci_name}" 2>/dev/null || {
            echo "[错误] LuCI 界面安装失败"
            return 1
        }
    fi
    echo "[成功] LuCI 界面安装完成"

    # 安装中文包
    if [ -n "$i18n_url" ] && [ -f "${CACHE_DIR}/${plugin_name}/${i18n_name}" ]; then
        echo "[安装] 安装中文包..."
        if [ "$is_apk" -eq 1 ]; then
            apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${i18n_name}" 2>/dev/null && echo "[成功] 中文包安装完成" || echo "[警告] 中文包安装失败"
        else
            opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${i18n_name}" 2>/dev/null && echo "[成功] 中文包安装完成" || echo "[警告] 中文包安装失败"
        fi
    fi

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
    uninstall_plugin "luci-i18n-daed-zh-cn"

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
