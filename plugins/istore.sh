#!/bin/sh
# plugins/istore.sh - iStore 插件模块

install_istore() {
    echo ""
    echo "================================"
    echo " 安装 iStore"
    echo "================================"
    echo ""

    echo "[更新] 更新软件源索引..."
    apk update 2>/dev/null || opkg update 2>/dev/null || {
        echo "[错误] 软件源更新失败"
        return 1
    }

    local run_url="https://github.com/linkease/openwrt-app-actions/raw/main/applications/luci-app-systools/root/usr/share/systools/istore-reinstall.run"
    local run_file="/tmp/istore-reinstall.run"

    echo "[下载] 下载 iStore 安装脚本..."
    if ! download_file "$run_url" "$run_file"; then
        echo "[错误] 下载失败"
        return 1
    fi

    if [ ! -s "$run_file" ]; then
        echo "[错误] 下载文件为空"
        rm -f "$run_file"
        return 1
    fi

    chmod 755 "$run_file"

    echo "[安装] 正在运行安装脚本..."
    if ! sh "$run_file"; then
        echo "[错误] iStore 安装失败"
        rm -f "$run_file"
        return 1
    fi

    rm -f "$run_file"

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_istore() {
    echo ""
    echo "================================"
    echo " 卸载 iStore"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-store"
    uninstall_plugin "istore"

    show_success
}

update_istore() {
    echo ""
    echo "================================"
    echo " 更新 iStore"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_istore
}
