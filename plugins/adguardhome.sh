#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块

# 修改建议：工作目录必须存放在可写且不与二进制冲突的位置
AGH_WORK_DIR="/etc/AdGuardHome"

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
    echo "================================"
    echo ""

    # 1. 预处理工作目录
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
        apk update && apk add --allow-untrusted adguardhome
    else
        opkg update && opkg install adguardhome
    fi

    echo "[步骤 2/3] 安装 LuCI 界面..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted luci-app-adguardhome luci-i18n-adguardhome-zh-cn
    else
        opkg install luci-app-adguardhome luci-i18n-adguardhome-zh-cn || install_adguardhome_luci_github "$is_apk"
    fi

    echo "[配置] 写入核心更新链接及初始化环境..."
    setup_adguardhome_links

    # 修正 LuCI 兼容层
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted luci-compat 2>/dev/null
    else
        opkg install luci-compat 2>/dev/null
    fi

    echo "[成功] AdGuardHome 安装完成"
    echo "提示：请在 LuCI 界面将'工作目录'设置为: $AGH_WORK_DIR"
    
    fix_dependencies
    restart_luci
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
    
    local pkg_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.${pkg_ext}$" | head -1)
    
    local download_dir="${CACHE_DIR}/adguardhome"
    mkdir -p "$download_dir"
    wget -q -O "${download_dir}/luci.pkg" "$pkg_url"
    
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite "${download_dir}/luci.pkg"
    else
        opkg install --force-overwrite "${download_dir}/luci.pkg"
    fi
}

setup_adguardhome_links() {
    # 确保配置文件目录存在
    mkdir -p /usr/share/AdGuardHome
    local link_file="/usr/share/AdGuardHome/links.txt"

    # 写入规范的 GitHub 下载链接
    cat <<EOF > "$link_file"
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_amd64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_arm64.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_armv7.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mipsle_softfloat.tar.gz
https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mips_softfloat.tar.gz
EOF

    echo "[配置] 默认下载链接已更新"
}

# 其他辅助函数 (uninstall_adguardhome, update_adguardhome 保持不变)