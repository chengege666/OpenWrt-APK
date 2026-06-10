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

    # 查找 daed 核心包
    local daed_url
    daed_url=$(echo "$all_urls" | grep -E "/daed[-_][^/]+${daed_arch}[^/]*\.${pkg_ext}$" | head -1)

    if [ -z "$daed_url" ]; then
        local base_arch="${daed_arch%_generic}"
        daed_url=$(echo "$all_urls" | grep -E "/daed[-_][^/]+${base_arch}[^/]*\.${pkg_ext}$" | head -1)
    fi

    if [ -z "$daed_url" ]; then
        echo "[错误] 未找到 ${arch} 架构的 Daed 核心包"
        return 1
    fi

    # 查找 luci-app-daed 界面包
    local luci_url
    luci_url=$(echo "$all_urls" | grep -E "/luci-app-daed[-_][^/]*\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-daed 界面包"
        return 1
    fi

    # 查找中文包
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep -E "/luci-i18n-daed-zh-cn[-_][^/]*\.${pkg_ext}$" | head -1)

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

    # ----- 安装 daed 核心 -----
    echo "[安装] 安装 Daed 核心..."

    # 先清理可能残留的强制安装记录
    if [ "$is_apk" -eq 1 ]; then
        apk del --force-broken-world daed 2>/dev/null || true
    fi

    # 策略 1: 正常安装
    local daed_installed=0
    if [ "$is_apk" -eq 1 ]; then
        echo "[安装] apk add --allow-untrusted ${daed_name}..."
        local install_output
        install_output=$(apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>&1)
        if echo "$install_output" | grep -q "^OK"; then
            if apk info -e daed 2>/dev/null; then
                daed_installed=1
            fi
        fi
        if [ "$daed_installed" -eq 0 ]; then
            echo "[提示] 标准安装失败，尝试强制安装..."
            install_output=$(apk add --allow-untrusted --force-overwrite --force-broken-world "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>&1)
            echo "$install_output"
            if apk info -e daed 2>/dev/null; then
                daed_installed=1
            fi
        fi
    else
        if opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${daed_name}" 2>/dev/null; then
            daed_installed=1
        fi
    fi

    # 策略 2: 手动解压
    if [ "$daed_installed" -eq 0 ]; then
        local pkg_file="${CACHE_DIR}/${plugin_name}/${daed_name}"

        echo "[手动] 分析包格式..."
        local tmp_dir="/tmp/daed-extract-$$"
        rm -rf "$tmp_dir"
        mkdir -p "$tmp_dir"

        # OpenWrt APK 实际上是 .tar.gz 格式
        tar xzf "$pkg_file" -C "$tmp_dir" 2>/dev/null || {
            # 可能 gzip 压缩但不是 tar
            gzip -dc "$pkg_file" > "$tmp_dir/raw" 2>/dev/null || {
                # 可能是 ZIP (Android APK 格式)
                unzip -o -q "$pkg_file" -d "$tmp_dir" 2>/dev/null || true
            }
        }

        # 检查并解压内容
        if [ -f "$tmp_dir/data.tar.gz" ]; then
            echo "[手动] 检测到 data.tar.gz (标准 OpenWrt 包格式)"
            tar xzf "$tmp_dir/data.tar.gz" -C / 2>/dev/null && daed_installed=1
        fi

        if [ "$daed_installed" -eq 0 ] && [ -f "$tmp_dir/raw" ]; then
            echo "[手动] 检测到 gzip 压缩数据，尝试解压到根目录..."
            gzip -dc "$pkg_file" | tar xf - -C / 2>/dev/null || {
                cp -f "$tmp_dir/raw" /usr/bin/daed 2>/dev/null && chmod +x /usr/bin/daed
            }
        fi

        if [ "$daed_installed" -eq 0 ]; then
            echo "[手动] 检查包内容..."
            local pkg_contents
            pkg_contents=$(ls -la "$tmp_dir/" 2>/dev/null | head -30)
            echo "$pkg_contents"

            # 直接解压到根目录试试
            tar xzf "$pkg_file" -C / 2>/dev/null || true
            gzip -dc "$pkg_file" | tar xf - -C / 2>/dev/null || true
            unzip -o -q "$pkg_file" -d / 2>/dev/null || true
        fi

        # 运行 postinst 脚本
        if [ -f "$tmp_dir/postinst" ]; then
            chmod +x "$tmp_dir/postinst"
            "$tmp_dir/postinst" 2>/dev/null || true
        fi

        rm -rf "$tmp_dir"

        # 检查是否成功
        if [ -f /usr/bin/daed ] || [ -f /usr/sbin/daed ] || [ -f /usr/local/bin/daed ]; then
            daed_installed=1
        fi
    fi

    if [ "$daed_installed" -eq 0 ]; then
        echo "[错误] Daed 核心安装失败"
        echo "[提示] 请确认系统版本与 daed 兼容，或尝试手动安装:"
        echo "  apk add --allow-untrusted ${CACHE_DIR}/${plugin_name}/${daed_name}"
        return 1
    fi

    # 验证二进制是否存在
    local daed_bin=""
    [ -f /usr/bin/daed ] && daed_bin="/usr/bin/daed"
    [ -f /usr/sbin/daed ] && daed_bin="/usr/sbin/daed"

    if [ -n "$daed_bin" ]; then
        echo "[成功] Daed 核心已安装: $daed_bin"
    else
        echo "[警告] 未找到 daed 二进制文件，但包已解压"
    fi

    # ----- 安装 LuCI 界面 -----
    echo "[安装] 安装 LuCI 界面..."
    local luci_installed=0
    if [ "$is_apk" -eq 1 ]; then
        if apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${luci_name}" 2>/dev/null; then
            luci_installed=1
        else
            echo "[提示] 标准安装失败，尝试手动解压..."
        fi
    else
        if opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${luci_name}" 2>/dev/null; then
            luci_installed=1
        fi
    fi

    # 手动解压 LuCI
    if [ "$luci_installed" -eq 0 ]; then
        local tmp_dir="/tmp/daed-luci-extract-$$"
        rm -rf "$tmp_dir"
        mkdir -p "$tmp_dir"

        if tar xzf "${CACHE_DIR}/${plugin_name}/${luci_name}" -C "$tmp_dir" 2>/dev/null; then
            if [ -f "$tmp_dir/data.tar.gz" ]; then
                tar xzf "$tmp_dir/data.tar.gz" -C / 2>/dev/null && luci_installed=1
            else
                tar xzf "${CACHE_DIR}/${plugin_name}/${luci_name}" -C / 2>/dev/null && luci_installed=1
            fi
        fi

        if [ -f "$tmp_dir/postinst" ]; then
            chmod +x "$tmp_dir/postinst"
            "$tmp_dir/postinst" 2>/dev/null || true
        fi

        rm -rf "$tmp_dir"
    fi

    if [ "$luci_installed" -eq 0 ]; then
        echo "[错误] LuCI 界面安装失败"
        return 1
    fi
    echo "[成功] LuCI 界面安装完成"

    # ----- 安装中文包 -----
    if [ -n "$i18n_name" ] && [ -f "${CACHE_DIR}/${plugin_name}/${i18n_name}" ]; then
        echo "[安装] 安装中文包..."
        if [ "$is_apk" -eq 1 ]; then
            if ! apk add --allow-untrusted --force-overwrite "${CACHE_DIR}/${plugin_name}/${i18n_name}" 2>/dev/null; then
                # 手动解压
                local tmp_dir="/tmp/daed-i18n-extract-$$"
                rm -rf "$tmp_dir"
                mkdir -p "$tmp_dir"
                if tar xzf "${CACHE_DIR}/${plugin_name}/${i18n_name}" -C "$tmp_dir" 2>/dev/null; then
                    [ -f "$tmp_dir/data.tar.gz" ] && tar xzf "$tmp_dir/data.tar.gz" -C / 2>/dev/null
                    tar xzf "${CACHE_DIR}/${plugin_name}/${i18n_name}" -C / 2>/dev/null
                fi
                rm -rf "$tmp_dir"
                echo "[成功] 中文包已安装"
            else
                echo "[成功] 中文包安装完成"
            fi
        else
            opkg install --force-overwrite "${CACHE_DIR}/${plugin_name}/${i18n_name}" 2>/dev/null || echo "[警告] 中文包安装失败"
        fi
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
