#!/bin/sh
# core/doctor.sh - 查看系统信息
# 调用方式: show_system_info

show_system_info() {
    echo ""
    echo "================================"
    echo " 系统信息"
    echo "================================"
    echo ""

    echo "--- OpenWrt 版本 ---"
    [ -f /etc/openwrt_release ] && cat /etc/openwrt_release || echo "(未找到)"
    echo ""

    echo "--- 系统架构 ---"
    echo "  架构: $(uname -m)"
    echo "  内核: $(uname -r)"
    echo ""

    echo "--- 包管理器 ---"
    if command -v apk >/dev/null 2>&1; then
        echo "  包管理器: apk"
        echo "  APK 架构: $(apk --print-arch 2>/dev/null || echo unknown)"
        echo "  已安装: $(apk list --installed 2>/dev/null | wc -l) 包"
    elif command -v opkg >/dev/null 2>&1; then
        echo "  包管理器: opkg"
        echo "  已安装: $(opkg list-installed 2>/dev/null | wc -l) 包"
    else
        echo "  包管理器: 未知"
    fi
    echo ""

    echo "--- 磁盘空间 ---"
    df -h 2>/dev/null || df
    echo ""

    echo "--- 内存信息 ---"
    free -h 2>/dev/null || free 2>/dev/null || cat /proc/meminfo 2>/dev/null | head -5 || echo "(不可用)"
    echo ""

    echo "--- 挂载状态 ---"
    mount | grep -E ' on /$| on /overlay | on /rom | on /tmp ' || echo "(无)"
    echo ""

    echo "--- overlay 使用率 ---"
    if mount | grep -q "overlayfs:/overlay on /"; then
        df /overlay 2>/dev/null | awk 'NR==2{printf "  总: %s  已用: %s  可用: %s  使用率: %s\n", $2, $3, $4, $5}'
    else
        df / 2>/dev/null | awk 'NR==2{printf "  总: %s  已用: %s  可用: %s  使用率: %s\n", $2, $3, $4, $5}'
    fi
    echo ""
}
