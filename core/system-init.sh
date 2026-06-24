#!/bin/sh
# core/system-init.sh - 基础初始化（时区/中文界面/SFTP/常用下载工具）
# 调用方式: system_init

system_init() {
    echo ""
    echo "================================"
    echo " 基础初始化"
    echo "  时区 / 中文界面 / SFTP / 工具"
    echo "================================"
    echo ""

    # 前置检查
    [ "$(id -u)" = "0" ] || { echo "[错误] 请使用 root 用户执行"; return 1; }

    local pkg_mgr=""
    command -v apk >/dev/null 2>&1 && pkg_mgr="apk"
    command -v opkg >/dev/null 2>&1 && pkg_mgr="opkg"
    [ -n "$pkg_mgr" ] || { echo "[错误] 不支持的系统"; return 1; }

    # 1. 设置时区
    echo "[1/5] 设置时区 Asia/Shanghai"
    if command -v uci >/dev/null 2>&1; then
        uci -q set system.@system[0].zonename='Asia/Shanghai' || true
        uci -q set system.@system[0].timezone='CST-8' || true
        uci -q commit system || echo "  [警告] 保存失败"
        [ -x /etc/init.d/system ]  && /etc/init.d/system reload  >/dev/null 2>&1 || true
        [ -x /etc/init.d/sysntpd ] && /etc/init.d/sysntpd restart >/dev/null 2>&1 || true
        echo "  [完成]"
    else
        echo "  [跳过] uci 不可用"
    fi
    echo ""

    # 2. 恢复 wget（apk 环境适配）
    echo "[2/5] 修复 wget 环境"
    if [ "$pkg_mgr" = "apk" ]; then
        apk del wget wget-nossl wget-ssl >/dev/null 2>&1 || true
        local src=""
        [ -x /bin/uclient-fetch ]   && src="/bin/uclient-fetch"
        [ -x /usr/bin/uclient-fetch ] && src="/usr/bin/uclient-fetch"
        [ -x /bin/busybox ] && /bin/busybox wget --help >/dev/null 2>&1 && src="/bin/busybox"
        if [ -n "$src" ]; then
            mkdir -p /usr/bin
            ln -sf "$src" /usr/bin/wget
            echo "  [完成] wget -> $src"
        else
            echo "  [警告] 未找到 uclient-fetch/busybox wget"
        fi
    else
        echo "  [跳过] 非 apk 环境"
    fi
    echo ""

    # 3. 更新包索引
    echo "[3/5] 更新包索引"
    if [ "$pkg_mgr" = "apk" ]; then
        apk update >/dev/null 2>&1 && echo "  [完成]" || echo "  [警告] 失败"
    else
        opkg update >/dev/null 2>&1 && echo "  [完成]" || echo "  [警告] 失败"
    fi
    echo ""

    # 4. 安装基础包
    echo "[4/5] 安装基础包"
    for pkg in ca-bundle curl openssh-sftp-server luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn; do
        printf "  %s ... " "$pkg"
        if [ "$pkg_mgr" = "apk" ]; then
            if apk info -e "$pkg" >/dev/null 2>&1; then
                echo "已安装"
            elif apk add "$pkg" >/dev/null 2>&1; then
                echo "成功"
            else
                echo "失败"
            fi
        else
            if opkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
                echo "已安装"
            elif opkg install "$pkg" >/dev/null 2>&1; then
                echo "成功"
            else
                echo "失败"
            fi
        fi
    done
    echo ""

    # 5. 重启服务 + 刷新 LuCI
    echo "[5/5] 重启服务"
    [ -x /etc/init.d/dropbear ] && /etc/init.d/dropbear restart >/dev/null 2>&1 || true
    echo "  dropbear 已重启（SFTP 可用）"
    if command -v restart_luci >/dev/null 2>&1; then
        restart_luci
    else
        rm -rf /tmp/luci-* /tmp/.luci* /var/run/luci-indexcache 2>/dev/null || true
        [ -x /etc/init.d/rpcd ]   && /etc/init.d/rpcd restart   >/dev/null 2>&1 || true
        [ -f /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
        [ -f /etc/init.d/nginx ]  && /etc/init.d/nginx restart  >/dev/null 2>&1 || true
    fi

    echo ""
    echo "================================"
    echo " 基础初始化完成"
    echo "================================"
}
