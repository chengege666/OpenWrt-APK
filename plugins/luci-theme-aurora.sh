#!/bin/sh
# plugins/luci-theme-aurora.sh - Aurora 主题插件模块

install_luci_theme_aurora() {
    manager_print_header "aurora"

    local owner repo
    owner=$(get_plugin_owner "aurora")
    repo=$(get_plugin_repo "aurora")

    cleanup_old_cache
    manager_install_apk "aurora" "$owner" "$repo" ""
}

uninstall_luci_theme_aurora() {
    manager_uninstall "aurora" "luci-theme-aurora"
}

update_luci_theme_aurora() {
    local owner repo
    owner=$(get_plugin_owner "aurora")
    repo=$(get_plugin_repo "aurora")
    manager_update "aurora" "$owner" "$repo" install_luci_theme_aurora
}
