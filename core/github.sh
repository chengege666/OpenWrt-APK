#!/bin/sh
# core/github.sh - GitHub Releases API 模块

get_latest_release() {
    local owner="$1"
    local repo="$2"

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "[错误] 仓库信息不完整"
        return 1
    fi

    local api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
    local response

    response=$(wget -q --timeout=15 -O- "$api_url" 2>/dev/null)

    if [ -z "$response" ]; then
        echo "[错误] 无法获取 GitHub Releases: $owner/$repo"
        return 1
    fi

    echo "$response"
}

get_release_tag() {
    local json="$1"

    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r '.tag_name' 2>/dev/null
    else
        echo "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
    fi
}

get_download_urls() {
    local json="$1"

    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r '.assets[].browser_download_url' 2>/dev/null
    else
        echo "$json" | sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p'
    fi
}

filter_apk_by_arch() {
    local urls="$1"
    local arch="$2"

    echo "$urls" | grep -i "$arch" | grep -i '\.apk$'
}

filter_main_apk() {
    local urls="$1"
    local plugin_name="$2"

    echo "$urls" | grep -i "$plugin_name" | grep -iv 'luci' | grep -iv 'i18n' | grep -i '\.apk$'
}

filter_luci_apk() {
    local urls="$1"
    local plugin_name="$2"

    echo "$urls" | grep -i "luci-app-${plugin_name}" | grep -i '\.apk$'
}

filter_i18n_apk() {
    local urls="$1"

    echo "$urls" | grep -i 'i18n' | grep -i 'zh' | grep -i '\.apk$'
}

filter_dependency_apks() {
    local urls="$1"
    local main_urls="$2"

    echo "$urls" | grep -iv '\.apk$' > /dev/null 2>&1 || echo "$urls"
}
