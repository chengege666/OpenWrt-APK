#!/bin/sh
# plugins/passwall.sh - PassWall 插件模块

install_passwall() {
    echo ""
    echo "================================"
    echo " 安装 PassWall"
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

    local ver_tag
    if [ "$is_apk" -eq 1 ]; then
        ver_tag="25.12+"
    elif [ "$release_ver" = "22.03" ] || [ "$release_ver" = "21.02" ]; then
        ver_tag="22.03-"
    else
        ver_tag="23.05-24.10"
    fi
    echo "[系统] OpenWrt $release_ver ($ver_tag)"

    local owner="Openwrt-Passwall"
    local repo="openwrt-passwall"
    local plugin_name="passwall"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    echo "[步骤 1/2] 下载 PassWall LuCI 界面..."
    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local luci_url
    luci_url=$(echo "$all_urls" | grep "${ver_tag}" | grep "luci-app-passwall" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[重试] 未找到匹配版本，尝试通用匹配..."
        luci_url=$(echo "$all_urls" | grep "luci-app-passwall" | grep "\.${pkg_ext}$" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        luci_url=$(echo "$all_urls" | grep "luci-app-passwall" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-passwall 安装包"
        return 1
    fi

    echo "[下载] $luci_url"
    local luci_name
    luci_name=$(basename "$luci_url")
    if ! wget -q --timeout=120 -O "${download_dir}/${luci_name}" "$luci_url" 2>/dev/null; then
        echo "[错误] 下载失败: $luci_name"
        rm -f "${download_dir}/${luci_name}"
        return 1
    fi

    if [ ! -s "${download_dir}/${luci_name}" ]; then
        echo "[错误] 下载文件为空"
        rm -f "${download_dir}/${luci_name}"
        return 1
    fi
    echo "[成功] LuCI 下载完成"

    echo "[步骤 2/2] 下载 PassWall 中文语言包..."
    local i18n_name=""
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "${ver_tag}" | grep "luci-i18n-passwall-zh-cn" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$i18n_url" ]; then
        echo "[重试] 未找到匹配版本中文包，尝试通用匹配..."
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-passwall-zh-cn" | grep "\.${pkg_ext}$" | head -1)
    fi

    if [ -n "$i18n_url" ]; then
        i18n_name=$(basename "$i18n_url")
        echo "[下载] $i18n_name"
        if ! wget -q --timeout=60 -O "${download_dir}/${i18n_name}" "$i18n_url" 2>/dev/null; then
            echo "[警告] 中文包下载失败，继续安装..."
            i18n_name=""
        elif [ ! -s "${download_dir}/${i18n_name}" ]; then
            echo "[警告] 中文包文件为空，继续安装..."
            rm -f "${download_dir}/${i18n_name}"
            i18n_name=""
        else
            echo "[成功] 中文包下载完成"
        fi
    else
        echo "[提示] 未找到中文语言包，将只安装主程序"
    fi

    echo "[安装] 安装 PassWall..."
    local install_ok=0

    if [ "$is_apk" -eq 1 ]; then
        echo "[安装] 安装 LuCI 主程序..."
        if apk add --allow-untrusted "${download_dir}/${luci_name}" 2>/dev/null; then
            install_ok=1
        fi

        if [ -n "$i18n_name" ] && [ -f "${download_dir}/${i18n_name}" ]; then
            echo "[安装] 安装中文包..."
            apk add --allow-untrusted "${download_dir}/${i18n_name}" 2>/dev/null
        fi
    else
        echo "[安装] 安装 LuCI 主程序..."
        if opkg install --force-overwrite "${download_dir}/${luci_name}" 2>/dev/null; then
            install_ok=1
        fi

        if [ -n "$i18n_name" ] && [ -f "${download_dir}/${i18n_name}" ]; then
            echo "[安装] 安装中文包..."
            opkg install --force-overwrite "${download_dir}/${i18n_name}" 2>/dev/null
        fi
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[成功] PassWall 安装完成"

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_passwall() {
    echo ""
    echo "================================"
    echo " 卸载 PassWall"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-passwall"
    uninstall_plugin "luci-i18n-passwall-zh-cn"

    show_success
}

update_passwall() {
    echo ""
    echo "================================"
    echo " 更新 PassWall"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_passwall
}
