#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块

AGH_WORK_DIR="/etc/AdGuardHome"

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
    echo "================================"
    echo ""

    mkdir -p "$AGH_WORK_DIR"
    chmod 755 "$AGH_WORK_DIR"

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    echo "[步骤 1/2] 安装 LuCI 界面..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted luci-app-adguardhome luci-i18n-adguardhome-zh-cn 2>/dev/null || {
            echo "[警告] LuCI 界面安装失败，尝试从 GitHub 安装..."
            install_adguardhome_luci_github "$is_apk" || echo "[错误] LuCI 界面安装失败"
        }
    else
        opkg install luci-app-adguardhome luci-i18n-adguardhome-zh-cn 2>/dev/null || {
            echo "[警告] LuCI 界面安装失败，尝试从 GitHub 安装..."
            install_adguardhome_luci_github "$is_apk" || echo "[错误] LuCI 界面安装失败"
        }
    fi

    echo "[步骤 2/2] 配置核心更新链接及初始化环境..."
    setup_adguardhome_links || echo "[警告] 链接配置失败"

    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted luci-compat 2>/dev/null
    else
        opkg install luci-compat 2>/dev/null
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] AdGuardHome 安装完成"
    echo ""
    echo "=========================================="
    echo " 重要提示"
    echo "=========================================="
    echo "请在 LuCI 界面将以下设置修改为："
    echo "  Work dir (工作目录): /etc/AdGuardHome"
    echo "  Config path (配置路径): /etc/AdGuardHome.yaml"
    echo "=========================================="
    echo ""
    echo "注意：/usr/bin/AdGuardHome 是只读目录，不可用作工作目录！"
    echo ""

    show_success
}

install_adguardhome_core_github() {
    local arch="$1"

    echo "[下载] 正在下载 AdGuardHome v0.107.74..."

    local download_url=""
    case "$arch" in
        x86_64)
            download_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_amd64.tar.gz"
            ;;
        aarch64)
            download_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_arm64.tar.gz"
            ;;
        arm)
            download_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_armv7.tar.gz"
            ;;
        mipsel)
            download_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_mipsle_softfloat.tar.gz"
            ;;
        mips)
            download_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_mips_softfloat.tar.gz"
            ;;
        *)
            echo "[错误] 不支持的架构: $arch"
            return 1
            ;;
    esac

    if [ -z "$download_url" ]; then
        echo "[错误] 未找到适合 $arch 架构的下载链接"
        return 1
    fi

    local download_dir="${CACHE_DIR}/adguardhome/core"
    mkdir -p "$download_dir"

    local tar_file="${download_dir}/AdGuardHome.tar.gz"
    if ! download_file "$download_url" "$tar_file"; then
        echo "[错误] 下载失败"
        return 1
    fi

    echo "[解压] 正在解压..."
    local extract_dir="${download_dir}/extracted"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    if tar -xzf "$tar_file" -C "$extract_dir" 2>/dev/null; then
        echo "[成功] 解压完成"
    else
        echo "[错误] 解压失败"
        rm -rf "$extract_dir"
        return 1
    fi

    echo "[安装] 正在安装二进制文件..."
    local bin_dir="$extract_dir/AdGuardHome"
    if [ ! -f "${bin_dir}/AdGuardHome" ]; then
        bin_dir=$(find "$extract_dir" -name "AdGuardHome" -type f 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
    fi

    if [ -z "$bin_dir" ] || [ ! -f "${bin_dir}/AdGuardHome" ]; then
        echo "[错误] 未找到 AdGuardHome 二进制文件"
        rm -rf "$extract_dir"
        return 1
    fi

    mkdir -p /usr/bin/AdGuardHome
    cp -f "${bin_dir}/AdGuardHome" /usr/bin/AdGuardHome/AdGuardHome
    chmod +x /usr/bin/AdGuardHome/AdGuardHome

    if [ -f /usr/bin/AdGuardHome/AdGuardHome ]; then
        echo "[成功] 二进制文件安装完成"
    else
        echo "[错误] 二进制文件安装失败"
        rm -rf "$extract_dir"
        return 1
    fi

    rm -rf "$extract_dir"
    rm -f "$tar_file"

    echo "[配置] 创建初始化脚本..."
    cat > /etc/init.d/adguardhome << 'INITEOF'
#!/bin/sh /etc/rc.common
START=95

start() {
    /usr/bin/AdGuardHome/AdGuardHome -w /etc/AdGuardHome -h 0.0.0.0 -p 3000 &
}

stop() {
    killall AdGuardHome 2>/dev/null
}

restart() {
    stop
    sleep 2
    start
}

enable() {
    mkdir -p /etc/rc.d
    ln -sf ../init.d/adguardhome /etc/rc.d/S95adguardhome 2>/dev/null
}

disable() {
    rm -f /etc/rc.d/S95adguardhome 2>/dev/null
}
INITEOF
    chmod +x /etc/init.d/adguardhome

    echo "[成功] AdGuardHome 核心安装完成"
}

