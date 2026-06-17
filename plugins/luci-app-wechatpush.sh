#!/bin/sh
# plugins/luci-app-wechatpush.sh - WeChatPush 微信推送插件模块

install_wechatpush() {
    echo ""
    echo "================================"
    echo " 安装 WeChatPush"
    echo "================================"
    echo ""

    local owner="tty228"
    local repo="luci-app-wechatpush"
    local plugin_name="wechatpush"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    local is_apk=0
    case "$release_ver" in
        25.*|snapshot) is_apk=1 ;;
    esac
    [ "$is_apk" -eq 1 ] && pkg_ext="apk" || pkg_ext="ipk"

    echo "[步骤 1/2] 下载 WeChatPush 主程序..."
    local main_url
    main_url=$(echo "$all_urls" | grep "luci-app-wechatpush" | grep -v "i18n" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$main_url" ]; then
        echo "[重试] 未找到 ${pkg_ext} 格式，尝试另一种格式..."
        case "$pkg_ext" in
            apk) main_url=$(echo "$all_urls" | grep "luci-app-wechatpush" | grep -v "i18n" | grep "\.ipk$" | head -1) ;;
            ipk) main_url=$(echo "$all_urls" | grep "luci-app-wechatpush" | grep -v "i18n" | grep "\.apk$" | head -1) ;;
        esac
    fi

    if [ -z "$main_url" ]; then
        echo "[错误] 未找到 WeChatPush 主程序包"
        return 1
    fi

    local main_file
    main_file=$(basename "$main_url")
    if ! download_file "$main_url" "${download_dir}/${main_file}"; then
        echo "[错误] 主程序下载失败"
        return 1
    fi

    if [ ! -s "${download_dir}/${main_file}" ]; then
        echo "[错误] 下载文件为空"
        rm -f "${download_dir}/${main_file}"
        return 1
    fi
    echo "[成功] 主程序下载完成"

    echo "[步骤 2/2] 下载中文语言包..."
    local i18n_url
    i18n_url=$(echo "$all_urls" | grep "luci-i18n-wechatpush-zh-cn" | grep "\.${pkg_ext}$" | head -1)

    if [ -z "$i18n_url" ]; then
        echo "[重试] 未找到 ${pkg_ext} 格式语言包，尝试另一种格式..."
        case "$pkg_ext" in
            apk) i18n_url=$(echo "$all_urls" | grep "luci-i18n-wechatpush-zh-cn" | grep "\.ipk$" | head -1) ;;
            ipk) i18n_url=$(echo "$all_urls" | grep "luci-i18n-wechatpush-zh-cn" | grep "\.apk$" | head -1) ;;
        esac
    fi

    if [ -n "$i18n_url" ]; then
        local i18n_file
        i18n_file=$(basename "$i18n_url")
        if ! download_file "$i18n_url" "${download_dir}/${i18n_file}"; then
            echo "[警告] 语言包下载失败，继续安装主程序..."
            i18n_url=""
        fi
    else
        echo "[警告] 未找到中文语言包"
    fi

    echo "[安装] 正在安装..."
    local install_ok=0
    for f in "${download_dir}"/*.apk "${download_dir}"/*.ipk; do
        [ -f "$f" ] || continue
        case "$f" in
            *.apk)
                echo "[安装] 安装 $(basename "$f")..."
                if apk add --allow-untrusted --force-overwrite "$f" 2>/dev/null; then
                    install_ok=1
                fi
                ;;
            *.ipk)
                echo "[安装] 安装 $(basename "$f")..."
                if opkg install --force-overwrite "$f" 2>/dev/null; then
                    install_ok=1
                fi
                ;;
        esac
    done

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

uninstall_wechatpush() {
    echo ""
    echo "================================"
    echo " 卸载 WeChatPush"
    echo "================================"
    echo ""

    uninstall_plugin "luci-app-wechatpush"
    uninstall_plugin "luci-i18n-wechatpush-zh-cn"

    show_success
}

update_wechatpush() {
    echo ""
    echo "================================"
    echo " 更新 WeChatPush"
    echo "================================"
    echo ""

    cleanup_old_cache
    install_wechatpush
}
