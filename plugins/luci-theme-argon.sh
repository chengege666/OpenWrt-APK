#!/bin/sh
# plugins/luci-theme-argon.sh - Argon 主题插件模块

install_luci_theme_argon() {
    manager_print_header "argon"

    local owner repo
    owner=$(get_plugin_owner "argon")
    repo=$(get_plugin_repo "argon")

    cleanup_old_cache
    manager_install_apk "argon" "$owner" "$repo" ""
}

uninstall_luci_theme_argon() {
    manager_uninstall "argon" "luci-theme-argon"
}

update_luci_theme_argon() {
    local owner repo
    owner=$(get_plugin_owner "argon")
    repo=$(get_plugin_repo "argon")
    manager_update "argon" "$owner" "$repo" install_luci_theme_argon
}
