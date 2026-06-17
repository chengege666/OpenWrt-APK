#!/bin/sh
# plugins/daed.sh - luci-app-daed (大鹅) 插件模块

install_daed_deps() {
    echo "[依赖] 检查 Daed 运行依赖..."

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac

    # daed 官方声明的运行时依赖
    local pkgs="ca-bundle curl zoneinfo-asia luci-compat"
    # 内核模块（需匹配运行内核）
    local kmods="kmod-sched-core kmod-sched-bpf kmod-veth"
    # GeoIP/GeoSite（.run 包内置，但以防万一也从源安装）
    local geos="v2ray-geoip v2ray-geosite"

    if [ "$is_apk" -eq 1 ]; then
        echo "[依赖] APK 系统，更新源索引..."
        apk update 2>/dev/null
        echo "[依赖] 安装系统依赖包..."
        apk add --allow-untrusted $pkgs $kmods $geos 2>/dev/null || true

        if modprobe nft_tproxy 2>/dev/null; then
            echo "[依赖] nft_tproxy 模块已加载"
            echo "nft_tproxy" >> /etc/modules.d/nft-tproxy.conf 2>/dev/null
        fi
    else
        echo "[依赖] OPKG 系统，更新源索引..."
        opkg update 2>/dev/null
        echo "[依赖] 安装系统依赖包..."
        opkg install $pkgs $kmods $geos 2>/dev/null || true
    fi

    echo "[依赖] 尝试加载内核模块..."
    for m in sched-core sched-bpf veth; do
        modprobe "$m" 2>/dev/null && echo "[依赖] $m 已加载" || echo "[提示] $m 模块不可用（若内核不支持可忽略）"
    done

    echo "[依赖] 依赖检查完成"
}

install_daed() {
    echo ""
    echo "================================"
    echo " 安装 Daed (大鹅)"
    echo "================================"
    echo ""

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    echo "[系统] OpenWrt $DISTRIB_RELEASE ($([ "$is_apk" -eq 1 ] && echo 'APK' || echo 'OPKG'))"

    local arch
    arch=$(detect_arch) || return 1
    echo "[架构] $arch"

    case "$arch" in
        x86_64|aarch64)
            ;;
        *)
            echo "[错误] Daed 目前仅支持 x86_64 和 aarch64 架构"
            return 1
            ;;
    esac

    install_daed_deps

    local owner="wkccd"
    local repo="luci-app-daed-runfiles"
    local plugin_name="daed"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    # 选择对应版本前缀: 24.10 选 24-, 25.12/snapshot 选 25-
    local ver_prefix="24"
    [ "$is_apk" -eq 1 ] && ver_prefix="25"

    # 架构映射
    local run_arch
    case "$arch" in
        x86_64) run_arch="x86-64" ;;
        aarch64) run_arch="aarch64_generic" ;;
    esac

    # 查找匹配的 .run 文件
    local run_url
    run_url=$(echo "$all_urls" | grep "${ver_prefix}-luci-app-dead" | grep "${run_arch}\.run$" | head -1)

    # aarch64 通用没找到则尝试 cortex-a53
    if [ -z "$run_url" ] && [ "$arch" = "aarch64" ]; then
        echo "[重试] 未找到 aarch64_generic，尝试 aarch64_cortex-a53..."
        run_url=$(echo "$all_urls" | grep "${ver_prefix}-luci-app-dead" | grep "aarch64_cortex-a53\.run$" | head -1)
        if [ -n "$run_url" ]; then
            run_arch="aarch64_cortex-a53"
        fi
    fi

    if [ -z "$run_url" ]; then
        echo "[错误] 未找到匹配架构 ${arch} 的安装包"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "${download_dir}/extracted"

    local run_name
    run_name=$(basename "$run_url")
    echo "[下载] $run_name"

    if ! download_file "$run_url" "${download_dir}/${run_name}"; then
        echo "[错误] 下载失败"
        return 1
    fi

    echo "[解压] 正在解压安装包（makeself 自解压）..."
    chmod +x "${download_dir}/${run_name}"

    if ! sh "${download_dir}/${run_name}" --target "${download_dir}/extracted" --noexec 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -rf "$download_dir"
        return 1
    fi

    rm -f "${download_dir}/${run_name}"

    echo "[信息] 解压内容:"
    ls -la "${download_dir}/extracted/" 2>/dev/null | grep -v "^total" | sed 's/^/  /'

    # 分别收集 APK 和 IPK 文件
    local apk_files
    apk_files=$(find "${download_dir}/extracted" -name "*.apk" 2>/dev/null)
    local ipk_files
    ipk_files=$(find "${download_dir}/extracted" -name "*.ipk" 2>/dev/null)

    local install_ok=0

    if [ -n "$apk_files" ]; then
        local apk_count
        apk_count=$(echo "$apk_files" | wc -l)
        echo "[安装] 安装 $apk_count 个 APK 包..."
        if apk add --allow-untrusted --force-overwrite $apk_files 2>/dev/null; then
            echo "[成功] APK 包安装完成"
            install_ok=1
        else
            echo "[警告] 部分 APK 安装可能存在问题"
        fi
    fi

    if [ -n "$ipk_files" ]; then
        local ipk_count
        ipk_count=$(echo "$ipk_files" | wc -l)
        echo "[安装] 安装 $ipk_count 个 IPK 包..."
        if opkg install --force-overwrite --force-reinstall $ipk_files 2>/dev/null; then
            echo "[成功] IPK 包安装完成"
            install_ok=1
        else
            echo "[警告] 部分 IPK 安装可能存在问题"
        fi
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 未找到可安装的包文件"
        rm -rf "$download_dir"
        return 1
    fi

    echo "[成功] 安装完成"

    echo "[修复] 修复依赖..."
    fix_dependencies

    # 检测并启用 dae/daed 服务
    local svc_name=""
    for s in daed dae; do
        if [ -f "/etc/init.d/$s" ]; then
            svc_name="$s"
            break
        fi
    done

    if [ -n "$svc_name" ]; then
        echo "[启用] 启用 ${svc_name} 服务..."
        /etc/init.d/"$svc_name" enable 2>/dev/null
    else
        echo "[提示] 未检测到 dae/daed 服务脚本，安装后请在 LuCI 中手动启用"
    fi

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_daed() {
    echo ""
    echo "================================"
    echo " 卸载 Daed (大鹅)"
    echo "================================"
    echo ""

    for s in daed dae; do
        if [ -f "/etc/init.d/$s" ]; then
            echo "[停止] 停止 ${s} 服务..."
            /etc/init.d/"$s" stop 2>/dev/null
            /etc/init.d/"$s" disable 2>/dev/null
        fi
    done

    uninstall_plugin "luci-app-daed"
    uninstall_plugin "luci-i18n-daed-zh-cn"
    uninstall_plugin "daed"
    uninstall_plugin "dae"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

update_daed() {
    echo ""
    echo "================================"
    echo " 更新 Daed (大鹅)"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_daed
}
