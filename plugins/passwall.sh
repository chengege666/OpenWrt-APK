#!/bin/sh
# plugins/passwall.sh - PassWall 插件模块

install_passwall() {
    echo ""
    echo "================================"
    echo " 安装 PassWall"
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

    local ver_tag
    if [ "$is_apk" -eq 1 ]; then
        ver_tag="25.12+"
    elif [ "$release_ver" = "22.03" ] || [ "$release_ver" = "21.02" ]; then
        ver_tag="22.03-"
    else
        ver_tag="23.05-24.10"
    fi
    local ver_tag_esc
    ver_tag_esc=$(echo "$ver_tag" | sed 's/\+/\\+/g')
    echo "[系统] OpenWrt $release_ver ($ver_tag)"

    rm -f /etc/apk/repositories.d/passwall.list 2>/dev/null

    local download_dir="${CACHE_DIR}/passwall"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    echo "[步骤 1/3] 下载 PassWall LuCI 界面..."

    local luci_release_json
    luci_release_json=$(get_latest_release "Openwrt-Passwall" "openwrt-passwall") || return 1

    local luci_tag
    luci_tag=$(get_release_tag "$luci_release_json")
    echo "[版本] $luci_tag"

    local luci_all_urls
    luci_all_urls=$(get_download_urls "$luci_release_json")

    local pkg_ext
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    local luci_url
    luci_url=$(echo "$luci_all_urls" | grep "${ver_tag_esc}" | grep "luci-app-passwall" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$luci_url" ]; then
        echo "[重试] 未找到匹配版本，尝试通用匹配..."
        luci_url=$(echo "$luci_all_urls" | grep "luci-app-passwall" | grep "\.${pkg_ext}$" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        luci_url=$(echo "$luci_all_urls" | grep "luci-app-passwall" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[错误] 未找到 luci-app-passwall 安装包"
        return 1
    fi

    local luci_name
    luci_name=$(basename "$luci_url")
    echo "[下载] $luci_name"
    if ! wget -q --timeout=120 -O "${download_dir}/${luci_name}" "$luci_url" 2>/dev/null; then
        echo "[错误] 下载失败: $luci_name"
        rm -f "${download_dir}/${luci_name}"
        return 1
    fi

    if [ ! -s "${download_dir}/${luci_name}" ]; then
        echo "[错误] 下载文件为空"
        rm -f "${download_dir}/${luci_name}"
        return 1
    fi
    echo "[成功] LuCI 下载完成"

    echo "[步骤 2/3] 下载 PassWall 中文语言包..."
    local i18n_name=""
    local i18n_url
    i18n_url=$(echo "$luci_all_urls" | grep "${ver_tag_esc}" | grep "luci-i18n-passwall-zh-cn" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$i18n_url" ]; then
        echo "[重试] 未找到匹配版本中文包，尝试通用匹配..."
        i18n_url=$(echo "$luci_all_urls" | grep "luci-i18n-passwall-zh-cn" | grep "\.${pkg_ext}$" | head -1)
    fi

    if [ -n "$i18n_url" ]; then
        i18n_name=$(basename "$i18n_url")
        echo "[下载] $i18n_name"
        if ! wget -q --timeout=60 -O "${download_dir}/${i18n_name}" "$i18n_url" 2>/dev/null; then
            echo "[警告] 中文包下载失败，继续安装..."
            i18n_name=""
        elif [ ! -s "${download_dir}/${i18n_name}" ]; then
            echo "[警告] 中文包文件为空，继续安装..."
            rm -f "${download_dir}/${i18n_name}"
            i18n_name=""
        else
            echo "[成功] 中文包下载完成"
        fi
    else
        echo "[提示] 未找到中文语言包，将只安装主程序"
    fi

    echo "[步骤 3/3] 下载依赖包..."
    local deps_release_json
    deps_release_json=$(get_latest_release "Openwrt-Passwall" "openwrt-passwall2") || {
        echo "[错误] 获取依赖包信息失败"
        return 1
    }

    local deps_all_urls
    deps_all_urls=$(get_download_urls "$deps_release_json")

    local pkg_zip_url
    local zip_prefix="passwall_packages_apk"
    [ "$is_apk" -eq 0 ] && zip_prefix="passwall_packages_ipk"

    pkg_zip_url=$(echo "$deps_all_urls" | grep "${zip_prefix}_${arch}\.zip$" | head -1)

    if [ -z "$pkg_zip_url" ]; then
        pkg_zip_url=$(echo "$deps_all_urls" | grep "${zip_prefix}_" | grep "${arch}" | grep "\.zip$" | head -1)
    fi

    if [ -z "$pkg_zip_url" ]; then
        echo "[错误] 未找到匹配架构 ${arch} 的依赖包"
        echo "[提示] 可直接安装 LuCI 主程序，依赖可能来自系统源："
        echo "        apk add --allow-untrusted ${download_dir}/$(basename "$luci_url" | sed 's/%2B/+/g')"
        pkg_zip_url=""
    fi

    if [ -n "$pkg_zip_url" ]; then
        local zip_name
        zip_name=$(basename "$pkg_zip_url")
        echo "[下载] $zip_name"
        if ! wget -q --timeout=180 -O "${download_dir}/${zip_name}" "$pkg_zip_url" 2>/dev/null; then
            echo "[警告] 依赖包下载失败，尝试直接安装 LuCI..."
            pkg_zip_url=""
        elif [ ! -s "${download_dir}/${zip_name}" ]; then
            echo "[警告] 依赖包文件为空，尝试直接安装 LuCI..."
            rm -f "${download_dir}/${zip_name}"
            pkg_zip_url=""
        else
            echo "[成功] 依赖包下载完成"
        fi
    fi

    echo "[安装] 安装 PassWall..."

    if [ -n "$pkg_zip_url" ] && [ -f "${download_dir}/${zip_name}" ]; then
        echo "[解压] 正在解压依赖包..."
        if unzip -o -q "${download_dir}/${zip_name}" -d "${download_dir}/packages" 2>/dev/null; then
            echo "[成功] 解压完成"
            rm -f "${download_dir}/${zip_name}"

            local pkg_files
            pkg_files=$(find "${download_dir}/packages" -name "*.${pkg_ext}" 2>/dev/null)
            if [ -n "$pkg_files" ]; then
                local pkg_count
                pkg_count=$(echo "$pkg_files" | wc -l)
                echo "[安装] 安装 $pkg_count 个依赖包..."

                if [ "$is_apk" -eq 1 ]; then
                    apk add --allow-untrusted --force-overwrite $pkg_files 2>/dev/null || echo "[警告] 部分依赖包安装失败"
                else
                    opkg install --force-overwrite $pkg_files 2>/dev/null || echo "[警告] 部分依赖包安装失败"
                fi
            fi
        else
            echo "[警告] 解压失败，尝试直接安装 LuCI..."
        fi
    fi

    local install_ok=0
    local luci_file
    luci_file=$(basename "$luci_url" | sed 's/%2B/+/g')

    if [ "$luci_file" != "$(basename "$luci_url")" ]; then
        mv -f "${download_dir}/$(basename "$luci_url")" "${download_dir}/${luci_file}" 2>/dev/null
    fi

    if [ "$is_apk" -eq 1 ]; then
        echo "[安装] 安装 LuCI 主程序..."
        if apk add --allow-untrusted --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null; then
            echo "[成功] LuCI 主程序安装完成"
            install_ok=1
        else
            echo "[安装] 缺少依赖，尝试从软件源安装..."
            local missing_deps="dns2socks chinadns-ng tcping microsocks ipt2socks"
            for pkg in $missing_deps; do
                apk add --allow-untrusted "$pkg" 2>/dev/null && echo "[安装] $pkg 完成" || true
            done
            if apk add --allow-untrusted --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null; then
                echo "[成功] LuCI 主程序安装完成"
                install_ok=1
            fi
        fi
    else
        echo "[安装] 安装 LuCI 主程序..."
        if opkg install --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null; then
            echo "[成功] LuCI 主程序安装完成"
            install_ok=1
        else
            echo "[安装] 缺少依赖，尝试从软件源安装..."
            local missing_deps="dns2socks chinadns-ng tcping microsocks ipt2socks"
            for pkg in $missing_deps; do
                opkg install "$pkg" 2>/dev/null && echo "[安装] $pkg 完成" || true
            done
            if opkg install --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null; then
                echo "[成功] LuCI 主程序安装完成"
                install_ok=1
            fi
        fi
    fi

    if [ "$install_ok" -eq 1 ] && [ -n "$i18n_name" ] && [ -f "${download_dir}/${i18n_name}" ]; then
        echo "[安装] 安装中文包..."
        local i18n_file
        i18n_file=$(echo "$i18n_name" | sed 's/%2B/+/g')
        if [ "$i18n_file" != "$i18n_name" ]; then
            mv -f "${download_dir}/${i18n_name}" "${download_dir}/${i18n_file}" 2>/dev/null
        fi

        if [ "$is_apk" -eq 1 ]; then
            apk add --allow-untrusted --force-overwrite "${download_dir}/${i18n_file}" 2>/dev/null && echo "[成功] 中文包安装完成"
        else
            opkg install --force-overwrite "${download_dir}/${i18n_file}" 2>/dev/null && echo "[成功] 中文包安装完成"
        fi
    fi

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        echo "[提示] 手动安装命令："
        echo "  apk add --allow-untrusted --force-overwrite ${download_dir}/${luci_file}"
        return 1
    fi

    echo "[成功] PassWall 安装完成"

    if [ "$is_apk" -eq 0 ]; then
        echo "[修复] 修复依赖..."
        fix_dependencies
    fi

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_passwall() {
    echo ""
    echo "================================"
    echo " 卸载 PassWall"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-passwall"
    uninstall_plugin "luci-i18n-passwall-zh-cn"

    show_success
}

update_passwall() {
    echo ""
    echo "================================"
    echo " 更新 PassWall"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_passwall
}
