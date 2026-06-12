#!/bin/sh
# plugins/adguardhome.sh - AdGuardHome 插件模块
# 适配: x86_64 + OpenWrt 25.12.x (APK)
# 核心: AdGuardTeam/AdGuardHome
# LuCI: w9315273/luci-app-adguardhome

# 路径常量
AGH_BIN="/usr/bin/AdGuardHome"
AGH_DIR="/etc/AdGuardHome"
AGH_YAML="${AGH_DIR}/AdGuardHome.yaml"
AGH_INITD="/etc/init.d/AdGuardHome"
AGH_DHCP_BAK="/etc/config/dhcp.adguardhome.bak"

# 检测 x86_64
_check_agh_arch() {
    local arch
    arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        echo "[错误] AdGuardHome 插件仅支持 x86_64 架构，当前: $arch"
        return 1
    fi
}

# 检测 25.x APK 系统
_check_agh_system() {
    . /etc/openwrt_release 2>/dev/null
    local release_ver
    release_ver=$(echo "$DISTRIB_RELEASE" | cut -d'.' -f1,2)
    case "$release_ver" in
        25.*|snapshot)
            return 0
            ;;
        *)
            echo "[错误] AdGuardHome 插件仅支持 OpenWrt 25.x (APK)，当前: $DISTRIB_RELEASE"
            return 1
            ;;
    esac
}

# 安装运行依赖
install_adguardhome_deps() {
    echo "[依赖] 检查 AdGuardHome 运行依赖..."
    apk update 2>/dev/null

    # 25.x 下 wget 拆分为 wget-ssl,直接装 wget-ssl 更稳
    local pkgs="ca-bundle wget-ssl coreutils-nohup"
    echo "[依赖] 安装系统包: $pkgs"
    apk add --allow-untrusted $pkgs 2>/dev/null || {
        echo "[警告] 部分依赖安装失败，继续执行"
    }

    echo "[依赖] 依赖检查完成"
}

# 下载核心二进制
download_adguardhome_core() {
    local plugin_name="adguardhome"
    local owner="AdGuardTeam"
    local repo="AdGuardHome"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[核心] 最新版本: $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    # x86_64 对应 amd64
    local core_url
    core_url=$(echo "$all_urls" | grep "AdGuardHome_linux_amd64\.tar\.gz$" | head -1)

    if [ -z "$core_url" ]; then
        echo "[错误] 未找到 linux_amd64 架构核心"
        return 1
    fi

    local download_dir="${CACHE_DIR}/${plugin_name}"
    rm -rf "$download_dir"
    mkdir -p "$download_dir"

    local core_name
    core_name=$(basename "$core_url")
    echo "[下载] $core_name"
    if ! download_file "$core_url" "${download_dir}/${core_name}"; then
        echo "[错误] 核心下载失败"
        return 1
    fi

    echo "[解压] 正在解压..."
    if ! tar xzf "${download_dir}/${core_name}" -C "${download_dir}" 2>/dev/null; then
        echo "[错误] 解压失败"
        rm -rf "$download_dir"
        return 1
    fi
    rm -f "${download_dir}/${core_name}"

    # 兼容两种目录结构:
    #   1. AdGuardHome/AdGuardHome  (官方标准)
    #   2. AdGuardHome              (扁平结构)
    local agh_src=""
    if [ -f "${download_dir}/AdGuardHome/AdGuardHome" ]; then
        agh_src="${download_dir}/AdGuardHome/AdGuardHome"
    elif [ -f "${download_dir}/AdGuardHome" ]; then
        agh_src="${download_dir}/AdGuardHome"
    fi

    if [ -z "$agh_src" ] || [ ! -f "$agh_src" ]; then
        echo "[错误] 解压后未找到 AdGuardHome 二进制"
        echo "[信息] 当前目录内容:"
        ls -la "${download_dir}" 2>/dev/null
        rm -rf "$download_dir"
        return 1
    fi

    # 把规范化的路径写到一个固定文件名,后续步骤不再关心目录结构
    cp -f "$agh_src" "${download_dir}/AdGuardHome.bin"
    echo "[成功] 核心下载完成"
}

# 部署核心到 /usr/bin
install_adguardhome_binary() {
    local plugin_name="adguardhome"
    local download_dir="${CACHE_DIR}/${plugin_name}"

    if [ ! -f "${download_dir}/AdGuardHome.bin" ]; then
        echo "[错误] 核心文件不存在,请先下载"
        return 1
    fi

    echo "[安装] 部署 AdGuardHome 核心..."
    mkdir -p /usr/bin
    cp -f "${download_dir}/AdGuardHome.bin" "$AGH_BIN"
    chmod +x "$AGH_BIN"

    if [ ! -x "$AGH_BIN" ]; then
        echo "[错误] 二进制安装失败"
        return 1
    fi

    echo "[成功] 核心部署完成: $AGH_BIN"
}

