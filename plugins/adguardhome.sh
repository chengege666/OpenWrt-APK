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

    echo "[步骤 1/3] 从系统软件源安装核心..."
    if [ "$is_apk" -eq 1 ]; then
        apk update && apk add --allow-untrusted adguardhome || {
            echo "[错误] AdGuardHome 核心安装失败"
            return 1
        }
    else
        opkg update && opkg install adguardhome || {
            echo "[错误] AdGuardHome 核心安装失败"
            return 1
        }
    fi

    echo "[步骤 2/3] 安装 LuCI 界面..."
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

    echo "[步骤 3/3] 配置核心更新链接及初始化环境..."
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

install_adguardhome_luci_github() {
    local is_apk="$1"
    local owner="stevenjoezhang"
    local repo="luci-app-adguardhome"
    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local all_urls
    all_urls=$(get_download_urls "$release_json")
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

    echo "[下载] 主包: $pkg_url"
    if wget -q --timeout=60 -O "${download_dir}/luci-main.pkg" "$pkg_url" 2>/dev/null; then
        if [ -f "${download_dir}/luci-main.pkg" ] && [ -s "${download_dir}/luci-main.pkg" ]; then
            echo "[成功] 主包下载完成"
        else
            echo "[错误] 主包下载文件为空"
            rm -f "${download_dir}/luci-main.pkg"
            return 1
        fi
    else
        echo "[错误] 主包下载失败"
        rm -f "${download_dir}/luci-main.pkg"
        return 1
    fi

    if [ -n "$i18n_url" ]; then
        echo "[下载] 中文包: $i18n_url"
        if wget -q --timeout=60 -O "${download_dir}/luci-i18n.pkg" "$i18n_url" 2>/dev/null; then
            if [ -f "${download_dir}/luci-i18n.pkg" ] && [ -s "${download_dir}/luci-i18n.pkg" ]; then
                echo "[成功] 中文包下载完成"
            else
                echo "[警告] 中文包下载文件为空，将只安装主包"
                rm -f "${download_dir}/luci-i18n.pkg"
                i18n_url=""
            fi
        else
            echo "[警告] 中文包下载失败，将只安装主包"
            rm -f "${download_dir}/luci-i18n.pkg"
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
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_amd64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_arm64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_armv7.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mipsle_softfloat.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mips_softfloat.tar.gz
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