#!/bin/sh
# plugins/honk.sh - honk 代理引擎插件模块
# 来源: https://github.com/daeuniverse/honk
# 官方 OpenWrt 安装说明: https://daeuniverse.org/openwrt/

_HONK_FEED_BASE="https://openwrt.daeuniverse.org"
_HONK_FEED_KEY="/etc/apk/keys/daeuniverse.pem"
_HONK_FEED_LIST="/etc/apk/repositories.d/daeuniverse.list"

# 通用下载：curl -> wget -> uclient-fetch
_honk_fetch_file() {
    local url="$1"
    local output="$2"
    local tool

    [ -n "$url" ] && [ -n "$output" ] || return 1

    for tool in curl wget uclient-fetch; do
        command -v "$tool" >/dev/null 2>&1 || continue
        rm -f "$output"
        case "$tool" in
            curl)
                curl -fL --proto '=https' --proto-redir '=https' \
                    --connect-timeout 15 --max-time 60 \
                    -o "$output" "$url" 2>/dev/null || true
                ;;
            wget)
                wget -q --timeout=30 -O "$output" "$url" 2>/dev/null || true
                ;;
            uclient-fetch)
                uclient-fetch -T 60 -O "$output" "$url" >/dev/null 2>&1 || true
                ;;
        esac
        if [ -s "$output" ]; then
            return 0
        fi
    done

    rm -f "$output"
    return 1
}

# 版本比较：仅接受 25.12 及以上
_honk_version_ok() {
    awk -v v="$1" 'BEGIN {
        split(v, a, ".")
        if (a[1] !~ /^[0-9]+$/ || a[2] !~ /^[0-9]+$/) exit 1
        if (a[1]+0 > 25) exit 0
        if (a[1]+0 < 25) exit 1
        if (a[2]+0 >= 12) exit 0
        exit 1
    }'
}

_honk_check_env() {
    . /etc/openwrt_release 2>/dev/null

    if ! command -v apk >/dev/null 2>&1; then
        echo "[错误] honk 仅支持 apk 包管理器（OpenWrt 25.12+），当前系统不适用"
        return 1
    fi
    if [ -z "$DISTRIB_RELEASE" ] || [ -z "$DISTRIB_ARCH" ] || [ -z "$DISTRIB_TARGET" ]; then
        echo "[错误] 无法读取系统版本信息 /etc/openwrt_release"
        return 1
    fi
    if ! _honk_version_ok "$DISTRIB_RELEASE"; then
        echo "[错误] honk 要求 OpenWrt 25.12+，当前版本: $DISTRIB_RELEASE"
        return 1
    fi

    case "$DISTRIB_ARCH" in
        x86_64|aarch64_generic|aarch64_cortex-a53|aarch64_cortex-a72|aarch64_cortex-a76)
            ;;
        *)
            echo "[错误] daeuniverse 软件源不支持当前架构: $DISTRIB_ARCH"
            echo "[提示] 仅提供 x86_64 与指定 aarch64 架构，不含 32 位 ARM / MIPS"
            return 1
            ;;
    esac

    return 0
}

# honk 与 dae / daed（含 NaiLink）不能同时运行
_honk_check_running() {
    if pidof dae >/dev/null 2>&1 || pidof daed >/dev/null 2>&1; then
        echo "[错误] 检测到 dae / daed 正在运行（含 NaiLink）"
        echo "[提示] honk 与 dae/daed 不能同时运行"
        echo "[提示] 请先停止并禁用对应服务后再安装 honk"
        return 1
    fi
    return 0
}

# 导入 daeuniverse 软件源签名公钥
_honk_import_key() {
    mkdir -p /etc/apk/keys || return 1

    echo "[软件源] 正在导入签名公钥..."
    if ! _honk_fetch_file "${_HONK_FEED_BASE}/public-key.pem" "$_HONK_FEED_KEY"; then
        echo "[错误] 公钥下载失败，请检查网络"
        return 1
    fi

    chmod 644 "$_HONK_FEED_KEY" 2>/dev/null
    if ! grep -q "BEGIN PUBLIC KEY" "$_HONK_FEED_KEY" 2>/dev/null; then
        echo "[错误] 公钥内容无效"
        rm -f "$_HONK_FEED_KEY"
        return 1
    fi

    echo "[成功] 公钥已导入: $_HONK_FEED_KEY"
    return 0
}

