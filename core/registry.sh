#!/bin/sh
# core/registry.sh - 插件注册表
# 集中管理所有插件的元数据：ID、显示名称、GitHub 仓库信息、类型

# ============================================================
# 插件注册数据
# 每行格式: plugin_id|display_name|owner|repo|pkg_type|has_deps|initd_service
#   pkg_type: apk, tarball, custom
# ============================================================
_PLUGIN_REGISTRY="
openclash|OpenClash|vernesong|OpenClash|apk|1|openclash
mosdns|MosDNS|sbwml|luci-app-mosdns|tarball|0|mosdns
adguardhome|AdGuardHome|AdguardTeam|AdGuardHome|custom|0|adguardhome
docker|Docker|_official_|_official_|custom|0|dockerd
aurora|Aurora 主题|eamonxg|luci-theme-aurora|apk|0|
lucky|Lucky|sirpdboy|luci-app-lucky|tarball|0|
argon|Argon 主题|jerrykuku|luci-theme-argon|apk|0|
taskplan|TaskPlan|sirpdboy|luci-app-taskplan|apk|0|
passwall2|PassWall2|Openwrt-Passwall|openwrt-passwall2|custom|0|
smartdns|SmartDNS|pymumu|smartdns|custom|0|
daed|Daed (大鹅)|wkccd|luci-app-daed-runfiles|custom|1|
"

# ============================================================
# 注册表查询函数
# ============================================================

# 根据索引号获取插件 ID (1-based)
plugin_id_by_index() {
    case "$1" in
        1)  echo "openclash" ;;
        2)  echo "mosdns" ;;
        3)  echo "adguardhome" ;;
        4)  echo "docker" ;;
        5)  echo "aurora" ;;
        6)  echo "lucky" ;;
        7)  echo "argon" ;;
        8)  echo "taskplan" ;;
        9)  echo "passwall2" ;;
        10) echo "smartdns" ;;
        11) echo "daed" ;;
        *)  echo "" ;;
    esac
}

# 插件总数
plugin_count() {
    echo 11
}

# 获取插件显示名称
get_plugin_name() {
    case "$1" in
        openclash)    echo "OpenClash" ;;
        mosdns)       echo "MosDNS" ;;
        adguardhome)  echo "AdGuardHome" ;;
        docker)       echo "Docker" ;;
        aurora)       echo "Aurora 主题" ;;
        lucky)        echo "Lucky" ;;
        argon)        echo "Argon 主题" ;;
        taskplan)     echo "TaskPlan" ;;
        passwall2)    echo "PassWall2" ;;
        smartdns)     echo "SmartDNS" ;;
        daed)         echo "Daed (大鹅)" ;;
        *)            echo "" ;;
    esac
}

# 获取插件 GitHub owner
get_plugin_owner() {
    case "$1" in
        openclash)    echo "vernesong" ;;
        mosdns)       echo "sbwml" ;;
        adguardhome)  echo "AdguardTeam" ;;
        aurora)       echo "eamonxg" ;;
        lucky)        echo "sirpdboy" ;;
        argon)        echo "jerrykuku" ;;
        taskplan)     echo "sirpdboy" ;;
        passwall2)    echo "Openwrt-Passwall" ;;
        smartdns)     echo "pymumu" ;;
        daed)         echo "wkccd" ;;
        *)            echo "" ;;
    esac
}

# 获取插件 GitHub repo
get_plugin_repo() {
    case "$1" in
        openclash)    echo "OpenClash" ;;
        mosdns)       echo "luci-app-mosdns" ;;
        adguardhome)  echo "AdGuardHome" ;;
        aurora)       echo "luci-theme-aurora" ;;
        lucky)        echo "luci-app-lucky" ;;
        argon)        echo "luci-theme-argon" ;;
        taskplan)     echo "luci-app-taskplan" ;;
        passwall2)    echo "openwrt-passwall2" ;;
        smartdns)     echo "smartdns" ;;
        daed)         echo "luci-app-daed-runfiles" ;;
        *)            echo "" ;;
    esac
}

# 获取插件包类型 (apk/tarball/custom)
get_plugin_type() {
    case "$1" in
        openclash|aurora|argon|taskplan)  echo "apk" ;;
        mosdns|lucky)                     echo "tarball" ;;
        *)                                echo "custom" ;;
    esac
}

# 是否需要依赖安装
plugin_has_deps() {
    case "$1" in
        openclash|daed) return 0 ;;
        *) return 1 ;;
    esac
}

# 获取插件 init.d 服务名（可为空）
get_plugin_service() {
    case "$1" in
        openclash)    echo "openclash" ;;
        mosdns)       echo "mosdns" ;;
        adguardhome)  echo "adguardhome" ;;
        docker)       echo "dockerd" ;;
        lucky)        echo "lucky" ;;
        taskplan)     echo "taskplan" ;;
        passwall2)    echo "passwall2" ;;
        smartdns)     echo "smartdns" ;;
        daed)         echo "daed" ;;
        *)            echo "" ;;
    esac
}

# 判断是否为可使用通用引擎的标准插件
is_standard_plugin() {
    case "$1" in
        openclash|mosdns|aurora|lucky|argon|taskplan) return 0 ;;
        *) return 1 ;;
    esac
}

# 判断是否为自定义插件（需要特殊安装逻辑）
is_custom_plugin() {
    case "$1" in
        adguardhome|docker|passwall2|smartdns|daed) return 0 ;;
        *) return 1 ;;
    esac
}

# 遍历所有插件 ID，为 update_all 提供列表
all_plugin_ids() {
    echo "openclash mosdns adguardhome docker aurora lucky argon taskplan passwall2 smartdns daed"
}
