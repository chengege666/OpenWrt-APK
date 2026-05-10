#!/bin/sh
# core/install.sh - APK 安装模块

CACHE_DIR="/root/apk-store/cache"

detect_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64)
            echo "aarch64"
            ;;
        armv7l|armv6l)
            echo "arm"
            ;;
        mipsel)
            echo "mipsel"
            ;;
        mips)
            echo "mips"
            ;;
        riscv64)
            echo "riscv64"
            ;;
        *)
            echo "[错误] 不支持的架构: $arch"
            return 1
            ;;
    esac
}

download_apks() {
    local urls="$1"
    local cache_subdir="$2"

    if [ -z "$urls" ]; then
        echo "[错误] APK 链接列表为空"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${cache_subdir}"
    mkdir -p "$download_dir"

    echo "$urls" | while IFS= read -r url; do
        if [ -n "$url" ]; then
            local filename
            filename=$(basename "$url")
            local output="${download_dir}/${filename}"

            if [ -f "$output" ] && [ -s "$output" ]; then
                echo "[跳过] 已存在: $filename"
                continue
            fi

            wget -q --timeout=30 -O "$output" "$url" 2>/dev/null
            if [ -f "$output" ] && [ -s "$output" ]; then
                echo "[下载] $filename"
            else
                echo "[失败] $filename"
                rm -f "$output"
            fi
        fi
    done
}

install_apks() {
    local cache_subdir="$1"
    local download_dir="${CACHE_DIR}/${cache_subdir}"

    if [ ! -d "$download_dir" ]; then
        echo "[错误] 下载目录不存在: $download_dir"
        return 1
    fi

    local apk_count
    apk_count=$(find "$download_dir" -name "*.apk" 2>/dev/null | wc -l)

    if [ "$apk_count" -eq 0 ]; then
        echo "[错误] 未找到 APK 文件"
        return 1
    fi

    echo "[安装] 正在安装 $apk_count 个 APK..."

    cd "$download_dir" || return 1

    if apk add --allow-untrusted --force-overwrite *.apk 2>/dev/null; then
        echo "[成功] APK 安装完成"
        return 0
    else
        echo "[错误] APK 安装失败"
        return 1
    fi
}

fix_dependencies() {
    echo "[修复] 正在修复依赖关系..."

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    if [ "$is_apk" -eq 1 ]; then
        echo "[提示] 跳过自动修复（耗时较长），如有问题请手动执行: apk fix"
    else
        opkg update 2>/dev/null
        opkg install --force-reinstall $(opkg list-installed 2>/dev/null | cut -d' ' -f1) 2>/dev/null
    fi

    echo "[成功] 依赖修复完成"
}

restart_luci() {
    echo "[重启] 正在重启 LuCI 服务..."

    if command -v service >/dev/null 2>&1; then
        service rpcd restart 2>/dev/null
    fi

    if [ -f /etc/init.d/uhttpd ]; then
        /etc/init.d/uhttpd restart 2>/dev/null
    fi

    if [ -f /etc/init.d/nginx ]; then
        /etc/init.d/nginx restart 2>/dev/null
    fi

    echo "[成功] LuCI 已重启"
}

uninstall_plugin() {
    local plugin_name="$1"

    if [ -z "$plugin_name" ]; then
        echo "[错误] 插件名称为空"
        return 1
    fi

    echo "[卸载] 正在卸载: $plugin_name"

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    if [ "$is_apk" -eq 1 ]; then
        apk del "$plugin_name" 2>/dev/null
        apk del "luci-app-${plugin_name}" 2>/dev/null
        apk del "luci-i18n-${plugin_name}-zh-cn" 2>/dev/null
    else
        opkg remove "$plugin_name" 2>/dev/null
        opkg remove "luci-app-${plugin_name}" 2>/dev/null
        opkg remove "luci-i18n-${plugin_name}-zh-cn" 2>/dev/null
    fi

    echo "[成功] 卸载完成: $plugin_name"
}

cleanup_old_cache() {
    echo "[清理] 清理旧缓存..."
    rm -rf "${CACHE_DIR}"/*
    mkdir -p "$CACHE_DIR"
}
