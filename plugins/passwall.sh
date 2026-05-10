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

    echo "[步骤 1/3] 尝试从系统软件源安装..."
    if [ "$is_apk" -eq 1 ]; then
        apk update 2>/dev/null
        if apk add --allow-untrusted luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null; then
            echo "[成功] 从软件源安装完成"
            fix_dependencies
            restart_luci
            show_success
            return
        else
            echo "[警告] 软件源安装失败，尝试从 GitHub 下载..."
        fi
    else
        opkg update 2>/dev/null
        if opkg install luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null; then
            echo "[成功] 从软件源安装完成"
            fix_dependencies
            restart_luci
            show_success
            return
        else
            echo "[警告] 软件源安装失败，尝试从 GitHub 下载..."
        fi
    fi

    install_passwall_github "$is_apk" || {
        echo "[错误] PassWall 安装失败"
        show_passwall_manual
        return 1
    }

    echo "[成功] PassWall 安装完成"
    fix_dependencies
    restart_luci
    show_success
}

install_passwall_github() {
    local is_apk="$1"
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
    local main_url="${base_url}/luci-app-passwall_${tag#v}_all.${pkg_ext}"
    local i18n_url="${base_url}/luci-i18n-passwall-zh-cn_${tag#v}_all.${pkg_ext}"

    local download_dir="${CACHE_DIR}/passwall"
    mkdir -p "$download_dir"

    echo "[下载] 主包..."
    if wget -q --timeout=120 -O "${download_dir}/passwall-main.pkg" "$main_url" 2>/dev/null; then
        if [ -f "${download_dir}/passwall-main.pkg" ] && [ -s "${download_dir}/passwall-main.pkg" ]; then
            echo "[成功] 主包下载完成"
        else
            echo "[错误] 主包下载文件为空"
            rm -f "${download_dir}/passwall-main.pkg"
            return 1
        fi
    else
        echo "[错误] 主包下载失败"
        rm -f "${download_dir}/passwall-main.pkg"
        return 1
    fi

    echo "[下载] 中文包..."
    if wget -q --timeout=60 -O "${download_dir}/passwall-i18n.pkg" "$i18n_url" 2>/dev/null; then
        if [ -f "${download_dir}/passwall-i18n.pkg" ] && [ -s "${download_dir}/passwall-i18n.pkg" ]; then
            echo "[成功] 中文包下载完成"
        else
            echo "[警告] 中文包下载失败，将只安装主包"
            rm -f "${download_dir}/passwall-i18n.pkg"
            i18n_url=""
        fi
    else
        echo "[警告] 中文包下载失败，将只安装主包"
        rm -f "${download_dir}/passwall-i18n.pkg"
        i18n_url=""
    fi

    echo "[安装] 正在安装 PassWall..."
    if [ "$is_apk" -eq 1 ]; then
        if [ -n "$i18n_url" ]; then
            apk add --allow-untrusted --force-overwrite "${download_dir}/passwall-main.pkg" "${download_dir}/passwall-i18n.pkg" 2>/dev/null || return 1
        else
            apk add --allow-untrusted --force-overwrite "${download_dir}/passwall-main.pkg" 2>/dev/null || return 1
        fi
    else
        if [ -n "$i18n_url" ]; then
            opkg install --force-overwrite "${download_dir}/passwall-main.pkg" "${download_dir}/passwall-i18n.pkg" 2>/dev/null || return 1
        else
            opkg install --force-overwrite "${download_dir}/passwall-main.pkg" 2>/dev/null || return 1
        fi
    fi

    echo "[成功] PassWall 安装完成"
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
