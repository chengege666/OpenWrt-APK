#!/bin/sh
# plugins/passwall.sh - luci-app-passwall 安装模块 (APK only, OpenWrt 25.12+)
#
# 包来源：
#   - 系统依赖: OpenWrt 官方源 (apk)
#   - PassWall 依赖库: GitHub passwall-packages (api-cache JSON -> SourceForge APK)
#   - LuCI 本体: GitHub passwall (Releases)
#
# 注意: SourceForge 目录页面有 Cloudflare 防护，不能直接爬取 HTML。
#       改为从 passwall-packages 的 api-cache release 获取下载 URL。

PKG_CACHE_REPO="Openwrt-Passwall/openwrt-passwall-packages"
PKG_CACHE_TAG="api-cache"
PKG_CACHE_BASE="https://github.com/${PKG_CACHE_REPO}/releases/download/${PKG_CACHE_TAG}"

# ============================================================
# 获取架构
# ============================================================
_get_arch() {
    . /etc/openwrt_release 2>/dev/null || return 1
    echo "$DISTRIB_ARCH"
}

# ============================================================
# 从 JSON API cache 中提取对应架构的下载 URL
# 参数: $1 JSON 内容  $2 架构名
# ============================================================
_extract_sf_url() {
    local json="$1"
    local arch="$2"

    # JSON 格式: {"version":"1.0","files":{"x86_64":"url1","aarch64":"url2",...}}
    # 或: {"version":"1.0","x86_64":"url1","aarch64":"url2",...}

    # 精确匹配架构
    local url
    url=$(echo "$json" | grep -oE "\"${arch}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" | head -1 | \
        sed 's/^[^:]*:[[:space:]]*"//;s/"$//')

    if [ -z "$url" ]; then
        # 回退: 尝试包含匹配
        url=$(echo "$json" | grep -oE "\"[^\"]*${arch}[^\"]*\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" | head -1 | \
            sed 's/^[^:]*:[[:space:]]*"//;s/"$//')
    fi
    echo "$url"
}

# ============================================================
# 从 SourceForge 下载一个 APK 文件
# 参数: $1 下载 URL  $2 输出路径
# ============================================================
_download_sf_apk() {
    local url="$1"
    local output="$2"

    # API cache JSON 中的 SourceForge URL 类似:
    # https://downloads.sourceforge.net/project/openwrt-passwall-build/.../file.apk
    download_file "$url" "$output"
}

