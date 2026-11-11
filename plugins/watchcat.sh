#!/bin/sh
# plugins/watchcat.sh - WatchCat 看门狗/重启守护插件模块
# 来源: OpenWrt 官方源（packages / luci feed），无需第三方仓库

install_watchcat() {
    echo ""
    echo "================================"
    echo " 安装 WatchCat"
    echo "================================"
    echo ""

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    echo "[系统] OpenWrt $DISTRIB_RELEASE ($([ "$is_apk" -eq 1 ] && echo 'APK' || echo 'OPKG'))"

    echo "[步骤 1/2] 安装 WatchCat 核心..."
    local core_ok=0
    if [ "$is_apk" -eq 1 ]; then
        if apk add watchcat 2>/dev/null; then
            echo "[成功] watchcat 核心安装完成"
            core_ok=1
        else
            echo "[错误] 软件源中未找到 watchcat 包"
        fi
    else
        opkg update 2>/dev/null
        if opkg install watchcat 2>/dev/null; then
            echo "[成功] watchcat 核心安装完成"
            core_ok=1
        else
            echo "[错误] 软件源中未找到 watchcat 包"
        fi
    fi

    if [ "$core_ok" -eq 0 ]; then
        echo "[提示] 请先在 软件源修改(9) 中切换可用源并更新后重试"
        return 1
    fi

    echo "[步骤 2/2] 安装 LuCI 界面及中文包..."
    local luci_ok=0
    if [ "$is_apk" -eq 1 ]; then
        apk add luci-app-watchcat 2>/dev/null && echo "[成功] luci-app-watchcat 安装完成" && luci_ok=1 || \
            echo "[提示] 软件源中未提供 luci-app-watchcat"
        apk add luci-i18n-watchcat-zh-cn 2>/dev/null && echo "[成功] luci-i18n-watchcat-zh-cn 安装完成" || \
            echo "[提示] 软件源中未提供 luci-i18n-watchcat-zh-cn"
    else
        opkg install luci-app-watchcat 2>/dev/null && echo "[成功] luci-app-watchcat 安装完成" && luci_ok=1 || \
            echo "[提示] 软件源中未提供 luci-app-watchcat"
        opkg install luci-i18n-watchcat-zh-cn 2>/dev/null && echo "[成功] luci-i18n-watchcat-zh-cn 安装完成" || \
            echo "[提示] 软件源中未提供 luci-i18n-watchcat-zh-cn"
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success

    if [ "$luci_ok" -eq 0 ]; then
        echo "[提示] 未安装 LuCI 前端，可使用命令行配置 /etc/config/watchcat"
        echo "       或手动从第三方仓库获取 luci-app-watchcat 前端"
    fi
    return 0
}

uninstall_watchcat() {
    echo ""
    echo "================================"
    echo " 卸载 WatchCat"
    echo "================================"
    echo ""

    # 停止并禁用 watchcat 服务
    if [ -x /etc/init.d/watchcat ]; then
        echo "[停止] 停止 WatchCat 服务..."
        /etc/init.d/watchcat stop 2>/dev/null || true
        /etc/init.d/watchcat disable 2>/dev/null || true
    fi

    # 通过包管理器卸载（核心 + LuCI 前端 + 中文包）
    uninstall_plugin "watchcat"

    # 清理 LuCI 残留（保留 /etc/config/watchcat 用户配置）
    rm -rf /usr/share/luci/menu.d/*watchcat* 2>/dev/null
    rm -rf /usr/share/rpcd/acl.d/*watchcat* 2>/dev/null
    rm -rf /www/luci-static/resources/*watchcat* 2>/dev/null

    echo "[提示] 已保留 /etc/config/watchcat 配置（如需彻底清理请手动删除）"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_watchcat() {
    echo ""
    echo "================================"
    echo " 更新 WatchCat"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_watchcat
}