install_adguardhome_luci_github() {
    local is_apk="$1"
    local owner="stevenjoezhang"
    local repo="luci-app-adguardhome"
    local tag="v0.107.74"
    local release_url="https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}"

    echo "[下载] 正在获取 LuCI 界面 ${tag}..."

    local release_json
    release_json=$(_fetch_github_api "$release_url" "LuCI AdGuardHome: $tag") || {
        echo "[错误] 获取 Release 信息失败: $tag"
        return 1
    }

    local all_urls
    all_urls=$(echo "$release_json" | grep -o '"browser_download_url":"[^"]*"' | sed 's/"browser_download_url":"//;s/"//')
    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local pkg_url
    pkg_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.${pkg_ext}$" | grep -iv "i18n" | head -1)

    if [ -z "$pkg_url" ]; then
        echo "[错误] 未找到合适的 LuCI 主包"
        return 1
    fi

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*i18n.*zh-cn.*\.${pkg_ext}$" | head -1)

    local download_dir="${CACHE_DIR}/adguardhome"
    mkdir -p "$download_dir"

    if ! download_file "$pkg_url" "${download_dir}/luci-main.pkg"; then
        echo "[错误] 主包下载失败"
        return 1
    fi

    if [ -n "$i18n_url" ]; then
        if ! download_file "$i18n_url" "${download_dir}/luci-i18n.pkg"; then
            echo "[警告] 中文包下载失败，将只安装主包"
            i18n_url=""
        fi
    else
        echo "[警告] 未找到中文包，将只安装主包"
    fi

    echo "[安装] 正在安装 LuCI 界面..."
    if [ "$is_apk" -eq 1 ]; then
        if [ -n "$i18n_url" ]; then
            apk add --allow-untrusted --force-overwrite "${download_dir}/luci-main.pkg" "${download_dir}/luci-i18n.pkg" 2>/dev/null || return 1
        else
            apk add --allow-untrusted --force-overwrite "${download_dir}/luci-main.pkg" 2>/dev/null || return 1
        fi
    else
        if [ -n "$i18n_url" ]; then
            opkg install --force-overwrite "${download_dir}/luci-main.pkg" "${download_dir}/luci-i18n.pkg" 2>/dev/null || return 1
        else
            opkg install --force-overwrite "${download_dir}/luci-main.pkg" 2>/dev/null || return 1
        fi
    fi

    echo "[成功] LuCI 界面安装完成"
}

setup_adguardhome_links() {
    mkdir -p /usr/share/AdGuardHome

    if [ ! -d /usr/share/AdGuardHome ]; then
        echo "[错误] 无法创建链接配置目录"
        return 1
    fi

    local link_file="/usr/share/AdGuardHome/links.txt"

    cat <<EOF > "$link_file"
https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_amd64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_arm64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_armv7.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_mipsle_softfloat.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_mips_softfloat.tar.gz
EOF

    echo "[配置] 默认下载链接已更新"
}

uninstall_adguardhome() {
    echo ""
    echo "================================"
    echo " 卸载 AdGuardHome"
    echo "================================"
    echo ""

    echo "[停止] 停止 AdGuardHome 服务..."
    if [ -f /etc/init.d/adguardhome ]; then
        /etc/init.d/adguardhome stop 2>/dev/null
        /etc/init.d/adguardhome disable 2>/dev/null
    fi

    echo "[卸载] 正在卸载 AdGuardHome..."
    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    if [ "$is_apk" -eq 1 ]; then
        apk del adguardhome 2>/dev/null
        apk del luci-app-adguardhome 2>/dev/null
        apk del luci-i18n-adguardhome-zh-cn 2>/dev/null
    else
        opkg remove adguardhome 2>/dev/null
        opkg remove luci-app-adguardhome 2>/dev/null
        opkg remove luci-i18n-adguardhome-zh-cn 2>/dev/null
    fi

    echo "[清理] 清理工作目录..."
    rm -rf "$AGH_WORK_DIR"
    rm -rf /usr/share/AdGuardHome
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_adguardhome() {
    echo ""
    echo "================================"
    echo " 更新 AdGuardHome"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_adguardhome
}