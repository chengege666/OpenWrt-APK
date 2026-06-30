#!/bin/sh
# install.sh - 一键安装脚本
#
# SPDX-FileCopyrightText: 2025 ChenGege
#
# SPDX-License-Identifier: GPL-3.0-only
#
# OpenWrt APK Store is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# OpenWrt APK Store is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OpenWrt APK Store. If not, see <https://www.gnu.org/licenses/>.
#
# 使用方式: wget -O- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh | sh

REPO_URL="https://github.com/chengege666/OpenWrt-APK"
INSTALL_DIR="/root/apk-store"

echo "================================"
echo " OpenWrt APK安装脚本 （CGG） 安装器"
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

TMP_DIR="/tmp/apk-store-install"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "[下载] 正在下载仓库压缩包..."
if ! wget -q --timeout=60 -O "${TMP_DIR}/repo.zip" "${REPO_URL}/archive/main.zip" 2>/dev/null; then
    echo "[错误] 仓库下载失败"
    exit 1
fi

echo "[解压] 正在解压..."
if ! unzip -o -q "${TMP_DIR}/repo.zip" -d "$TMP_DIR" 2>/dev/null; then
    echo "[错误] 解压失败"
    exit 1
fi

SRC_DIR="${TMP_DIR}/OpenWrt-APK-main"

cp -f "${SRC_DIR}/store.sh" "${INSTALL_DIR}/store.sh"
cp -rf "${SRC_DIR}/core/"* "${INSTALL_DIR}/core/"
cp -rf "${SRC_DIR}/plugins/"* "${INSTALL_DIR}/plugins/"

rm -rf "$TMP_DIR"

if [ ! -f "${INSTALL_DIR}/store.sh" ]; then
    echo "[错误] 核心文件缺失，安装失败"
    exit 1
fi

chmod +x "${INSTALL_DIR}/store.sh"

echo ""
echo "[成功] 下载完成"
echo ""

echo "[配置] 创建快捷启动命令..."
cat > /usr/bin/apk-store << 'EOF'
#!/bin/sh
sh /root/apk-store/store.sh
EOF
chmod +x /usr/bin/apk-store

echo "[成功] 快捷命令已创建: apk-store"
echo ""
echo "[启动] OpenWrt APK安装脚本..."
echo ""
sh "${INSTALL_DIR}/store.sh"
