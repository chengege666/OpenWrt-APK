#!/bin/sh
# apk-opts.sh - APK 安装参数配置模块
# 提供 --allow-untrusted 开关的持久化存储与查询
#
# 用法:
#   source apk-opts.sh
#   apk_opts_init
#   apk add $(apk_get_opts) *.apk
#
# 命令行模式:
#   sh apk-opts.sh          # 交互式切换
#   sh apk-opts.sh on       # 开启 --allow-untrusted
#   sh apk-opts.sh off      # 关闭 --allow-untrusted
#   sh apk-opts.sh status   # 查看当前状态

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

# ============================================================
# LuCI 网页上传安装补丁（只影响网页界面）
# ============================================================

# 查找 LuCI 包管理 Lua 文件（只找 .lua 文件，排除 .json）
luci_find_pkg_manager() {
    # 精确搜索包含 apk 调用的 Lua 文件
    local result
    result=$(find /usr/lib/lua/luci /usr/share/luci -name "*.lua" -type f 2>/dev/null | xargs grep -l "apk" 2>/dev/null | head -1)
    [ -n "$result" ] && echo "$result" && return 0

    # 备用：常见路径
    for f in \
        /usr/lib/lua/luci/controller/admin/system.lua \
        /usr/lib/lua/luci/controller/admin/package-manager.lua \
        /usr/lib/lua/luci/model/cbi/admin_system/packages.lua \
        /usr/lib/lua/luci/view/admin_system/packages.htm; do
        [ -f "$f" ] && echo "$f" && return 0
    done

    return 1
}

# 给 LuCI 包管理器打补丁，添加 --allow-untrusted
luci_patch_upload() {
    local lua_file
    lua_file=$(luci_find_pkg_manager)

    if [ -z "$lua_file" ]; then
        echo "[错误] 未找到 LuCI 包管理 Lua 文件"
        return 1
    fi

    echo "[补丁] 目标文件: $lua_file"

    # 备份
    if [ ! -f "${lua_file}.bak" ]; then
        cp "$lua_file" "${lua_file}.bak"
        echo "[备份] 已保存: ${lua_file}.bak"
    fi

    # 替换 apk add 为带 --allow-untrusted 的版本
    if grep -q "apk add.*upload" "$lua_file" 2>/dev/null || \
       grep -q 'os.execute.*apk' "$lua_file" 2>/dev/null || \
       grep -q 'luci.sys.call.*apk' "$lua_file" 2>/dev/null; then

        # 多种可能的匹配模式
        sed -i 's/os\.execute("apk add/os.execute("apk add --allow-untrusted/g' "$lua_file"
        sed -i "s/os\.execute('apk add/os.execute('apk add --allow-untrusted/g" "$lua_file"
        sed -i 's/luci\.sys\.call("apk add/luci.sys.call("apk add --allow-untrusted/g' "$lua_file"
        sed -i "s/luci\.sys\.call('apk add/luci.sys.call('apk add --allow-untrusted/g" "$lua_file"

        echo "[成功] LuCI 补丁已应用"
    else
        echo "[警告] 未在 Lua 文件中找到 apk 调用，可能需要手动修改"
        echo "[提示] 请编辑 $lua_file，在 apk add 后添加 --allow-untrusted"
    fi
}

# 恢复 LuCI 补丁
luci_unpatch_upload() {
    local lua_file
    lua_file=$(luci_find_pkg_manager)

    if [ -z "$lua_file" ]; then
        echo "[错误] 未找到 LuCI 包管理 Lua 文件"
        return 1
    fi

    if [ -f "${lua_file}.bak" ]; then
        mv "${lua_file}.bak" "$lua_file"
        echo "[成功] LuCI 补丁已恢复"
    else
        echo "[警告] 未找到备份文件，无法恢复"
    fi
}

# ============================================================
# 交互式切换菜单
# ============================================================
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
    echo "  3. 修复 LuCI 网页上传安装（推荐）"
    echo "  4. 恢复 LuCI 网页上传安装"
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
        3)
            luci_patch_upload
            ;;
        4)
            luci_unpatch_upload
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
            patch-luci)
                luci_patch_upload
                ;;
            unpatch-luci)
                luci_unpatch_upload
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
