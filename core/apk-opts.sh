#!/bin/sh
# core/apk-opts.sh - APK 安装参数配置模块
# 提供 --allow-untrusted 开关的持久化存储与查询
#
# 用法:
#   source core/apk-opts.sh
#   apk_opts_init
#   apk add $(apk_get_opts) *.apk
#
# 命令行模式:
#   sh core/apk-opts.sh          # 交互式切换
#   sh core/apk-opts.sh on       # 开启 --allow-untrusted
#   sh core/apk-opts.sh off      # 关闭 --allow-untrusted
#   sh core/apk-opts.sh status   # 查看当前状态

CONF_FILE="/etc/apk-store.conf"

# 初始化配置，如果配置文件不存在则创建默认值
apk_opts_init() {
    if [ ! -f "$CONF_FILE" ]; then
        echo "ALLOW_UNTRUSTED=true" > "$CONF_FILE"
    fi
    . "$CONF_FILE"
}

# 获取 APK 安装参数，供脚本调用
# 返回值: 适合直接传递给 apk add 的参数串
apk_get_opts() {
    if [ -f "$CONF_FILE" ] && grep -q "ALLOW_UNTRUSTED=true" "$CONF_FILE" 2>/dev/null; then
        echo "--allow-untrusted --force-overwrite"
    else
        echo "--force-overwrite"
    fi
}

# 检查是否允许无签名安装
# 返回值: 0=允许, 1=不允许
apk_is_untrusted() {
    [ -f "$CONF_FILE" ] && grep -q "ALLOW_UNTRUSTED=true" "$CONF_FILE" 2>/dev/null
}

# 设置开关值
# 参数: true 或 false
apk_set_untrusted() {
    local val="$1"
    case "$val" in
        true)
            echo "ALLOW_UNTRUSTED=true" > "$CONF_FILE"
            echo "[成功] --allow-untrusted 已开启（跳过签名验证）"
            return 0
            ;;
        false)
            echo "ALLOW_UNTRUSTED=false" > "$CONF_FILE"
            echo "[成功] --allow-untrusted 已关闭（需要有效签名）"
            return 0
            ;;
        *)
            echo "[错误] 参数必须为 true 或 false"
            return 1
            ;;
    esac
}

# 交互式切换菜单
apk_toggle_menu() {
    . "$CONF_FILE" 2>/dev/null || ALLOW_UNTRUSTED=true

    echo ""
    echo "================================"
    echo " --allow-untrusted 开关设置"
    echo "================================"
    echo ""
    echo "  当前状态: $([ "$ALLOW_UNTRUSTED" = "true" ] && echo '✓ 开启' || echo '✗ 关闭')"
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
            apk_set_untrusted true
            ;;
        2)
            apk_set_untrusted false
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
                apk_set_untrusted true
                ;;
            off|false|0)
                apk_set_untrusted false
                ;;
            status|-s|--status)
                . "$CONF_FILE"
                echo "ALLOW_UNTRUSTED=$([ "$ALLOW_UNTRUSTED" = "true" ] && echo 'true (开启)' || echo 'false (关闭)')"
                echo "安装参数: $(apk_get_opts)"
                ;;
            *)
                apk_toggle_menu
                ;;
        esac
        ;;
    *sh|*ash)
        # 管道模式：wget -qO- ... | sh
        if [ -c /dev/tty ] 2>/dev/null; then
            apk_opts_init
            apk_toggle_menu
        fi
        ;;
esac
