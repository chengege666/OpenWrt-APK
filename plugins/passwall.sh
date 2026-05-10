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

    if [ "$is_apk" -eq 1 ]; then
        echo "[步骤 2/3] 从 GitHub 下载 APK 安装..."
        install_passwall_apk
        return $?
    fi

    echo "[步骤 2/3] 添加 passwall-build 第三方软件源..."
    local pw_arch
    pw_arch=$(echo "$DISTRIB_ARCH" | tr -d ' \n')
    local base_url="https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-${release_ver}/${pw_arch}"

    for feed in passwall_luci passwall_packages; do
        echo "src/gz $feed ${base_url}/${feed}" >> /etc/opkg/customfeeds.conf 2>/dev/null
    done

    echo "[步骤 3/3] 安装 PassWall..."
    opkg update 2>/dev/null
    opkg install luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "[错误] 安装失败"
        echo ""
        echo "手动安装:"
        echo "  opkg update"
        echo "  opkg install luci-app-passwall"
        echo ""
        return 1
    fi

    echo "[成功] PassWall 安装完成"
    fix_dependencies
    restart_luci
    show_success
}

install_passwall_apk() {
    local owner="Openwrt-Passwall"
    local repo="openwrt-passwall"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || {
        echo "[错误] 无法获取 PassWall 版本信息"
        show_passwall_manual
        return 1
    }

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local luci_url
    luci_url=$(echo "$all_urls" | grep "luci-app-passwall.*\.apk$" | head -1)

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-passwall-zh-cn.*\.apk$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 APK 安装包"
        show_passwall_manual
        return 1
    fi

    local download_dir="${CACHE_DIR}/passwall"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    echo "[下载] luci-app-passwall.apk"
    if ! wget -q --timeout=60 -O "${download_dir}/luci-app-passwall.apk" "$luci_url" 2>/dev/null; then
        echo "[错误] 下载失败"
        show_passwall_manual
        return 1
    fi

    if [ -n "$i18n_url" ]; then
        echo "[下载] luci-i18n-passwall-zh-cn.apk"
        wget -q --timeout=60 -O "${download_dir}/luci-i18n-passwall-zh-cn.apk" "$i18n_url" 2>/dev/null
    fi

    echo "[依赖] 安装核心运行依赖..."
    apk add --allow-untrusted xray-core chinadns-ng ipt2socks dns2socks 2>&1 | grep -v "^$"

    echo "[安装] 安装 PassWall 管理界面..."
    cd "$download_dir" || return 1
    local apk_output
    apk_output=$(apk add --allow-untrusted --force-overwrite --force-depends --force-non-repository *.apk 2>&1)
    local ret=$?
    echo "$apk_output"

    if [ "$ret" -eq 0 ]; then
        echo "[成功] PassWall 安装完成"
        echo "[提示] 如需补全依赖: apk add --allow-untrusted xray-core sing-box chinadns-ng"
        fix_dependencies
        restart_luci
        show_success
        return 0
    fi

    echo "[错误] PassWall 安装失败"
    show_passwall_manual
    return 1
}

show_passwall_manual() {
    echo ""
    echo "================================"
    echo " 手动安装 PassWall"
    echo "================================"
    echo ""
    echo "方法一: 添加 passwall-build 软件源"
    echo "  . /etc/openwrt_release"
    echo "  pw_arch=\$(echo \$DISTRIB_ARCH | tr -d ' \n')"
    echo "  pw_ver=\$(echo \$DISTRIB_RELEASE | cut -d'.' -f1,2)"
    echo "  echo \"src/gz passwall_luci https://master.dl.sourceforge.net/project/openwrt-passwall-build/snapshots/packages/\${pw_arch}/passwall_luci\" >> /etc/opkg/customfeeds.conf"
    echo "  echo \"src/gz passwall_packages https://master.dl.sourceforge.net/project/openwrt-passwall-build/snapshots/packages/\${pw_arch}/passwall_packages\" >> /etc/opkg/customfeeds.conf"
    echo "  opkg update"
    echo "  opkg install luci-app-passwall luci-i18n-passwall-zh-cn"
    echo ""
    echo "方法二: 直接安装 GitHub 下载的 APK（需要先安装依赖）"
    echo "  apk add --allow-untrusted --force-overwrite luci-app-passwall*.apk"
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
