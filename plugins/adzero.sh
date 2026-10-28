#!/bin/sh
# plugins/adzero.sh - AdZero 广告过滤与 DNS 分流插件模块

install_adzero() {
    echo ""
    echo "================================"
    echo " 安装 AdZero"
    echo "================================"
    echo ""

    echo "[安装] 正在使用官方一键脚本进行安装..."
    local tmp_script="/tmp/adzero-install.sh"
    if curl -fL --proto '=https' --proto-redir '=https' \
        https://raw.githubusercontent.com/slobys/AdZero/main/scripts/install.sh \
        -o "$tmp_script" 2>/dev/null; then
        if sh "$tmp_script"; then
            rm -f "$tmp_script"
            echo "[成功] AdZero 安装完成"
            echo ""
            echo "[提示] 安装后请打开 LuCI：服务 → AdZero"
            echo "[提示] 页面未更新请按 Ctrl+F5 刷新"
            show_success
            return 0
        else
            rm -f "$tmp_script"
            echo "[错误] 官方脚本执行失败"
            return 1
        fi
    else
        echo "[错误] 官方脚本下载失败，请检查网络"
        return 1
    fi
}

uninstall_adzero() {
    echo ""
    echo "================================"
    echo " 卸载 AdZero"
    echo "================================"
    echo ""

    # 先 disable 恢复 AdZero 接管的 DNS 设置
    if [ -x /usr/libexec/adzero/ctl ]; then
        echo "[恢复] 正在恢复 AdZero 接管的网络设置..."
        /usr/libexec/adzero/ctl disable 2>/dev/null || true
    fi

    echo "[卸载] 正在移除 luci-app-adzero 包..."
    if command -v apk >/dev/null 2>&1 && apk info --installed luci-app-adzero >/dev/null 2>&1; then
        apk del luci-app-adzero 2>/dev/null || true
    elif command -v opkg >/dev/null 2>&1 && opkg list-installed 2>/dev/null | grep -q "^luci-app-adzero"; then
        opkg remove luci-app-adzero --autoremove 2>/dev/null || true
    else
        echo "[提示] 包管理器中未找到 luci-app-adzero，可能已卸载"
    fi

    echo "[清理] 清理残留文件..."
    rm -rf /usr/libexec/adzero 2>/dev/null
    rm -rf /usr/share/adzero 2>/dev/null
    rm -f /etc/init.d/adzero 2>/dev/null
    rm -rf /tmp/luci-indexcache 2>/dev/null
    rm -rf /tmp/luci-modulecache 2>/dev/null

    echo "[提示] 配置文件 /etc/adzero 已保留，如需彻底清理请手动删除"

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] AdZero 卸载完成"
}

update_adzero() {
    echo ""
    echo "================================"
    echo " 更新 AdZero"
    echo "================================"
    echo ""

    echo "[更新] 正在使用官方一键脚本进行升级..."
    local tmp_script="/tmp/adzero-install.sh"
    if curl -fL --proto '=https' --proto-redir '=https' \
        https://raw.githubusercontent.com/slobys/AdZero/main/scripts/install.sh \
        -o "$tmp_script" 2>/dev/null; then
        if sh "$tmp_script" --upgrade; then
            rm -f "$tmp_script"
            echo "[成功] AdZero 更新完成"
            show_success
            return 0
        else
            rm -f "$tmp_script"
            echo "[错误] 官方升级脚本执行失败"
            return 1
        fi
    else
        echo "[错误] 官方脚本下载失败，请检查网络"
        return 1
    fi
}
