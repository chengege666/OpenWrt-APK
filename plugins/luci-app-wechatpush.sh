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
    local installed_list=""
    local _out="/tmp/_wechatpush_install.log"
    local _rc=0
    for f in "${download_dir}"/*.apk "${download_dir}"/*.ipk; do
        [ -f "$f" ] || continue
        case "$f" in
            *.apk)
                echo "[安装] 安装 $(basename "$f")..."
                apk add --allow-untrusted --force-overwrite "$f" >"$_out" 2>&1
                _rc=$?
                [ -s "$_out" ] && tail -5 "$_out"
                if [ $_rc -eq 0 ]; then
                    install_ok=1
                    installed_list="${installed_list} $(basename "$f" .apk)"
                fi
                ;;
            *.ipk)
                echo "[安装] 安装 $(basename "$f")..."
                opkg install --force-overwrite "$f" >"$_out" 2>&1
                _rc=$?
                [ -s "$_out" ] && tail -5 "$_out"
                if [ $_rc -eq 0 ]; then
                    install_ok=1
                    installed_list="${installed_list} $(basename "$f" .ipk)"
                fi
                ;;
        esac
    done
    rm -f "$_out"

    if [ "$install_ok" -eq 0 ]; then
        echo "[错误] 安装失败"
        return 1
    fi

    # [新增] 文件落盘验证 + 重装兜底（覆盖 "包名已登记但文件未写入" 的异常场景）
    echo "[验证] 检查关键文件是否落盘..."
    local verify_menu verify_acl verify_view
    verify_menu=$(ls /usr/share/luci/menu.d/*wechatpush* 2>/dev/null | head -1)
    verify_acl=$(ls /usr/share/rpcd/acl.d/*wechatpush* 2>/dev/null | head -1)
    verify_view=$(ls /www/luci-static/resources/view/wechatpush/*.js 2>/dev/null | head -1)

    if [ -z "$verify_menu" ] || [ -z "$verify_acl" ] || [ -z "$verify_view" ]; then
        echo "[警告] 检测到关键文件未完整落盘（menu:$verify_menu acl:$verify_acl view:$verify_view）"
        echo "[修复] 执行兜底重装：先卸载 + 清残留 + 再安装..."

        # 备份用户配置（如果存在）
        [ -f /etc/config/wechatpush ] && cp -f /etc/config/wechatpush /etc/config/wechatpush.bak 2>/dev/null

        # APK 模式兜底
        if command -v apk >/dev/null 2>&1; then
            apk del --purge luci-app-wechatpush 2>&1 | tail -3
            apk del --purge luci-i18n-wechatpush-zh-cn 2>&1 | tail -3
        # IPK 模式兜底
        elif command -v opkg >/dev/null 2>&1; then
            opkg remove --force-remove --force-depends luci-app-wechatpush 2>&1 | tail -3
            opkg remove --force-remove --force-depends luci-i18n-wechatpush-zh-cn 2>&1 | tail -3
        fi

        # 暴力清残留
        rm -rf /usr/share/luci/menu.d/*wechatpush* \
               /usr/share/rpcd/acl.d/*wechatpush* \
               /www/luci-static/resources/view/wechatpush \
               /usr/share/wechatpush \
               /usr/libexec/wechatpush-call \
               /usr/lib/lua/luci/controller/*wechatpush* \
               /usr/lib/lua/luci/model/cbi/*wechatpush* \
               /usr/lib/lua/luci/view/*wechatpush* \
               /usr/lib/lua/luci/i18n/*wechatpush* \
               /usr/bin/*wechatpush* \
               /usr/lib/lua/*wechatpush* 2>/dev/null
        # 保留 config/init.d（后面重装会释放）避免路径冲突
        rm -f /etc/config/wechatpush /etc/init.d/wechatpush /etc/uci-defaults/luci-wechatpush 2>/dev/null

        # 再次安装
        echo "[修复] 重新安装下载包..."
        local retry_ok=0
        local _retry_out="/tmp/_wechatpush_retry.log"
        local _retry_rc=0
        for f in "${download_dir}"/*.apk "${download_dir}"/*.ipk; do
            [ -f "$f" ] || continue
            case "$f" in
                *.apk)
                    echo "[安装] 重装 $(basename "$f")..."
                    apk add --allow-untrusted --force-overwrite "$f" >"$_retry_out" 2>&1
                    _retry_rc=$?
                    [ -s "$_retry_out" ] && tail -5 "$_retry_out"
                    if [ $_retry_rc -eq 0 ]; then
                        retry_ok=1
                    fi
                    ;;
                *.ipk)
                    echo "[安装] 重装 $(basename "$f")..."
                    opkg install --force-overwrite "$f" >"$_retry_out" 2>&1
                    _retry_rc=$?
                    [ -s "$_retry_out" ] && tail -5 "$_retry_out"
                    if [ $_retry_rc -eq 0 ]; then
                        retry_ok=1
                    fi
                    ;;
            esac
        done
        rm -f "$_retry_out"

        # 恢复用户配置
        if [ -f /etc/config/wechatpush.bak ]; then
            [ ! -f /etc/config/wechatpush ] || mv -f /etc/config/wechatpush /etc/config/wechatpush.pkgnew 2>/dev/null
            mv -f /etc/config/wechatpush.bak /etc/config/wechatpush 2>/dev/null
            echo "[恢复] 已还原原 /etc/config/wechatpush 配置"
        fi

        # 二次验证
        verify_menu=$(ls /usr/share/luci/menu.d/*wechatpush* 2>/dev/null | head -1)
        verify_acl=$(ls /usr/share/rpcd/acl.d/*wechatpush* 2>/dev/null | head -1)
        if [ -z "$verify_menu" ] || [ -z "$verify_acl" ]; then
            echo "[错误] 兜底重装后关键文件仍缺失，建议手动检查文件系统或改用 tar 直接解包 APK"
            echo "[提示] 手动解包命令: tar -xzf ${download_dir}/luci-app-wechatpush-*.apk -C /"
            return 1
        fi

        if [ "$retry_ok" -eq 0 ]; then
            echo "[错误] 兜底重装失败"
            return 1
        fi
        echo "[成功] 兜底重装完成"
    else
        echo "[成功] 关键文件验证通过"
    fi

    echo "[修复] 修复依赖..."
    # APK 模式直接执行 apk fix（不再依赖 fix_dependencies 的跳过逻辑）
    if command -v apk >/dev/null 2>&1; then
        echo "[修复] 执行 apk fix..."
        apk fix 2>&1 | tail -10
    fi
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

    # 1. APK 包管理器强制卸载（去掉 2>/dev/null，错误可见）
    echo "[卸载] apk: 正在卸载 luci-app-wechatpush..."
    apk del --purge luci-app-wechatpush 2>&1
    echo "[卸载] apk: 正在卸载 luci-i18n-wechatpush-zh-cn..."
    apk del --purge luci-i18n-wechatpush-zh-cn 2>&1
    apk del --purge luci-i18n-wechatpush 2>&1
    apk del --purge wechatpush 2>&1

    # 2. 暴力清理残留文件（覆盖 --force-overwrite 强装但数据库无记录的情况）
    echo "[清理] 正在清理残留文件..."
    rm -rf /usr/lib/lua/luci/controller/*wechatpush* 2>/dev/null
    rm -rf /usr/lib/lua/luci/model/cbi/*wechatpush* 2>/dev/null
    rm -rf /usr/lib/lua/luci/view/*wechatpush* 2>/dev/null
    rm -rf /usr/lib/lua/luci/i18n/*wechatpush* 2>/dev/null
    rm -rf /usr/share/luci/menu.d/*wechatpush* 2>/dev/null
    rm -rf /usr/share/rpcd/acl.d/*wechatpush* 2>/dev/null
    rm -rf /www/luci-static/resources/*wechatpush* 2>/dev/null
    rm -rf /etc/config/*wechatpush* 2>/dev/null
    rm -rf /etc/init.d/*wechatpush* 2>/dev/null
    rm -rf /usr/bin/*wechatpush* 2>/dev/null
    rm -rf /usr/share/*wechatpush* 2>/dev/null
    rm -rf /usr/lib/lua/*wechatpush* 2>/dev/null

    # 3. 清理 LuCI 缓存并重启服务
    echo "[重启] 正在重启 LuCI..."
    restart_luci

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
