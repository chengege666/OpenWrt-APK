#!/bin/sh
# apk-opts.sh - APK 安装参数配置模块
# 提供 --allow-untrusted 开关，影响 LuCI 网页上传安装和命令行 apk add
#
# 用法:
#   sh apk-opts.sh          # 交互式切换
#   sh apk-opts.sh on       # 开启 --allow-untrusted
#   sh apk-opts.sh off      # 关闭 --allow-untrusted
#   sh apk-opts.sh status   # 查看当前状态

CONF_FILE="/etc/apk-store.conf"
PKG_MGR="/usr/libexec/package-manager-call"

# 初始化配置
apk_opts_init() {
    if [ ! -f "$CONF_FILE" ]; then
        echo "ALLOW_UNTRUSTED=true" > "$CONF_FILE"
    fi
    . "$CONF_FILE"
}

# 开启 --allow-untrusted
apk_set_on() {
    # 1. 修改包管理器后端（影响 LuCI 网页上传）
    if [ -f "$PKG_MGR" ]; then
        sed -i 's/^[[:space:]]*action="add"$/	action="add --allow-untrusted"/' "$PKG_MGR" 2>/dev/null
    fi

    # 2. 写入配置文件（影响 apk_get_opts 调用）
    echo "ALLOW_UNTRUSTED=true" > "$CONF_FILE"

    echo "[成功] --allow-untrusted 已开启（跳过签名验证）"
}

# 关闭 --allow-untrusted
apk_set_off() {
    # 1. 恢复包管理器后端
    if [ -f "$PKG_MGR" ]; then
        sed -i 's/^[[:space:]]*action="add --allow-untrusted"$/	action="add"/' "$PKG_MGR" 2>/dev/null
    fi

    # 2. 写入配置文件
    echo "ALLOW_UNTRUSTED=false" > "$CONF_FILE"

    echo "[成功] --allow-untrusted 已关闭（需要有效签名）"
}

# 查看状态
apk_show_status() {
    . "$CONF_FILE" 2>/dev/null || ALLOW_UNTRUSTED=true

    # 检查包管理器状态
    local pkg_status=""
    if [ -f "$PKG_MGR" ] && grep -q "action=\"add --allow-untrusted\"" "$PKG_MGR" 2>/dev/null; then
        pkg_status="已开启"
    else
        pkg_status="未开启"
    fi

    echo "ALLOW_UNTRUSTED=$([ "$ALLOW_UNTRUSTED" = "true" ] && echo 'true (开启)' || echo 'false (关闭)')"
    echo "LuCI 网页安装: $pkg_status"
    echo "安装参数: $(apk_get_opts)"
}

# 获取 APK 安装参数
apk_get_opts() {
    if [ -f "$CONF_FILE" ] && grep -q "ALLOW_UNTRUSTED=true" "$CONF_FILE" 2>/dev/null; then
        echo "--allow-untrusted --force-overwrite"
    else
        echo "--force-overwrite"
    fi
}

# 交互式菜单
apk_toggle_menu() {
    . "$CONF_FILE" 2>/dev/null || ALLOW_UNTRUSTED=true

    # 检测当前状态
    local pkg_on=0
    if [ -f "$PKG_MGR" ] && grep -q "action=\"add --allow-untrusted\"" "$PKG_MGR" 2>/dev/null; then
        pkg_on=1
    fi

    echo ""
    echo "================================"
    echo " --allow-untrusted 开关设置"
    echo "================================"
    echo ""
    if [ "$pkg_on" -eq 1 ]; then
        echo "  当前状态: 开启"
    else
        echo "  当前状态: 关闭"
    fi
    echo ""
    echo "  1. 开启（跳过签名验证，默认）"
    echo "  2. 关闭（需要有效签名）"
    echo "  0. 返回"
    echo ""
    printf "  请选择: "
    read -r choice < /dev/tty 2>/dev/null || read -r choice
    choice=$(echo "$choice" | tr -d '\r\n ')

    case "$choice" in
        1)
            apk_set_on
            ;;
        2)
            apk_set_off
            ;;
        0)
            return
            ;;
        *)
            echo "[错误] 无效输入"
            return 1
            ;;
    esac
}

# ============================================================
# 命令行入口
# ============================================================
case "$0" in
    */apk-opts.sh|apk-opts.sh|/dev/fd/*)
        apk_opts_init

        case "${1:-}" in
            on|true|1)
                apk_set_on
                ;;
            off|false|0)
                apk_set_off
                ;;
            status|-s|--status)
                apk_show_status
                ;;
            *)
                apk_toggle_menu
                ;;
        esac
        ;;
    *sh|*ash)
        if [ -c /dev/tty ] 2>/dev/null; then
            apk_opts_init
            apk_toggle_menu
        fi
        ;;
esac