# 写入 @daeuniverse 软件源（官方 OpenWrt 无 BTF 时追加 kmods 源）
_honk_write_repo() {
    local base pkg_url kmods_url

    . /etc/openwrt_release 2>/dev/null
    base="${_HONK_FEED_BASE}/$(echo "$DISTRIB_RELEASE" | cut -d. -f1-2)"
    pkg_url="${base}/packages/${DISTRIB_ARCH}/packages.adb"

    mkdir -p /etc/apk/repositories.d || return 1
    if ! printf '@daeuniverse %s\n' "$pkg_url" > "$_HONK_FEED_LIST"; then
        echo "[错误] 无法写入软件源文件: $_HONK_FEED_LIST"
        return 1
    fi

    if [ ! -e /sys/kernel/btf/vmlinux ]; then
        kmods_url="${base}/kmods/${DISTRIB_RELEASE}/${DISTRIB_TARGET}/packages.adb"
        if command -v wget >/dev/null 2>&1 && \
           ! wget -q --spider --timeout=15 "$kmods_url" 2>/dev/null; then
            echo "[警告] 未找到 ${DISTRIB_RELEASE}/${DISTRIB_TARGET} 的 kmods 源"
            echo "[提示] 若内核未自带 BTF，安装会因缺少 vmlinux-btf 失败"
        else
            printf '@daeuniverse %s\n' "$kmods_url" >> "$_HONK_FEED_LIST"
        fi
    fi

    echo "[软件源] 已写入: $_HONK_FEED_LIST"
    return 0
}

# 启用并启动 honk 服务
_honk_enable_service() {
    if [ ! -x /etc/init.d/honk ]; then
        echo "[警告] 未找到 /etc/init.d/honk，请稍后手动启用服务"
        return 1
    fi

    uci set honk.config.enabled=1 2>/dev/null
    uci commit honk 2>/dev/null
    /etc/init.d/honk enable 2>/dev/null
    /etc/init.d/honk start 2>/dev/null

    if pidof honk-core >/dev/null 2>&1 || pidof honk >/dev/null 2>&1; then
        echo "[成功] honk 服务已启动"
    else
        echo "[提示] honk 服务未运行，请打开 LuCI 服务 → honk 检查配置"
    fi
    return 0
}

install_honk() {
    echo ""
    echo "================================"
    echo " 安装 Honk"
    echo "================================"
    echo ""

    _honk_check_env || return 1
    _honk_check_running || return 1
    _honk_import_key || return 1
    _honk_write_repo || return 1

    echo "[软件源] 正在更新软件源索引..."
    apk update 2>/dev/null || echo "[警告] apk update 失败，继续尝试安装"

    echo "[安装] 正在安装 honk 与 luci-app-honk..."
    if ! apk add "honk@daeuniverse" "luci-app-honk@daeuniverse"; then
        echo "[错误] honk 安装失败"
        echo "[提示] 常见原因：内核低于 6.12、缺少 vmlinux-btf、软件源不可访问"
        return 1
    fi

    _honk_enable_service

    echo ""
    echo "[提示] doona 面板: http://路由器LAN地址:9527/"
    echo "[提示] 首次访问需创建管理员账号，使用 IP 访问不要用域名"
    echo "[提示] 默认配置使用 br-lan，如 LAN 接口不同请先在 LuCI 中修改"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
    return 0
}

uninstall_honk() {
    echo ""
    echo "================================"
    echo " 卸载 Honk"
    echo "================================"
    echo ""

    if [ -x /etc/init.d/honk ]; then
        echo "[停止] 停止 honk 服务..."
        /etc/init.d/honk stop 2>/dev/null || true
        /etc/init.d/honk disable 2>/dev/null || true
    fi

    echo "[卸载] 移除 luci-app-honk..."
    apk del luci-app-honk 2>/dev/null || true
    echo "[卸载] 移除 honk..."
    apk del honk 2>/dev/null || true

    if apk info -e honk >/dev/null 2>&1; then
        echo "[错误] honk 包仍存在，卸载未完成"
        return 1
    fi

    if apk info -e dae >/dev/null 2>&1 || apk info -e luci-app-dae >/dev/null 2>&1; then
        echo "[提示] 仍安装有 daeuniverse 软件包，保留软件源与公钥"
    else
        echo "[清理] 移除 daeuniverse 软件源与公钥..."
        rm -f "$_HONK_FEED_LIST"
        rm -f "$_HONK_FEED_KEY"
    fi

    echo "[提示] 配置目录 /etc/honk 已保留，如需彻底清理请手动删除"

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] Honk 卸载完成"
}

update_honk() {
    echo ""
    echo "================================"
    echo " 更新 Honk"
    echo "================================"
    echo ""

    _honk_check_env || return 1

    if ! apk info -e honk >/dev/null 2>&1; then
        echo "[错误] 未检测到已安装的 honk，请先安装"
        return 1
    fi

    _honk_import_key || return 1
    _honk_write_repo || return 1

    echo "[软件源] 正在更新软件源索引..."
    apk update 2>/dev/null || echo "[警告] apk update 失败，继续尝试升级"

    local pkgs="honk"
    apk info -e luci-app-honk >/dev/null 2>&1 && pkgs="$pkgs luci-app-honk"

    echo "[更新] 正在升级 honk..."
    if ! apk upgrade $pkgs; then
        echo "[错误] honk 升级失败"
        return 1
    fi

    if [ -x /etc/init.d/honk ] && /etc/init.d/honk enabled >/dev/null 2>&1; then
        echo "[重启] 重启 honk 服务..."
        /etc/init.d/honk restart 2>/dev/null || true
    fi

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] Honk 更新完成"
}