# ============================================================
# 安装 PassWall
# ============================================================
install_passwall() {
    echo ""
    echo "================================"
    echo " 安装 PassWall"
    echo "================================"
    echo ""

    # ---- 检测环境 ----
    local arch
    arch=$(_get_arch) || {
        echo "[错误] 无法获取架构"
        return 1
    }
    echo "[架构] $arch"

    local download_dir="${CACHE_DIR}/passwall"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    # ============================================================
    # 1. 安装系统硬依赖 (OpenWrt 官方源)
    # ============================================================
    echo ""
    echo "--- [1/5] 安装系统硬依赖 ---"

    local sys_pkgs="coreutils coreutils-base64 coreutils-nohup curl dnsmasq-full ip-full libuci-lua lua luci-compat luci-lib-jsonc resolveip lyaml"

    # 透明代理
    if command -v fw4 >/dev/null 2>&1 || [ -f /etc/config/firewall4 ] 2>/dev/null; then
        echo "  防火墙: Nftables (fw4)"
        sys_pkgs="$sys_pkgs nftables kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
    else
        echo "  防火墙: Iptables (fw3)"
        sys_pkgs="$sys_pkgs ipset iptables iptables-zz-legacy iptables-mod-conntrack-extra iptables-mod-iprange iptables-mod-socket iptables-mod-tproxy kmod-ipt-nat"
    fi

    local ok=0 fail=0
    for pkg in $sys_pkgs; do
        if apk add "$pkg" 2>/dev/null; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    done
    printf "  结果: 成功 %d, 失败 %d\n" "$ok" "$fail"

    # ============================================================
    # 2. 获取 GitHub Releases 中的 LuCI 包
    # ============================================================
    echo ""
    echo "--- [2/5] 获取 LuCI 主程序 ---"

    local release_json
    release_json=$(get_latest_release "Openwrt-Passwall" "openwrt-passwall") || {
        echo "[错误] GitHub API 请求失败"
        return 1
    }

    local tag
    tag=$(get_release_tag "$release_json")
    echo "  版本: $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    local luci_url
    luci_url=$(echo "$all_urls" | grep -i "luci-app-passwall" | grep "\.apk$" | head -1)
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep -i "luci-i18n-passwall-zh-cn" | grep "\.apk$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-passwall APK"
        return 1
    fi

    local luci_name; luci_name=$(basename "$luci_url")
    local i18n_name=""; [ -n "$i18n_url" ] && i18n_name=$(basename "$i18n_url")
    echo "  LuCI: $luci_name"
    [ -n "$i18n_name" ] && echo "  中文: $i18n_name"

    # ============================================================
    # 3. 从 passwall-packages api-cache JSON 获取依赖包 URL
    # ============================================================
    echo ""
    echo "--- [3/5] 获取依赖包下载地址 ---"

    # 需要安装的包名列表 (对应 passwall-packages 中的 JSON 文件名)
    local need_pkgs="chinadns-ng dns2socks geoip geosite geoview haproxy hysteria ipt2socks microsocks naiveproxy shadow-tls shadowsocks-rust shadowsocksr-libev simple-obfs sing-box tcping v2ray-plugin xray-core xray-plugin"

    # 下载 URL 列表文件
    local url_list="${download_dir}/download_urls.txt"
    > "$url_list"

    local found=0 notfound=0
    for pkg in $need_pkgs; do
        local json_url="${PKG_CACHE_BASE}/${pkg}-release-api.json"
        local json_out="${download_dir}/${pkg}.json"

        # 下载 JSON cache (通过 GitHub 镜像)
        if download_file "$json_url" "$json_out" 2>/dev/null; then
            local json_content
            json_content=$(cat "$json_out")

            local sf_url
            sf_url=$(_extract_sf_url "$json_content" "$arch")

            if [ -n "$sf_url" ]; then
                echo "  [找到] $pkg -> $(basename "$sf_url")"
                echo "$sf_url" >> "$url_list"
                found=$((found + 1))
            else
                echo "  [跳过] $pkg: 无 $arch 架构版本"
                notfound=$((notfound + 1))
            fi
        else
            echo "  [跳过] $pkg: JSON 获取失败"
            notfound=$((notfound + 1))
        fi
    done
    printf "  结果: 找到 %d 个包, %d 个跳过\n" "$found" "$notfound"

    # ============================================================
    # 4. 根据 URL 列表下载所有 APK
    # ============================================================
    echo ""
    echo "--- [4/5] 下载 APK 包 ---"

    local dl_ok=0 dl_fail=0
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        local name; name=$(basename "$url")
        local output="${download_dir}/${name}"

        if [ -f "$output" ] && [ -s "$output" ]; then
            echo "  [跳过] $name"
            dl_ok=$((dl_ok + 1))
            continue
        fi

        if _download_sf_apk "$url" "$output"; then
            echo "  [下载] $name"
            dl_ok=$((dl_ok + 1))
        else
            echo "  [失败] $name"
            dl_fail=$((dl_fail + 1))
        fi
    done < "$url_list"

    # 下载 LuCI 包
    echo ""
    echo "  下载 LuCI 主程序..."
    download_file "$luci_url" "${download_dir}/${luci_name}" || {
        echo "[错误] LuCI 下载失败"
        return 1
    }
    dl_ok=$((dl_ok + 1))

    if [ -n "$i18n_url" ]; then
        download_file "$i18n_url" "${download_dir}/${i18n_name}" || true
        dl_ok=$((dl_ok + 1))
    fi

    printf "  结果: 成功 %d, 失败 %d\n" "$dl_ok" "$dl_fail"
    if [ "$dl_ok" -eq 0 ]; then
        echo "[错误] 没有下载到任何包"
        return 1
    fi

    # ============================================================
    # 5. 安装 APK
    # ============================================================
    echo ""
    echo "--- [5/5] 安装 APK 包 ---"

    local total_apk
    total_apk=$(find "$download_dir" -maxdepth 1 -name "*.apk" 2>/dev/null | wc -l)
    echo "  共 $total_apk 个 APK"

    # 先装依赖 (非 luci 开头的)
    echo "  安装依赖包..."
    for f in "$download_dir"/*.apk; do
        [ -f "$f" ] || continue
        local base; base=$(basename "$f")
        case "$base" in
            luci-app-passwall*|luci-i18n-passwall*) continue ;;
        esac
        apk add --allow-untrusted --force-overwrite "$f" 2>/dev/null || true
    done

    # 装 LuCI
    echo "  安装 LuCI 主程序..."
    apk add --allow-untrusted --force-overwrite "${download_dir}/${luci_name}" 2>/dev/null || {
        echo "[错误] LuCI 安装失败"
        return 1
    }

    if [ -n "$i18n_name" ] && [ -f "${download_dir}/${i18n_name}" ]; then
        echo "  安装中文语言包..."
        apk add --allow-untrusted --force-overwrite "${download_dir}/${i18n_name}" 2>/dev/null || \
            echo "  [警告] 中文包安装失败"
    fi

    echo ""
    echo "[成功] PassWall 安装完成"
    restart_luci
    show_success
}

# ============================================================
# 卸载
# ============================================================
uninstall_passwall() {
    echo ""
    echo "================================"
    echo " 卸载 PassWall"
    echo "================================"
    echo ""

    apk del luci-app-passwall luci-i18n-passwall-zh-cn 2>/dev/null
    echo ""
    echo "[完成] PassWall 已卸载"
    echo "[提示] 依赖包保留，如需清理: apk del xray-core sing-box chinadns-ng ..."
    show_success
}

# ============================================================
# 更新
# ============================================================
update_passwall() {
    echo ""
    echo "================================"
    echo " 更新 PassWall"
    echo "================================"
    echo ""
    cleanup_old_cache
    install_passwall
}