# 生成最小可用配置 (跳过 Web 初始化向导)
generate_adguardhome_config() {
    mkdir -p "$AGH_DIR"

    if [ -f "$AGH_YAML" ]; then
        echo "[配置] 已存在 AdGuardHome.yaml,跳过生成"
        return 0
    fi

    echo "[配置] 生成初始 AdGuardHome.yaml..."
    cat > "$AGH_YAML" << 'YAMLEOF'
http:
  address: 0.0.0.0:3000
  session_ttl: 720
  users: []
  auth_attempts: 5
  ban_time: 300
  trusted_proxies:
    - 127.0.0.1
    - ::1
  protection_enabled: true
  real_ip_header: X-Forwarded-For
  use_default_user: true
  default_user:
    name: admin
    password: admin

dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  protection_enabled: true
  blocking_mode: default
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocking_ttl: 10
  parental_blocking: []
  safesearch_enabled: false
  safebrowsing_enabled: false
  upstream_dns:
    - 1.1.1.1
    - 8.8.8.8
  upstream_dns_file: ""
  bootstrap_dns:
    - 1.1.1.1
    - 8.8.8.8
  all_servers: false
  fastest_addr: false
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies: []
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  serve_stale: 0
  serve_expired: false
  edns_client_subnet: false
YAMLEOF

    chmod 600 "$AGH_YAML"
    echo "[成功] 初始配置已生成: $AGH_YAML"
    echo "[提示] 默认账号 admin / admin,请在 Web 界面 (端口 3000) 立即修改"
}

# 创建 procd 启动脚本
create_adguardhome_initd() {
    echo "[服务] 创建 /etc/init.d/AdGuardHome..."

    cat > "$AGH_INITD" << 'INITEOF'
#!/bin/sh /etc/rc.common

START=95
STOP=15

USE_PROCD=1

PROG="/usr/bin/AdGuardHome"
CONFFILE="/etc/AdGuardHome/AdGuardHome.yaml"
WORKDIR="/etc/AdGuardHome"

start_service() {
    procd_open_instance
    procd_set_param command "$PROG" --no-check-update -c "$CONFFILE" -w "$WORKDIR"
    procd_set_param respawn 3600 5 5
    procd_set_param file "$CONFFILE"
    procd_set_param stdout 0
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    pkill -f "/usr/bin/AdGuardHome" 2>/dev/null
}

reload_service() {
    stop
    start
}
INITEOF

    chmod +x "$AGH_INITD"
    echo "[成功] 启动脚本已创建"
}

# 解决 53 端口冲突: dnsmasq 改 5353 + noresolv
resolve_dns_port_conflict() {
    echo "[端口] 检查 53 端口占用..."

    if ! grep -q "config dnsmasq" /etc/config/dhcp 2>/dev/null; then
        echo "[端口] 未检测到 dnsmasq 配置,跳过"
        return 0
    fi

    # 首次安装时备份原配置 (卸载时还原)
    if [ ! -f "$AGH_DHCP_BAK" ]; then
        echo "[备份] 备份 /etc/config/dhcp -> $AGH_DHCP_BAK"
        cp -f /etc/config/dhcp "$AGH_DHCP_BAK"
    fi

    # 修改端口为 5353 (覆盖 list 或 option)
    local cur_port
    cur_port=$(uci get dhcp.@dnsmasq[0].port 2>/dev/null)
    if [ -n "$cur_port" ]; then
        uci set dhcp.@dnsmasq[0].port='5353'
    else
        uci add_list dhcp.@dnsmasq[0].port='5353'
    fi

    # 强制 noresolv=1
    uci set dhcp.@dnsmasq[0].noresolv='1'

    uci commit dhcp
    echo "[端口] dnsmasq 端口 -> 5353, noresolv -> 1"

    if [ -f /etc/init.d/dnsmasq ]; then
        /etc/init.d/dnsmasq restart 2>/dev/null
        echo "[端口] dnsmasq 已重启"
    fi
}

# 还原 dnsmasq 配置
restore_dnsmasq_config() {
    if [ -f "$AGH_DHCP_BAK" ]; then
        echo "[还原] 还原 /etc/config/dhcp 备份"
        cp -f "$AGH_DHCP_BAK" /etc/config/dhcp
        rm -f "$AGH_DHCP_BAK"

        if [ -f /etc/init.d/dnsmasq ]; then
            /etc/init.d/dnsmasq restart 2>/dev/null
            echo "[还原] dnsmasq 已重启"
        fi
    fi
}

