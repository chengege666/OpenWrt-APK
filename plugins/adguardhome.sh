#!/bin/sh
# plugins/adguardhome.sh - AdGuard Home 插件模块

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuard Home"
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
    echo "[系统] OpenWrt $DISTRIB_RELEASE ($([ "$is_apk" -eq 1 ] && echo 'APK' || echo 'OPKG'))"

    # ---------- 方式一: 通过包管理器安装 ----------
    echo "[步骤 1/2] 尝试通过包管理器安装..."

    if [ "$is_apk" -eq 1 ]; then
        if apk add adguardhome 2>/dev/null; then
            echo "[成功] adguardhome 核心安装完成"
        else
            echo "[提示] 软件源中未找到 adguardhome 包，改用手动安装"
            install_adguardhome_manual "$arch" && return 0 || return 1
        fi
        # 可选安装 LuCI 界面及中文包
        apk add luci-app-adguardhome 2>/dev/null && echo "[成功] luci-app-adguardhome 安装完成" || \
            echo "[提示] 软件源中未提供 luci-app-adguardhome"
        apk add luci-i18n-adguardhome-zh-cn 2>/dev/null && echo "[成功] luci-i18n-adguardhome-zh-cn 安装完成" || \
            echo "[提示] 软件源中未提供 luci-i18n-adguardhome-zh-cn"
        if ! apk info --installed luci-app-adguardhome >/dev/null 2>&1; then
            echo "[提示] 如需 Web 界面请访问 AdGuard Home 内置管理页面 (端口 3000)"
        fi
    else
        opkg update 2>/dev/null
        if opkg install adguardhome 2>/dev/null; then
            echo "[成功] adguardhome 核心安装完成"
        else
            echo "[提示] 软件源中未找到 adguardhome 包，改用手动安装"
            install_adguardhome_manual "$arch" && return 0 || return 1
        fi
        opkg install luci-app-adguardhome 2>/dev/null && echo "[成功] luci-app-adguardhome 安装完成" || \
            echo "[提示] 软件源中未提供 luci-app-adguardhome"
        opkg install luci-i18n-adguardhome-zh-cn 2>/dev/null && echo "[成功] luci-i18n-adguardhome-zh-cn 安装完成" || \
            echo "[提示] 软件源中未提供 luci-i18n-adguardhome-zh-cn"
        if ! opkg list-installed 2>/dev/null | grep -q "^luci-app-adguardhome"; then
            echo "[提示] 如需 Web 界面请访问 AdGuard Home 内置管理页面 (端口 3000)"
        fi
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
    return 0
}

