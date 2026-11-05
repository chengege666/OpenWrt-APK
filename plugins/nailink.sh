#!/bin/sh
# plugins/nailink.sh - NaiLink 代理管理插件模块
# 来源: https://github.com/slobys/NaiLink

_NAILINK_INSTALLER_URLS_RAW="https://raw.githubusercontent.com/slobys/NaiLink/main/openwrt/install.sh https://github.com/slobys/NaiLink/raw/main/openwrt/install.sh"
# 官方入口会强制追加 --latest，仅用于安装/更新，不能用于卸载
_NAILINK_INSTALLER_URL_OFFICIAL="https://slobys.github.io/NaiLink/install.sh"
_NAILINK_INSTALLER_TMP="/tmp/nailink-install.sh"

# 判断包是否已安装（兼容 apk / opkg）
_nailink_pkg_installed() {
    local pkg="$1"
    [ -n "$pkg" ] || return 1

    if command -v apk >/dev/null 2>&1 && apk info -e "$pkg" >/dev/null 2>&1; then
        return 0
    fi
    if command -v opkg >/dev/null 2>&1 && opkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
        return 0
    fi
    return 1
}

# 下载官方安装脚本（Raw 入口失败自动回退）
# 参数 $2: 1 = 允许回退官方入口（该入口会追加 --latest，仅限安装/更新）
_nailink_download_installer() {
    local output="$1"
    local allow_official="${2:-0}"
    local urls="$_NAILINK_INSTALLER_URLS_RAW"
    local url tool

    [ -n "$output" ] || return 1
    if [ "$allow_official" = 1 ]; then
        urls="$urls $_NAILINK_INSTALLER_URL_OFFICIAL"
    fi

    for url in $urls; do
        for tool in curl uclient-fetch wget; do
            command -v "$tool" >/dev/null 2>&1 || continue
            rm -f "$output"
            case "$tool" in
                curl)
                    curl -fL --proto '=https' --proto-redir '=https' \
                        --connect-timeout 15 --max-time 60 \
                        -o "$output" "$url" 2>/dev/null || true
                    ;;
                uclient-fetch)
                    uclient-fetch -T 60 -O "$output" "$url" >/dev/null 2>&1 || true
                    ;;
                wget)
                    wget -q --timeout=30 -O "$output" "$url" 2>/dev/null || true
                    ;;
            esac
            if [ -s "$output" ]; then
                echo "[下载] 安装脚本来源: $url"
                return 0
            fi
        done
    done

    rm -f "$output"
    return 1
}

# 检测与 Daed / Daede 的包冲突（互斥，不能共存）
_nailink_check_conflict() {
    if _nailink_pkg_installed "daed" || _nailink_pkg_installed "luci-app-daed"; then
        echo "[错误] 检测到已安装 Daed / Daede（daed 或 luci-app-daed）"
        echo "[提示] NaiLink 与 Daed / Daede 互斥，无法共存"
        echo "[提示] 请先在 卸载插件 菜单中卸载 Daed(10) 或 Daede(23)，再安装 NaiLink"
        return 1
    fi
    return 0
}

install_nailink() {
    echo ""
    echo "================================"
    echo " 安装 NaiLink"
    echo "================================"
    echo ""

    _nailink_check_conflict || return 1

    echo "[提示] 官方脚本会自动检测架构、内核能力与依赖，不兼容时会停止安装"
    echo "[安装] 正在获取官方安装脚本..."

    if ! _nailink_download_installer "$_NAILINK_INSTALLER_TMP" 1; then
        echo "[错误] 安装脚本下载失败，请检查网络或路由器 DNS"
        return 1
    fi

    if ! sh -n "$_NAILINK_INSTALLER_TMP" 2>/dev/null; then
        echo "[错误] 下载的安装脚本校验失败"
        rm -f "$_NAILINK_INSTALLER_TMP"
        return 1
    fi

    if sh "$_NAILINK_INSTALLER_TMP" --install --latest; then
        rm -f "$_NAILINK_INSTALLER_TMP"
        echo "[成功] NaiLink 安装完成"
        echo ""
        echo "[提示] 安装后请打开 LuCI：服务 → NaiLink"
        echo "[提示] 页面未更新请按 Ctrl+F5 刷新"
        restart_luci
        show_success
        return 0
    fi

    rm -f "$_NAILINK_INSTALLER_TMP"
    echo "[错误] NaiLink 安装失败，请查看上方日志"
    return 1
}

uninstall_nailink() {
    echo ""
    echo "================================"
    echo " 卸载 NaiLink"
    echo "================================"
    echo ""

    if ! _nailink_pkg_installed "daed-router" && ! _nailink_pkg_installed "luci-app-daed-router"; then
        echo "[提示] 未检测到 NaiLink 安装包，可能已卸载"
    fi

    echo "[备份] 官方脚本会先备份到 /root/daed-backups，再删除插件和配置"

    local installer=""
    if [ -s "$_NAILINK_INSTALLER_TMP" ] && sh -n "$_NAILINK_INSTALLER_TMP" 2>/dev/null; then
        installer="$_NAILINK_INSTALLER_TMP"
    elif _nailink_download_installer "$_NAILINK_INSTALLER_TMP"; then
        installer="$_NAILINK_INSTALLER_TMP"
    fi

    if [ -z "$installer" ]; then
        echo "[错误] 无法获取官方安装脚本，卸载未执行"
        echo "[提示] 可联网时手动执行 nailink，选择 2 卸载"
        return 1
    fi

    if sh "$installer" --uninstall; then
        rm -f "$_NAILINK_INSTALLER_TMP"
        echo "[成功] NaiLink 卸载完成"
        echo "[提示] 备份文件位于 /root/daed-backups"
        restart_luci
        show_success
        return 0
    fi

    rm -f "$_NAILINK_INSTALLER_TMP"
    echo "[错误] NaiLink 卸载失败，请查看上方日志"
    return 1
}

update_nailink() {
    echo ""
    echo "================================"
    echo " 更新 NaiLink"
    echo "================================"
    echo ""

    _nailink_check_conflict || return 1

    echo "[更新] 正在获取官方安装脚本（保留节点、订阅和配置）..."

    if ! _nailink_download_installer "$_NAILINK_INSTALLER_TMP" 1; then
        echo "[错误] 安装脚本下载失败，请检查网络或路由器 DNS"
        return 1
    fi

    if ! sh -n "$_NAILINK_INSTALLER_TMP" 2>/dev/null; then
        echo "[错误] 下载的安装脚本校验失败"
        rm -f "$_NAILINK_INSTALLER_TMP"
        return 1
    fi

    if sh "$_NAILINK_INSTALLER_TMP" --install --latest; then
        rm -f "$_NAILINK_INSTALLER_TMP"
        echo "[成功] NaiLink 更新完成"
        restart_luci
        show_success
        return 0
    fi

    rm -f "$_NAILINK_INSTALLER_TMP"
    echo "[错误] NaiLink 更新失败，请查看上方日志"
    return 1
}
