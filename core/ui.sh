#!/bin/sh
# core/ui.sh - 用户界面模块

show_main_menu() {
    echo "========================================"
    echo " OpenWrt APK Store"
    echo "========================================"
    echo ""
    echo "1.   安装插件"
    echo "2.   卸载插件"
    echo "3.   更新插件"
    echo "4.   一键配置启动快捷键"
    echo "5.   基础初始化（时区 / 中文 / SFTP / 工具）"
    echo "6.   自定义 overlay 扩容"
    echo "7.   查看系统信息"
    echo "8.   APK 安装参数 (--allow-untrusted)"
    echo "9.   软件源修改"
    echo "00.  卸载脚本"
    echo "000. 更新脚本"
    echo "0.   退出"
    echo "========================================"
    echo ""
}

show_install_plugin_menu() {
    echo "================================"
    echo " 安装插件"
    echo "================================"
    echo ""
    echo -e "  1.  OpenClash (科学上网)       6.  Argon 主题 (后台主题)"
    echo -e "  2.  MosDNS (DNS解析)           7.  TaskPlan (定时任务)"
    echo -e "  3.  Docker (容器管理)          8.  PassWall2 (科学上网)"
    echo -e "  4.  Aurora 主题 (后台主题)     9.  SmartDNS (DNS加速)"
    echo -e "  5.  Lucky (端口转发)           10. Daed (科学上网)"
    echo -e "  11. iStore (软件商店)          12. DiskMan (磁盘管理)"
    echo -e "  13. WeChatPush (消息推送)      14. PassWall (科学上网)"
    echo -e "  15. Nikki (科学上网)"
    echo -e "  0.  返回上级"
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
    echo -e "  1.  卸载 OpenClash (科学上网)   6.  卸载 Argon 主题 (后台主题)"
    echo -e "  2.  卸载 MosDNS (DNS解析)       7.  卸载 TaskPlan (定时任务)"
    echo -e "  3.  卸载 Docker (容器管理)      8.  卸载 PassWall2 (科学上网)"
    echo -e "  4.  卸载 Aurora 主题 (后台主题) 9.  卸载 SmartDNS (DNS加速)"
    echo -e "  5.  卸载 Lucky (端口转发)       10. 卸载 Daed (科学上网)"
    echo -e "  11. 卸载 iStore (软件商店)      12. 卸载 DiskMan (磁盘管理)"
    echo -e "  13. 卸载 WeChatPush (消息推送)  14. 卸载 PassWall (科学上网)"
    echo -e "  15. 卸载 Nikki (科学上网)"
    echo -e "  0.  返回上级"
    echo ""
}

show_update_menu() {
    echo "================================"
    echo " 更新插件"
    echo "================================"
    echo ""
    echo -e "  1.  更新 OpenClash (科学上网)   6.  更新 Argon 主题 (后台主题)"
    echo -e "  2.  更新 MosDNS (DNS解析)       7.  更新 TaskPlan (定时任务)"
    echo -e "  3.  更新 Docker (容器管理)      8.  更新 PassWall2 (科学上网)"
    echo -e "  4.  更新 Aurora 主题 (后台主题) 9.  更新 SmartDNS (DNS加速)"
    echo -e "  5.  更新 Lucky (端口转发)       10. 更新 Daed (科学上网)"
    echo -e "  11. 更新 iStore (软件商店)      12. 更新 DiskMan (磁盘管理)"
    echo -e "  13. 更新 WeChatPush (消息推送)  14. 更新 PassWall (科学上网)"
    echo -e "  15. 更新 Nikki (科学上网)       16. 更新全部"
echo -e "  0.  返回上级"
    echo ""
}

show_repo_menu() {
    echo "================================"
    echo " 软件源修改"
    echo "================================"
    echo ""
    echo -e "  1.  中科大源 (USTC)"
    echo -e "  2.  清华源 (Tsinghua)"
    echo -e "  3.  官方源 (Official)"
    echo -e "  4.  恢复默认源"
    echo -e "  5.  查看当前源"
    echo -e "  6.  测试源延迟"
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
