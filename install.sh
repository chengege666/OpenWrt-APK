#!/bin/sh
# install.sh - 一键安装脚本
# 使用方式: wget -O- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh | sh

REPO_URL="https://github.com/chengege666/OpenWrt-APK"
RAW_URL="https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main"
INSTALL_DIR="/tmp/apk-store-installer"

echo "================================"
echo " OpenWrt APK Store 安装器"
echo "================================"
echo ""

if ! wget -q --spider --timeout=5 https://github.com 2>/dev/null; then
    echo "[错误] 网络连接失败"
    exit 1
fi

echo "[下载] 正在下载 OpenWrt APK Store..."

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "${INSTALL_DIR}/core"
mkdir -p "${INSTALL_DIR}/plugins"

download_file() {
    local url="$1"
    local output="$2"
    if wget -q --timeout=30 -O "$output" "$url" 2>/dev/null; then
        if [ -f "$output" ] && [ -s "$output" ]; then
            return 0
        fi
    fi
    return 1
}

download_file "${RAW_URL}/store.sh" "${INSTALL_DIR}/store.sh" && echo "[下载] store.sh" || { echo "[错误] store.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/core/network.sh" "${INSTALL_DIR}/core/network.sh" && echo "[下载] core/network.sh" || { echo "[错误] core/network.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/core/github.sh" "${INSTALL_DIR}/core/github.sh" && echo "[下载] core/github.sh" || { echo "[错误] core/github.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/core/install.sh" "${INSTALL_DIR}/core/install.sh" && echo "[下载] core/install.sh" || { echo "[错误] core/install.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/core/ui.sh" "${INSTALL_DIR}/core/ui.sh" && echo "[下载] core/ui.sh" || { echo "[错误] core/ui.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/openclash.sh" "${INSTALL_DIR}/plugins/openclash.sh" && echo "[下载] plugins/openclash.sh" || { echo "[错误] plugins/openclash.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/passwall.sh" "${INSTALL_DIR}/plugins/passwall.sh" && echo "[下载] plugins/passwall.sh" || { echo "[错误] plugins/passwall.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/mosdns.sh" "${INSTALL_DIR}/plugins/mosdns.sh" && echo "[下载] plugins/mosdns.sh" || { echo "[错误] plugins/mosdns.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/adguardhome.sh" "${INSTALL_DIR}/plugins/adguardhome.sh" && echo "[下载] plugins/adguardhome.sh" || { echo "[错误] plugins/adguardhome.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/docker.sh" "${INSTALL_DIR}/plugins/docker.sh" && echo "[下载] plugins/docker.sh" || { echo "[错误] plugins/docker.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/ddns.sh" "${INSTALL_DIR}/plugins/ddns.sh" && echo "[下载] plugins/ddns.sh" || { echo "[错误] plugins/ddns.sh 下载失败"; exit 1; }
download_file "${RAW_URL}/plugins/tailscale.sh" "${INSTALL_DIR}/plugins/tailscale.sh" && echo "[下载] plugins/tailscale.sh" || { echo "[错误] plugins/tailscale.sh 下载失败"; exit 1; }

chmod +x "${INSTALL_DIR}/store.sh"
echo ""
echo "[成功] 下载完成"
echo ""
echo "[启动] OpenWrt APK Store..."
echo ""
sh "${INSTALL_DIR}/store.sh"
