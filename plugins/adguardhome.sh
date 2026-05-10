#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块

install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
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

    local pm
    [ "$is_apk" -eq 1 ] && pm="apk" || pm="opkg"

    echo "[步骤 1/3] 从系统软件源安装核心..."
    if [ "$is_apk" -eq 1 ]; then
        apk update 2>/dev/null
    else
        opkg update 2>/dev/null
    fi

    local core_installed=0
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted adguardhome 2>&1 | tail -3
        if apk list --installed 2>/dev/null | grep -q "adguardhome"; then
            core_installed=1
        fi
    else
        opkg install adguardhome 2>&1 | tail -3
        if opkg list-installed 2>/dev/null | grep -q "adguardhome"; then
            core_installed=1
        fi
    fi

    if [ "$core_installed" -eq 0 ]; then
        echo "[错误] AdGuardHome 核心安装失败"
        return 1
    fi
    echo "[核心] AdGuardHome 已安装"

    echo "[步骤 2/3] 从系统软件源安装 LuCI 界面..."
    local luci_installed=0
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted luci-app-adguardhome luci-i18n-adguardhome-zh-cn 2>&1 | tail -3
        if apk list --installed 2>/dev/null | grep -q "luci-app-adguardhome"; then
            luci_installed=1
        fi
    else
        opkg install luci-app-adguardhome luci-i18n-adguardhome-zh-cn 2>&1 | tail -3
        if opkg list-installed 2>/dev/null | grep -q "luci-app-adguardhome"; then
            luci_installed=1
        fi
    fi

    if [ "$luci_installed" -eq 0 ]; then
        echo "[步骤 3/3] 系统源中无 LuCI 界面，从 GitHub 下载..."
        install_adguardhome_luci_github "$is_apk"
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi

    echo "[配置] 写入核心更新链接..."
    setup_adguardhome_links

    echo "[修复] 安装 LuCI 兼容层..."
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted luci-compat 2>&1 | tail -3
    else
        opkg install luci-compat 2>&1 | tail -3
    fi

    echo "[成功] AdGuardHome 安装完成"
    fix_dependencies
    restart_luci
    show_success
}

install_adguardhome_luci_github() {
    local is_apk="$1"

    local owner="stevenjoezhang"
    local repo="luci-app-adguardhome"
    local plugin_name="adguardhome"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local pkg_url
    pkg_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.${pkg_ext}$" | head -1)

    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn.*\.${pkg_ext}$" | head -1)

    if [ -z "$pkg_url" ]; then
        pkg_url=$(echo "$all_urls" | grep "luci-app-adguardhome.*\.\(apk\|ipk\)$" | head -1)
        i18n_url=$(echo "$all_urls" | grep "luci-i18n-adguardhome-zh-cn.*\.\(apk\|ipk\)$" | head -1)
    fi

    if [ -z "$pkg_url" ]; then
        echo "[错误] 未找到 LuCI 界面安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    mkdir -p "$download_dir"

    echo "[下载] luci-app-adguardhome.${pkg_ext}"
    if ! wget -q --timeout=60 -O "${download_dir}/luci-app-adguardhome.${pkg_ext}" "$pkg_url" 2>/dev/null; then
        echo "[错误] 下载失败"
        return 1
    fi

    if [ -n "$i18n_url" ]; then
        echo "[下载] luci-i18n-adguardhome-zh-cn.${pkg_ext}"
        wget -q --timeout=60 -O "${download_dir}/luci-i18n-adguardhome-zh-cn.${pkg_ext}" "$i18n_url" 2>/dev/null
    fi

    echo "[安装] 安装 LuCI 界面..."
    cd "$download_dir" || return 1
    if [ "$is_apk" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite --force-non-repository *.apk 2>&1 || {
            echo "[错误] 安装失败"
            return 1
        }
    else
        opkg install --force-overwrite *.ipk 2>&1 || {
            echo "[错误] 安装失败"
            return 1
        }
    fi

    echo "[界面] LuCI 界面安装完成"
}

setup_adguardhome_links() {
    local link_file="/usr/share/AdGuardHome/links.txt"
    mkdir -p /usr/share/AdGuardHome 2>/dev/null

    local arch
    arch=$(detect_arch) || return 1

    case "$arch" in
        x86_64)
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_amd64.tar.gz" > "$link_file"
            ;;
        aarch64)
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_arm64.tar.gz" > "$link_file"
            ;;
        arm)
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_armv7.tar.gz" > "$link_file"
            ;;
        mipsel)
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mipsle_softfloat.tar.gz" > "$link_file"
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mipsle_hardfloat.tar.gz" >> "$link_file"
            ;;
        mips)
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mips_softfloat.tar.gz" > "$link_file"
            echo "https://github.com/AdguardTeam/AdGuardHome/releases/download/{version}/AdGuardHome_linux_mips_hardfloat.tar.gz" >> "$link_file"
            ;;
    esac

    echo "[核心] 更新链接已写入: $link_file"
}

uninstall_adguardhome() {
    echo ""
    echo "================================"
    echo " 卸载 AdGuardHome"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-adguardhome"
    uninstall_plugin "adguardhome"
    uninstall_plugin "luci-i18n-adguardhome-zh-cn"

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
