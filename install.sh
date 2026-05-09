#!/bin/sh
# install.sh - 一键安装脚本
# 使用方式: wget -O- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh | sh

REPO_URL="https://github.com/chengege666/OpenWrt-APK"
INSTALL_DIR="/root/apk-store"

echo "================================"
echo " OpenWrt APK Store 安装器"
echo "================================"
echo ""

if ! wget -q --spider --timeout=5 https://github.com 2>/dev/null; then
    echo "[错误] 网络连接失败"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "[安装] 正在安装 git..."
    apk update 2>/dev/null
    apk add git 2>/dev/null
    if ! command -v git >/dev/null 2>&1; then
        echo "[错误] git 安装失败，请手动安装"
        exit 1
    fi
fi

echo "[下载] 正在克隆 OpenWrt APK Store..."

rm -rf "$INSTALL_DIR"

if git clone --depth=1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
    echo "[成功] 克隆完成"
else
    echo "[错误] 克隆失败"
    exit 1
fi

chmod +x "${INSTALL_DIR}/store.sh"

echo ""
echo "[配置] 创建快捷启动命令..."
cat > /usr/bin/apk-store << 'EOF'
#!/bin/sh
sh /root/apk-store/store.sh
EOF
chmod +x /usr/bin/apk-store

echo "[成功] 快捷命令已创建: apk-store"
echo ""
echo "[启动] OpenWrt APK Store..."
echo ""
sh "${INSTALL_DIR}/store.sh"
