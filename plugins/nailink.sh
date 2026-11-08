#!/bin/sh
# plugins/nailink.sh - NaiLink 代理管理插件模块
# 来源: https://github.com/slobys/NaiLink

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

# 在发布清单中查找唯一匹配记录
# 参数: $1=manifest文件 $2=格式(apk) $3=架构 $4=包名
# 输出: 匹配行（TSV：格式 架构 包名 文件名 SHA256 版本）
_nailink_manifest_record() {
    awk -F '\t' -v fmt="$2" -v arch="$3" -v pkg="$4" '
        !/^#/ && NF==6 && $1==fmt && $2==arch && $3==pkg { line=$0; count++ }
        END { if (count!=1) exit 1; print line }' "$1"
}

install_nailink() {
    echo ""
    echo "================================"
    echo " 安装 NaiLink"
    echo "================================"
    echo ""

    _nailink_check_conflict || return 1

    command -v sha256sum >/dev/null 2>&1 || { echo "[错误] 缺少 sha256sum"; return 1; }

    local owner="slobys"
    local repo="NaiLink"
    local plugin_name="nailink"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    if [ -z "$tag" ]; then
        echo "[错误] 无法获取版本信息"
        return 1
    fi
    echo "[版本] $tag"

    local base_url="https://github.com/${owner}/${repo}/releases/download/${tag}"
    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    # 下载发布清单
    if ! download_file "${base_url}/manifest.tsv" "${download_dir}/manifest.tsv"; then
        echo "[错误] 发布清单下载失败"
        return 1
    fi
    if [ "$(head -n 1 "${download_dir}/manifest.tsv")" != "# daed-openwrt-manifest-v1" ]; then
        echo "[错误] 发布清单格式无法识别"
        return 1
    fi

    # CPU 类型（发布页提供 x86_64 / ARM64 / ARMv7 / MIPS32 / MIPSel32 包）
    local machine
    machine=$(uname -m)
    case "$machine" in
        x86_64|aarch64|armv7|armv7l|mips|mipsel|mipsle) ;;
        *)
            echo "[错误] 不支持的 CPU 架构: $machine"
            return 1
            ;;
    esac
    echo "[架构] $machine"

    # 读取 apk 接受的架构列表（/etc/apk/arch 优先，回退 apk --print-arch）
    local architectures=""
    if [ -r /etc/apk/arch ]; then
        architectures=$(awk 'NF {$1=$1; if (NF!=1 || $1 !~ /^[a-zA-Z0-9_+-]+$/) exit 1; print $1}' /etc/apk/arch) || {
            echo "[错误] /etc/apk/arch 内容无效"
            return 1
        }
    fi
    if [ -z "$architectures" ]; then
        architectures=$(apk --print-arch 2>/dev/null)
    fi
    if [ -z "$architectures" ]; then
        echo "[错误] 无法读取 apk 架构"
        return 1
    fi

    # 按官方映射逐个架构匹配 daed-router 运行时包（以固件原生架构为准）
    local runtime="" selected_arch=""
    local architecture
    for architecture in $architectures; do
        case "$machine:$architecture" in
            x86_64:x86_64) ;;
            aarch64:aarch64|aarch64:aarch64_*) ;;
            armv7:arm_cortex-a*|armv7l:arm_cortex-a*) ;;
            mips:mipsel_*|mipsel:mipsel_*|mipsle:mipsel_*) ;;
            mips:mips_*) ;;
            *) continue ;;
        esac
        runtime=$(_nailink_manifest_record "${download_dir}/manifest.tsv" apk "$architecture" daed-router)
        if [ -n "$runtime" ]; then
            selected_arch="$architecture"
            break
        fi
    done

    if [ -z "$selected_arch" ]; then
        echo "[错误] 发布页没有匹配本机架构的 daed-router 包（CPU: $machine，架构列表: $architectures）"
        return 1
    fi
    echo "[匹配] daed-router 架构: $selected_arch"

    # LuCI 界面包为 all 通用架构
    local plugin
    plugin=$(_nailink_manifest_record "${download_dir}/manifest.tsv" apk all luci-app-daed-router)
    if [ -z "$plugin" ]; then
        echo "[错误] 发布清单中未找到 luci-app-daed-router"
        return 1
    fi

    # 校验两个包版本一致
    local version
    version=$(printf '%s\n' "$runtime" | cut -f6)
    if [ "$version" != "$(printf '%s\n' "$plugin" | cut -f6)" ]; then
        echo "[错误] 运行时与 LuCI 包版本不一致"
        return 1
    fi

    local runtime_file plugin_file runtime_sum plugin_sum
    runtime_file=$(printf '%s\n' "$runtime" | cut -f4)
    runtime_sum=$(printf '%s\n' "$runtime" | cut -f5)
    plugin_file=$(printf '%s\n' "$plugin" | cut -f4)
    plugin_sum=$(printf '%s\n' "$plugin" | cut -f5)

    if ! download_file "${base_url}/${runtime_file}" "${download_dir}/${runtime_file}"; then
        echo "[错误] daed-router 下载失败"
        return 1
    fi
    if ! download_file "${base_url}/${plugin_file}" "${download_dir}/${plugin_file}"; then
        echo "[错误] luci-app-daed-router 下载失败"
        return 1
    fi

    # SHA-256 校验
    echo "[校验] 正在校验 SHA-256..."
    local actual
    actual=$(sha256sum "${download_dir}/${runtime_file}" 2>/dev/null | cut -d' ' -f1)
    if [ "$actual" != "$runtime_sum" ]; then
        echo "[错误] daed-router SHA-256 不匹配，已停止安装"
        return 1
    fi
    actual=$(sha256sum "${download_dir}/${plugin_file}" 2>/dev/null | cut -d' ' -f1)
    if [ "$actual" != "$plugin_sum" ]; then
        echo "[错误] luci-app-daed-router SHA-256 不匹配，已停止安装"
        return 1
    fi

    echo "[安装] 正在安装..."
    cd "$download_dir" || return 1
    if apk add --allow-untrusted --force-overwrite "$runtime_file" "$plugin_file" 2>/dev/null; then
        echo "[成功] APK 安装完成"
    else
        echo "[错误] APK 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[清理] 清除 LuCI 缓存..."
    rm -rf /tmp/luci-* 2>/dev/null

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo ""
    echo "[提示] 安装后请打开 LuCI：服务 → NaiLink"
    echo "[提示] 页面未更新请按 Ctrl+F5 刷新"
    show_success
    return 0
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

    # 先停止并禁用 daed 服务
    if [ -f /etc/init.d/daed ]; then
        echo "[停止] 正在停止 daed 服务..."
        /etc/init.d/daed stop 2>/dev/null || true
        /etc/init.d/daed disable 2>/dev/null || true
    fi

    echo "[卸载] 正在移除 NaiLink 包..."
    uninstall_plugin "daed-router"

    echo "[清理] 清理残留文件..."
    rm -rf /etc/daed 2>/dev/null
    rm -f /etc/config/daed /etc/config/daed.apk-new /etc/config/daed.opkg-dist 2>/dev/null
    rm -f /etc/init.d/daed /usr/bin/daed /usr/sbin/daed-router-setup /usr/sbin/nailink 2>/dev/null
    rm -rf /usr/libexec/daed /usr/share/daed-router 2>/dev/null
    rm -f /www/cgi-bin/daed-router 2>/dev/null
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null

    echo "[提示] 官方脚本的历史备份（如有）保留在 /root/daed-backups"

    echo "[重启] 重启 LuCI..."
    restart_luci

    echo "[成功] NaiLink 卸载完成"
    show_success
}

update_nailink() {
    echo ""
    echo "================================"
    echo " 更新 NaiLink"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_nailink
}
