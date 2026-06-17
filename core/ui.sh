#!/bin/sh
# core/ui.sh - 用户界面模块

# 颜色定义
GREEN='\033[32m'
NC='\033[0m'

# 缓存已安装包列表（避免重复查询）
_INSTALLED_CACHE=""
_load_installed_cache() {
    if [ -z "$_INSTALLED_CACHE" ]; then
        _INSTALLED_CACHE="$(apk info 2>/dev/null; opkg list-installed 2>/dev/null | cut -d' ' -f1)"
    fi
}

# 检测插件是否已安装
_is_installed() {
    local pkg="$1"
    _load_installed_cache
    echo "$_INSTALLED_CACHE" | grep -qx "$pkg"
}

# 根据安装状态输出带颜色的文本（无换行）
_ci() {
    local pkg="$1"
    local text="$2"
    if _is_installed "$pkg"; then
        printf '\033[32m%s\033[0m' "$text"
    else
        printf '%s' "$text"
    fi
}

show_main_menu() {
    echo "================================"
    echo " OpenWrt APK Store"
    echo "================================"
    echo ""
    echo "1.   安装插件"
    echo "2.   卸载插件"
    echo "3.   更新插件"
    echo "4.   一键配置启动快捷键"
    echo "00.  卸载脚本"
    echo "000. 更新脚本"
    echo "0.   退出"
    echo ""
}

show_install_plugin_menu() {
    echo "================================"
    echo " 安装插件"
    echo "================================"
    echo ""
    _ci "luci-app-openclash" "1.  OpenClash             "; _ci "luci-app-argon-config" "6.  Argon 主题"
    echo ""
    _ci "luci-app-mosdns" "2.  MosDNS                "; _ci "luci-app-taskplan" "7.  TaskPlan"
    echo ""
    _ci "docker" "3.  Docker                "; _ci "luci-app-passwall2" "8.  PassWall2"
    echo ""
    _ci "luci-theme-aurora" "4.  Aurora 主题           "; _ci "luci-app-smartdns" "9.  SmartDNS"
    echo ""
    _ci "luci-app-lucky" "5.  Lucky                 "; _ci "luci-app-daed" "10. Daed"
    echo ""
    _ci "luci-app-store" "11. iStore                "; _ci "luci-app-diskman" "12. DiskMan"
    echo ""
    _ci "luci-app-wechatpush" "13. WeChatPush"
    echo ""
    echo "0.  返回上级"
    echo ""
}

show_shortcut_list() {
    local found=0
    for f in /usr/bin/?; do
        [ -e "$f" ] || continue
        if [ -L "$f" ] && [ "$(readlink "$f")" = "${SCRIPT_DIR}/store.sh" ] 2>/dev/null; then
            echo "  $(basename "$f") -> Open APK Store"
            found=1
        elif [ -f "$f" ] && head -1 "$f" 2>/dev/null | grep -q "${SCRIPT_DIR}/store.sh"; then
            echo "  $(basename "$f") -> Open APK Store"
            found=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "[提示] 暂无已设置的快捷键"
    else
        echo ""
        echo "在终端输入以上字母即可启动 APK Store"
    fi
}

show_uninstall_menu() {
    echo "================================"
    echo " 卸载插件"
    echo "================================"
    echo ""
    _ci "luci-app-openclash" "1.  卸载 OpenClash        "; _ci "luci-app-argon-config" "6.  卸载 Argon 主题"
    echo ""
    _ci "luci-app-mosdns" "2.  卸载 MosDNS           "; _ci "luci-app-taskplan" "7.  卸载 TaskPlan"
    echo ""
    _ci "docker" "3.  卸载 Docker           "; _ci "luci-app-passwall2" "8.  卸载 PassWall2"
    echo ""
    _ci "luci-theme-aurora" "4.  卸载 Aurora 主题      "; _ci "luci-app-smartdns" "9.  卸载 SmartDNS"
    echo ""
    _ci "luci-app-lucky" "5.  卸载 Lucky            "; _ci "luci-app-daed" "10. 卸载 Daed"
    echo ""
    _ci "luci-app-store" "11. 卸载 iStore           "; _ci "luci-app-diskman" "12. 卸载 DiskMan"
    echo ""
    _ci "luci-app-wechatpush" "13. 卸载 WeChatPush"
    echo ""
    echo -e "  0.  返回上级"
    echo ""
}

show_update_menu() {
    echo "================================"
    echo " 更新插件"
    echo "================================"
    echo ""
    _ci "luci-app-openclash" "1.  更新 OpenClash        "; _ci "luci-app-argon-config" "6.  更新 Argon 主题"
    echo ""
    _ci "luci-app-mosdns" "2.  更新 MosDNS           "; _ci "luci-app-taskplan" "7.  更新 TaskPlan"
    echo ""
    _ci "docker" "3.  更新 Docker           "; _ci "luci-app-passwall2" "8.  更新 PassWall2"
    echo ""
    _ci "luci-theme-aurora" "4.  更新 Aurora 主题      "; _ci "luci-app-smartdns" "9.  更新 SmartDNS"
    echo ""
    _ci "luci-app-lucky" "5.  更新 Lucky            "; _ci "luci-app-daed" "10. 更新 Daed"
    echo ""
    _ci "luci-app-store" "11. 更新 iStore           "; _ci "luci-app-diskman" "12. 更新 DiskMan"
    echo ""
    _ci "luci-app-wechatpush" "13. 更新 WeChatPush"
    echo ""
    echo -e "  14. 更新全部"
    echo -e "  0.  返回上级"
    echo ""
}

show_success() {
    echo ""
    echo "================================"
    echo " 安装成功！"
    echo "================================"
    echo ""
}

show_error() {
    echo ""
    echo "================================"
    echo " 操作失败"
    echo "================================"
    echo ""
}

show_progress() {
    local message="$1"
    echo "[进度] $message"
}

confirm_action() {
    local message="$1"
    echo ""
    echo "$message"
    printf "确认继续？(y/n): "
    read -r confirm
    case "$confirm" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_enter() {
    echo ""
    printf "按回车键继续..."
    read -r dummy
}