# 手动安装 AdGuard Home（当包管理器不可用时）
install_adguardhome_manual() {
    local arch="$1"

    echo ""
    echo "[手动] 从 AdGuard Home 官方 GitHub 下载..."

    local owner="AdguardTeam"
    local repo="AdGuardHome"
    local plugin_name="adguardhome"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    # 架构映射（AdGuardHome 文件命名规则）
    local agh_arch
    case "$arch" in
        x86_64)
            agh_arch="linux_amd64"
            ;;
        aarch64)
            agh_arch="linux_arm64"
            ;;
        arm)
            agh_arch="linux_armv7"
            ;;
        mipsel)
            agh_arch="linux_mipsle_softfloat"
            ;;
        mips)
            agh_arch="linux_mips_softfloat"
            ;;
        riscv64)
            agh_arch="linux_riscv64"
            ;;
        *)
            echo "[错误] 不支持的架构: $arch"
            return 1
            ;;
    esac

    # 查找匹配的 tar.gz
    local tarball_url
    tarball_url=$(echo "$all_urls" | grep "AdGuardHome_${agh_arch}.tar.gz" | head -1)

    if [ -z "$tarball_url" ]; then
        echo "[错误] 未找到匹配架构 ${arch} (${agh_arch}) 的下载包"
        echo "[提示] 可用文件列表:"
        echo "$all_urls" | grep "tar.gz" | head -10
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local tarball_name
    tarball_name=$(basename "$tarball_url")

    echo "[下载] $tarball_name ..."
    if ! download_file "$tarball_url" "${download_dir}/${tarball_name}"; then
        echo "[错误] 下载失败"
        rm -rf "$download_dir"
        return 1
    fi

    echo "[解压] 正在解压..."
    if ! tar xzf "${download_dir}/${tarball_name}" -C "$download_dir" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -rf "$download_dir"
        return 1
    fi

    # AdGuardHome 解压后目录名为 AdGuardHome
    local extract_dir="${download_dir}/AdGuardHome"
    if [ ! -d "$extract_dir" ]; then
        # 尝试查找实际解压目录
        extract_dir=$(find "$download_dir" -maxdepth 2 -name "AdGuardHome" -type d 2>/dev/null | head -1)
    fi

    if [ ! -d "$extract_dir" ] || [ ! -f "${extract_dir}/AdGuardHome" ]; then
        echo "[错误] 解压后未找到可执行文件"
        rm -rf "$download_dir"
        return 1
    fi

    echo "[安装] 安装 AdGuard Home 到 /opt/AdGuardHome ..."
    mkdir -p /opt
    rm -rf /opt/AdGuardHome 2>/dev/null
    cp -r "$extract_dir" /opt/

    if [ ! -f /opt/AdGuardHome/AdGuardHome ]; then
        echo "[错误] 复制失败"
        rm -rf "$download_dir"
        return 1
    fi
    chmod +x /opt/AdGuardHome/AdGuardHome

    echo "[服务] 注册系统服务..."
    /opt/AdGuardHome/AdGuardHome -s install 2>/dev/null || {
        # 手动创建 init 脚本
        cat > /etc/init.d/AdGuardHome << 'INITEOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /opt/AdGuardHome/AdGuardHome
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    /opt/AdGuardHome/AdGuardHome -s stop
}

service_triggers() {
    procd_add_reload_trigger "adguardhome"
}
INITEOF
        chmod +x /etc/init.d/AdGuardHome
        /etc/init.d/AdGuardHome enable 2>/dev/null
    }

    echo "[启动] 启动 AdGuard Home..."
    /opt/AdGuardHome/AdGuardHome -s start 2>/dev/null || /etc/init.d/AdGuardHome start 2>/dev/null

    echo "[成功] AdGuard Home 手动安装完成"
    echo ""
    echo "========================================"
    echo "  首次配置请访问: http://$(ip route get 1 2>/dev/null | grep src= | awk '{print $7}'):3000"
    echo "  或访问路由器 IP:3000 进行初始化设置"
    echo "========================================"
    echo ""

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
    return 0
}

uninstall_adguardhome() {
    echo ""
    echo "================================"
    echo " 卸载 AdGuard Home"
    echo "================================"
    echo ""

    # 判断是包管理器安装还是手动安装
    if command -v apk >/dev/null 2>&1 && apk info --installed adguardhome >/dev/null 2>&1; then
        echo "[卸载] 通过包管理器卸载..."
        apk del adguardhome 2>/dev/null
        apk del luci-app-adguardhome 2>/dev/null
    elif command -v opkg >/dev/null 2>&1 && opkg list-installed 2>/dev/null | grep -q "^adguardhome"; then
        echo "[卸载] 通过包管理器卸载..."
        opkg remove adguardhome 2>/dev/null
        opkg remove luci-app-adguardhome 2>/dev/null
    else
        echo "[卸载] 卸载手动安装版本..."
        echo "[停止] 停止服务..."
        /opt/AdGuardHome/AdGuardHome -s stop 2>/dev/null
        /opt/AdGuardHome/AdGuardHome -s uninstall 2>/dev/null
        /etc/init.d/AdGuardHome stop 2>/dev/null
        /etc/init.d/AdGuardHome disable 2>/dev/null

        echo "[清理] 删除文件..."
        rm -rf /opt/AdGuardHome
        rm -f /etc/init.d/AdGuardHome
    fi

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_adguardhome() {
    echo ""
    echo "================================"
    echo " 更新 AdGuard Home"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_adguardhome
}
