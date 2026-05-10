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

    local install_ok=1
    if [ "$is_apk" -eq 1 ]; then
        apk update 2>/dev/null
        apk add --allow-untrusted luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null && install_ok=0
    else
        opkg update 2>/dev/null
        opkg install luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null && install_ok=0
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[成功] PassWall 安装完成"
        fix_dependencies
        restart_luci
        show_success
        return
    fi

    echo "[重试] 系统软件源中未找到，添加 passwall-build 软件源..."

    local pw_arch
    pw_arch=$(echo "$DISTRIB_ARCH" | tr -d ' \n')

    local base_url
    case "$release_ver" in
        25.*|snapshot)
            base_url="https://master.dl.sourceforge.net/project/openwrt-passwall-build/snapshots/packages/${pw_arch}"
            ;;
        *)
            base_url="https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-${release_ver}/${pw_arch}"
            ;;
    esac

    local feed_added=0
    for feed in passwall_luci passwall_packages; do
        if wget -q --spider --timeout=10 "${base_url}/${feed}/Packages.gz" 2>/dev/null; then
            echo "添加: $feed"
            echo "src/gz $feed ${base_url}/${feed}" >> /etc/opkg/customfeeds.conf 2>/dev/null
            feed_added=1
        fi
    done

    if [ "$feed_added" -eq 0 ]; then
        echo "[提示] passwall-build 软件源不可用"
        echo ""
        echo "================================"
        echo " 手动安装 PassWall"
        echo "================================"
        echo ""
        echo "添加软件源后执行:"
        echo "  echo \"src/gz passwall_luci https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-${release_ver}/${pw_arch}/passwall_luci\" >> /etc/opkg/customfeeds.conf"
        echo "  echo \"src/gz passwall_packages https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-${release_ver}/${pw_arch}/passwall_packages\" >> /etc/opkg/customfeeds.conf"
        echo "  opkg update"
        echo "  opkg install luci-app-passwall"
        echo ""
        return 1
    fi

    install_ok=1
    if [ "$is_apk" -eq 1 ]; then
        apk update 2>/dev/null
        apk add --allow-untrusted luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null && install_ok=0
    else
        opkg update 2>/dev/null
        opkg install luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null && install_ok=0
    fi

    if [ "$install_ok" -ne 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[成功] PassWall 安装完成"
    fix_dependencies
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