# 下载并安装 LuCI 界面
install_adguardhome_luci() {
    echo "[LuCI] 下载 AdGuardHome LuCI 界面..."

    local plugin_name="adguardhome"
    local download_dir="${CACHE_DIR}/${plugin_name}"
    mkdir -p "$download_dir"

    local owner="w9315273"
    local repo="luci-app-adguardhome"

    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || {
        echo "[警告] 无法获取 LuCI release,跳过界面安装"
        return 0
    }

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[LuCI] 版本: $tag"

    local all_urls
    all_urls=$(get_download_urls "$release_json")

    # 优先 .apk (25.x);fallback .ipk (24.x 兼容)
    local luci_url
    luci_url=$(echo "$all_urls" | grep "luci-app-adguardhome" | grep -E '\.apk$' | head -1)
    if [ -z "$luci_url" ]; then
        luci_url=$(echo "$all_urls" | grep "luci-app-adguardhome" | head -1)
    fi

    if [ -z "$luci_url" ]; then
        echo "[警告] 未找到 LuCI 界面包,跳过"
        return 0
    fi

    local luci_file
    luci_file=$(basename "$luci_url")
    echo "[下载] $luci_file"
    if ! download_file "$luci_url" "${download_dir}/${luci_file}"; then
        echo "[警告] LuCI 界面下载失败,跳过"
        return 0
    fi

    echo "[安装] 安装 LuCI 界面..."
    case "$luci_file" in
        *.apk)
            apk add --allow-untrusted --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null
            ;;
        *.ipk)
            opkg install --force-overwrite "${download_dir}/${luci_file}" 2>/dev/null
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "[成功] LuCI 界面安装完成"
    else
        echo "[警告] LuCI 界面安装可能有问题"
    fi
}

# 主入口: 安装
install_adguardhome() {
    echo ""
    echo "================================"
    echo " 安装 AdGuardHome"
    echo "================================"
    echo ""

    _check_agh_arch || return 1
    _check_agh_system || return 1

    install_adguardhome_deps

    download_adguardhome_core || return 1
    install_adguardhome_binary || return 1

    generate_adguardhome_config
    create_adguardhome_initd

    resolve_dns_port_conflict
    install_adguardhome_luci

    echo "[修复] 修复依赖..."
    fix_dependencies

    echo "[启用] 启用 AdGuardHome..."
    if [ -f "$AGH_INITD" ]; then
        $AGH_INITD enable 2>/dev/null
        $AGH_INITD start 2>/dev/null
    fi

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success

    echo ""
    echo "================================"
    echo " AdGuardHome 访问信息"
    echo "  Web 界面: http://路由器IP:3000"
    echo "  默认账号: admin / admin (请立即修改)"
    echo "  DNS 端口: 0.0.0.0:53"
    echo "  dnsmasq:  0.0.0.0:5353 (已让出 53 端口)"
    echo "================================"
}

# 主入口: 卸载
uninstall_adguardhome() {
    echo ""
    echo "================================"
    echo " 卸载 AdGuardHome"
    echo "================================"
    echo ""

    echo "[停止] 停止 AdGuardHome 服务..."
    if [ -f "$AGH_INITD" ]; then
        $AGH_INITD stop 2>/dev/null
        $AGH_INITD disable 2>/dev/null
    fi
    pkill -f "/usr/bin/AdGuardHome" 2>/dev/null

    echo "[清理] 清理核心文件..."
    rm -f "$AGH_BIN"
    rm -rf "$AGH_DIR"
    rm -f "$AGH_INITD"
    rm -rf /var/log/AdGuardHome.log

    echo "[还原] 还原 dnsmasq 配置..."
    restore_dnsmasq_config

    echo "[卸载] 卸载 LuCI 界面..."
    uninstall_plugin "adguardhome"

    echo "[重启] 重启 LuCI..."
    restart_luci

    show_success
}

# 主入口: 更新
update_adguardhome() {
    echo ""
    echo "================================"
    echo " 更新 AdGuardHome"
    echo "================================"
    echo ""

    cleanup_old_cache

    # 备份现有配置和 init.d
    local yaml_bak=""
    local initd_bak=""
    if [ -f "$AGH_YAML" ]; then
        yaml_bak="${AGH_YAML}.bak"
        cp -f "$AGH_YAML" "$yaml_bak"
    fi
    if [ -f "$AGH_INITD" ]; then
        initd_bak="${AGH_INITD}.bak"
        cp -f "$AGH_INITD" "$initd_bak"
    fi

    install_adguardhome

    # 还原配置 (用户修改过的设置不丢)
    if [ -n "$yaml_bak" ] && [ -f "$yaml_bak" ]; then
        mv -f "$yaml_bak" "$AGH_YAML"
        echo "[还原] 配置文件已保留"
    fi
    if [ -n "$initd_bak" ] && [ -f "$initd_bak" ]; then
        rm -f "$initd_bak"
    fi
}
