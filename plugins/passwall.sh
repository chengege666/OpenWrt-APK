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
    echo "[系统] $DISTRIB_RELEASE"

    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    echo "[步骤 1/4] 安装依赖..."
    install_passwall_deps "$is_apk" || {
        echo "[错误] 依赖安装失败"
        return 1
    }

    echo "[步骤 2/4] 安装主程序..."
    install_passwall_main "$is_apk" || {
        echo "[错误] 主程序安装失败"
        return 1
    }

    echo "[步骤 3/4] 安装中文语言包..."
    install_passwall_i18n "$is_apk" || {
        echo "[警告] 中文语言包安装失败，主程序已安装"
    }

    echo "[步骤 4/4] 配置完成..."
    fix_dependencies
    restart_luci

    echo "[成功] PassWall 安装完成"
    show_success
}

install_passwall_deps() {
    local is_apk="$1"

    echo "[依赖] 安装 PassWall 运行依赖..."

    local deps="dnsmasq-full curl ca-bundle ip-full iptables iptables-mod-tproxy iptables-mod-extra iptables-mod-nat-extra iptables-mod-iprange iptables-mod-conntrack-extra"

    if [ "$is_apk" -eq 1 ]; then
        apk update 2>/dev/null
        for dep in $deps; do
            echo "[依赖] 安装: $dep"
            apk add --allow-untrusted "$dep" 2>/dev/null || echo "[警告] $dep 安装失败"
        done
    else
        opkg update 2>/dev/null
        for dep in $deps; do
            echo "[依赖] 安装: $dep"
            opkg install "$dep" 2>/dev/null || echo "[警告] $dep 安装失败"
        done
    fi

    echo "[成功] 依赖安装完成"
}

install_passwall_main() {
    local is_apk="$1"

    echo "[主程序] 尝试从软件源安装..."
    if [ "$is_apk" -eq 1 ]; then
        if apk add --allow-untrusted luci-app-passwall 2>/dev/null; then
            echo "[成功] 从软件源安装主程序完成"
            return 0
        fi
    else
        if opkg install luci-app-passwall 2>/dev/null; then
            echo "[成功] 从软件源安装主程序完成"
            return 0
        fi
    fi

    echo "[警告] 软件源安装失败，从 GitHub 下载..."
    install_passwall_from_github "$is_apk" "main" || return 1
}

install_passwall_i18n() {
    local is_apk="$1"

    echo "[语言包] 尝试从软件源安装..."
    if [ "$is_apk" -eq 1 ]; then
        if apk add --allow-untrusted luci-i18n-passwall-zh-cn 2>/dev/null; then
            echo "[成功] 从软件源安装中文语言包完成"
            return 0
        fi
    else
        if opkg install luci-i18n-passwall-zh-cn 2>/dev/null; then
            echo "[成功] 从软件源安装中文语言包完成"
            return 0
        fi
    fi

    echo "[警告] 软件源安装失败，从 GitHub 下载..."
    install_passwall_from_github "$is_apk" "i18n" || return 1
}

install_passwall_from_github() {
    local is_apk="$1"
    local pkg_type="$2"
    local owner="Openwrt-Passwall"
    local repo="openwrt-passwall"

    echo "[下载] 正在获取最新版本..."
    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || {
        echo "[警告] GitHub API 不可用，尝试直接下载..."
        release_json=""
    }

    local tag=""
    if [ -n "$release_json" ]; then
        tag=$(get_release_tag "$release_json")
    fi

    if [ -z "$tag" ]; then
        echo "[提示] 使用默认版本 v5.0-1"
        tag="v5.0-1"
    fi
    echo "[版本] $tag"

    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local base_url="https://github.com/${owner}/${repo}/releases/download/${tag}"
    local download_url=""
    local pkg_name=""

    if [ "$pkg_type" = "main" ]; then
        download_url="${base_url}/luci-app-passwall_${tag#v}_all.${pkg_ext}"
        pkg_name="passwall-main.pkg"
    else
        download_url="${base_url}/luci-i18n-passwall-zh-cn_${tag#v}_all.${pkg_ext}"
        pkg_name="passwall-i18n.pkg"
    fi

    local download_dir="${CACHE_DIR}/passwall"
    mkdir -p "$download_dir"

    echo "[下载] $download_url"
    if wget -q --timeout=120 -O "${download_dir}/${pkg_name}" "$download_url" 2>/dev/null; then
        if [ -f "${download_dir}/${pkg_name}" ] && [ -s "${download_dir}/${pkg_name}" ]; then
            echo "[成功] 下载完成"
        else
            echo "[错误] 下载文件为空"
            rm -f "${download_dir}/${pkg_name}"
            return 1
        fi
    else
        echo "[错误] 下载失败"
        rm -f "${download_dir}/${pkg_name}"
        return 1
    fi

    echo "[安装] 正在安装..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite "${download_dir}/${pkg_name}" 2>/dev/null || return 1
    else
        opkg install --force-overwrite "${download_dir}/${pkg_name}" 2>/dev/null || return 1
    fi

    echo "[成功] 安装完成"
}

show_passwall_manual() {
    echo ""
    echo "================================"
    echo " 手动安装 PassWall"
    echo "================================"
    echo ""
    echo "方法一: 从 GitHub 下载 APK/IPK 安装"
    echo "  访问: https://github.com/Openwrt-Passwall/openwrt-passwall/releases"
    echo "  下载对应架构的 luci-app-passwall 包"
    echo "  apk add --allow-untrusted luci-app-passwall*.apk"
    echo ""
    echo "方法二: 添加第三方软件源 (opkg 系统)"
    echo "  . /etc/openwrt_release"
    echo "  pw_arch=\$(echo \$DISTRIB_ARCH | tr -d ' \n')"
    echo "  pw_ver=\$(echo \$DISTRIB_RELEASE | cut -d'.' -f1,2)"
    echo "  echo \"src/gz passwall_luci https://master.dl.sourceforge.net/project/openwrt-passwall-build/snapshots/packages/\${pw_arch}/passwall_luci\" >> /etc/opkg/customfeeds.conf"
    echo "  opkg update && opkg install luci-app-passwall"
    echo ""
    wait_for_enter
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
