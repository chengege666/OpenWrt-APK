#!/bin/sh
# plugins/oxidns.sh - OxiDNS 插件模块

install_oxidns() {
    echo ""
    echo "================================"
    echo " 安装 OxiDNS"
    echo "================================"
    echo ""

    echo "[安装] 正在使用官方一键脚本进行安装..."
    if wget -O- https://oxidns.org/install.sh | sh; then
        echo "[成功] OxiDNS 安装完成"
        show_success
    else
        echo "[错误] OxiDNS 安装失败"
        return 1
    fi
}

uninstall_oxidns() {
    echo ""
    echo "================================"
    echo " 卸载 OxiDNS"
    echo "================================"
    echo ""

    echo "[卸载] 正在停止 OxiDNS 服务..."
    /etc/init.d/oxidns stop 2>/dev/null

    echo "[卸载] 正在移除相关包..."
    if command -v apk >/dev/null 2>&1; then
        apk del luci-app-oxidns luci-i18n-oxidns-zh-cn oxidns 2>/dev/null
    else
        opkg remove luci-app-oxidns luci-i18n-oxidns-zh-cn oxidns 2>/dev/null
    fi

    echo "[清理] 清理残留文件..."
    rm -rf /usr/share/oxidns/webui 2>/dev/null
    rm -f /usr/bin/oxidns 2>/dev/null

    echo "[提示] 配置文件 /etc/oxidns/config.yaml 和工作目录 /var/lib/oxidns 已保留，若需彻底清理请手动删除。"

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] OxiDNS 卸载完成"
}

update_oxidns() {
    echo ""
    echo "================================"
    echo " 更新 OxiDNS"
    echo "================================"
    echo ""

    echo "[更新] 正在使用官方一键脚本进行更新..."
    if wget -O- https://oxidns.org/install.sh | sh; then
        echo "[成功] OxiDNS 更新完成"
        show_success
    else
        echo "[错误] OxiDNS 更新失败"
        return 1
    fi
}
