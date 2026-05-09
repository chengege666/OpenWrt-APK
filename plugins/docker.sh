#!/bin/sh
# plugins/docker.sh - Docker 插件模块

install_docker() {
    echo ""
    echo "================================"
    echo " 安装 Docker"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    echo "[安装] Docker 为官方 APK 包，直接从软件源安装..."

    echo "[更新] 更新软件源索引..."
    apk update 2>/dev/null

    echo "[安装] 安装 Docker 核心..."
    apk add --allow-untrusted docker dockerd 2>/dev/null

    echo "[安装] 安装 LuCI 管理界面..."
    apk add --allow-untrusted luci-app-dockerman luci-i18n-dockerman-zh-cn 2>/dev/null

    echo "[配置] 配置 Docker..."
    if [ ! -f /etc/config/dockerd ]; then
        uci set dockerd.globals='globals' 2>/dev/null
        uci set dockerd.globals.data_root='/opt/docker' 2>/dev/null
        uci commit dockerd 2>/dev/null
    fi

    echo "[启用] 启用 dockerd 服务..."
    if [ -f /etc/init.d/dockerd ]; then
        /etc/init.d/dockerd enable 2>/dev/null
        /etc/init.d/dockerd start 2>/dev/null
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_docker() {
    echo ""
    echo "================================"
    echo " 卸载 Docker"
    echo "================================"
    echo ""

    echo "[停止] 停止 dockerd 服务..."
    if [ -f /etc/init.d/dockerd ]; then
        /etc/init.d/dockerd stop 2>/dev/null
        /etc/init.d/dockerd disable 2>/dev/null
    fi

    uninstall_plugin "luci-app-dockerman"
    uninstall_plugin "docker"
    uninstall_plugin "dockerd"
    uninstall_plugin "luci-i18n-dockerman-zh-cn"

    show_success
}

update_docker() {
    echo ""
    echo "================================"
    echo " 更新 Docker"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_docker
}
