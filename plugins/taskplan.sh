#!/bin/sh
# plugins/taskplan.sh - TaskPlan 插件模块

install_taskplan() {
    manager_print_header "taskplan"

    local owner repo
    owner=$(get_plugin_owner "taskplan")
    repo=$(get_plugin_repo "taskplan")

    cleanup_old_cache
    manager_install_apk "taskplan" "$owner" "$repo" ""
}

uninstall_taskplan() {
    manager_uninstall "taskplan" "luci-app-taskplan" "luci-i18n-taskplan-zh-cn"
}

update_taskplan() {
    local owner repo
    owner=$(get_plugin_owner "taskplan")
    repo=$(get_plugin_repo "taskplan")
    manager_update "taskplan" "$owner" "$repo" install_taskplan
}
