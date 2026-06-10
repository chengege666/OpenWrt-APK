#!/bin/sh
# plugins/daed.sh - Daed 插件模块（基于 eBPF 的高性能透明代理）

install_daed_deps() {
    echo "[依赖] 安装 Daed 运行依赖..."

    # daed 运行所需的依赖包
    local deps="ca-bundle v2ray-geoip v2ray-geosite"

    if command -v apk >/dev/null 2>&1; then
        for pkg in $deps; do
            if apk add --allow-untrusted "$pkg" 2>/dev/null; then
                echo "[依赖] $pkg 安装成功"
            else
                echo "[依赖] $pkg 已内置或无需安装"
            fi
        done
    else
        for pkg in $deps; do
            if opkg install "$pkg" 2>/dev/null; then
                echo "[依赖] $pkg 安装成功"
            else
                echo "[依赖] $pkg 已内置或无需安装"
            fi
        done
    fi

    echo "[依赖] 依赖检查完成"
}

install_daed() {
    echo ""
    echo "================================"
    echo " 安装 Daed"
    echo "================================"
    echo ""

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    local pkg_ext="ipk"
    [ "$is_apk" -eq 1 ] && pkg_ext="apk"

    local daed_arch
    case "$arch" in
        x86_64)    daed_arch="x86_64" ;;
        aarch64)   daed_arch="aarch64_generic" ;;
        *)
            echo "[错误] Daed 暂不支持 $arch 架构"
            echo "[提示] 目前支持的架构: x86_64, aarch64"
            return 1
            ;;
    esac

    # 先装依赖
    install_daed_deps

    local owner="QiuSimons"
    local repo="luci-app-daed"
    local plugin_name="daed"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    # 查找 daed 核心包（文件名如 daed_2026.06.08-r1_x86_64-openwrt-25.12.apk）
    local daed_url
    daed_url=$(echo "$all_urls" | grep -E "daed[-_][0-9].*${daed_arch}[^/]*\.${pkg_ext}$" | head -1)

    if [ -z "$daed_url" ]; then
        local base_arch="${daed_arch%_generic}"
        daed_url=$(echo "$all_urls" | grep -E "daed[-_][0-9].*${base_arch}[^/]*\.${pkg_ext}$" | head -1)
    fi

    if [ -z "$daed_url" ]; then
        echo "[错误] 未找到 ${arch} 架构的 Daed 核心包"
        return 1
    fi

    # 查找 luci-app-daed 界面包（文件名如 luci-app-daed_1.4-r1_all-openwrt-25.12.apk）
    local luci_url
    luci_url=$(echo "$all_urls" | grep -E "luci-app-daed[-_][0-9].*\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-daed 界面包"
        return 1
    fi

    # 查找中文包（文件名如 luci-i18n-daed-zh-cn_25.283.11553.bce4b5f_all-openwrt-25.12.apk）
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep -E "luci-i18n-daed-zh-cn[-_][0-9].*\.${pkg_ext}$" | head -1)

    # 查找 vmlinux-btf（daed 核心依赖，文件名如 vmlinux-btf_6.6.135_x86_64.ipk）
    local vmlinux_url
    vmlinux_url=$(echo "$all_urls" | grep -E "vmlinux-btf[-_][0-9].*\.${pkg_ext}$" | head -1)

    local daed_name
    daed_name=$(basename "$daed_url")

    local luci_name
    luci_name=$(basename "$luci_url")

    if ! download_file "$daed_url" "${CACHE_DIR}/${plugin_name}/${daed_name}"; then
        echo "[错误] Daed 核心下载失败"
        return 1
    fi

    if ! download_file "$luci_url" "${CACHE_DIR}/${plugin_name}/${luci_name}"; then
        echo "[错误] LuCI 界面下载失败"
        return 1
    fi

    local i18n_name=""
    if [ -n "$i18n_url" ]; then
        i18n_name=$(basename "$i18n_url")
        download_file "$i18n_url" "${CACHE_DIR}/${plugin_name}/${i18n_name}" || echo "[警告] 中文包下载失败"
    fi

    local vmlinux_name=""
    if [ -n "$vmlinux_url" ]; then
        vmlinux_name=$(basename "$vmlinux_url")
        download_file "$vmlinux_url" "${CACHE_DIR}/${plugin_name}/${vmlinux_name}" || echo "[警告] vmlinux-btf 下载失败"
    fi

    # ----- 一次性安装所有包（apk 可以一起解析依赖）-----
    echo "[安装] 安装 $tag ..."

    # 先清理可能残留的强制安装记录
    if [ "$is_apk" -eq 1 ]; then
        apk del --force-broken-world daed luci-app-daed luci-i18n-daed-zh-cn 2>/dev/null || true
    fi

    # 收集所有 APK 路径（包括 vmlinux-btf 依赖）
    local pkgs="${CACHE_DIR}/${plugin_name}/${daed_name} ${CACHE_DIR}/${plugin_name}/${luci_name}"
    [ -n "$i18n_name" ] && [ -f "${CACHE_DIR}/${plugin_name}/${i18n_name}" ] && pkgs="$pkgs ${CACHE_DIR}/${plugin_name}/${i18n_name}"
    [ -n "$vmlinux_name" ] && [ -f "${CACHE_DIR}/${plugin_name}/${vmlinux_name}" ] && pkgs="$pkgs ${CACHE_DIR}/${plugin_name}/${vmlinux_name}"

    if [ "$is_apk" -eq 1 ]; then
        echo "[安装] 尝试标准安装..."
        apk add --allow-untrusted --force-overwrite $pkgs 2>/dev/null && echo "[成功] 标准安装完成" || echo "[提示] 标准安装失败"

        # 检查文件是否落地，没有就强制安装
        if [ ! -f /usr/bin/daed ] && [ ! -f /usr/sbin/daed ]; then
            echo "[提示] 文件未落地，尝试强制安装..."
            apk add --allow-untrusted --force-overwrite --force-broken-world $pkgs 2>/dev/null && echo "[成功] 强制安装完成" || echo "[提示] 强制安装也失败"
        fi

        # 如果还是没有文件，用 apk extract 手动解压（必须 cd / 才能解压到正确位置）
        if [ ! -f /usr/bin/daed ] && [ ! -f /usr/sbin/daed ]; then
            echo "[提示] 文件仍未落地，使用 apk extract 手动解压..."
            for pkg in $pkgs; do
                echo "[手动] 解压 $(basename $pkg)..."
                (cd / && apk extract --allow-untrusted "$pkg" 2>/dev/null) || echo "[警告] 解压 $(basename $pkg) 失败"
            done
        fi

        # 检查文件是否落地
        if [ -f /usr/bin/daed ] || [ -f /usr/sbin/daed ]; then
            echo "[成功] Daed 核心已安装: $(ls /usr/bin/daed /usr/sbin/daed 2>/dev/null)"
        else
            echo "[错误] Daed 核心文件未找到"
            return 1
        fi

        if ls /usr/lib/lua/luci/controller/daed* >/dev/null 2>&1 || ls /usr/share/luci/menu.d/*daed* >/dev/null 2>&1; then
            echo "[成功] LuCI 界面已安装"
        else
            echo "[错误] LuCI 界面文件未找到"
            echo "[提示] 请尝试手动安装：apk add --allow-untrusted $pkgs"
            return 1
        fi
    else
        # opkg 安装
        if opkg install --force-overwrite $pkgs 2>/dev/null; then
            echo "[成功] 安装完成"
        else
            opkg install --force-overwrite --force-depends $pkgs 2>/dev/null || echo "[警告] 安装可能有问题"
        fi

        if [ -f /usr/bin/daed ] || [ -f /usr/sbin/daed ]; then
            echo "[成功] Daed 核心已安装"
        else
            echo "[错误] Daed 核心安装失败"
            return 1
        fi
    fi

    # 验证二进制是否存在
    local daed_bin=""
    [ -f /usr/bin/daed ] && daed_bin="/usr/bin/daed"
    [ -f /usr/sbin/daed ] && daed_bin="/usr/sbin/daed"

    if [ -n "$daed_bin" ]; then
        echo "[成功] Daed 核心已安装: $daed_bin"
        chmod +x "$daed_bin" 2>/dev/null
    else
        echo "[警告] 未找到 daed 二进制文件，但包已解压"
    fi

    # ----- 创建/启用服务 -----
    echo "[启用] 配置 Daed 服务..."
    if [ -f /etc/init.d/daed ]; then
        /etc/init.d/daed enable 2>/dev/null
        /etc/init.d/daed start 2>/dev/null
        echo "[成功] Daed 服务已启用"
    else
        echo "[创建] 创建 Daed 服务脚本..."
        cat > /etc/init.d/daed << 'INITEOF'
#!/bin/sh /etc/rc.common

START=50
STOP=90

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/daed
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall daed 2>/dev/null
}

service_triggers() {
    procd_add_reload_trigger "daed"
}
INITEOF
        chmod +x /etc/init.d/daed
        /etc/init.d/daed enable 2>/dev/null
        /etc/init.d/daed start 2>/dev/null
        echo "[成功] Daed 服务脚本已创建并启用"
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* /tmp/luci-modulecache* /tmp/luci-indexcache* /tmp/luci-sessions 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo ""
    echo "================================"
    echo " Daed 安装完成"
    echo "================================"
    echo ""
    echo "请尝试以下操作让 LuCI 菜单出现："
    echo "1. 浏览器 Ctrl+Shift+R 强制刷新"
    echo "2. 或退出登录后重新登录"
    echo "3. 或重启设备"
    echo ""
}

uninstall_daed() {
    echo ""
    echo "================================"
    echo " 卸载 Daed"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-daed"
    uninstall_plugin "daed"
    uninstall_plugin "luci-i18n-daed-zh-cn"

    echo "[清理] 清理残留文件..."
    rm -f /etc/init.d/daed
    rm -rf /tmp/luci-* /tmp/luci-modulecache* /tmp/luci-indexcache* 2>/dev/null

    show_success
}

update_daed() {
    echo ""
    echo "================================"
    echo " 更新 Daed"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_daed
}
