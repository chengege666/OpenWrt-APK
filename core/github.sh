#!/bin/sh
# core/github.sh - GitHub Releases API 模块

# 内部函数：通过镜像获取 GitHub API 响应
_fetch_github_api() {
    local url="$1"
    local desc="$2"

    # 有镜像则走镜像
    if [ -n "$GITHUB_MIRROR" ]; then
        local proxied_url="${GITHUB_MIRROR%/}/${url}"
        local response
        response=$(wget -q --timeout=15 -O- "$proxied_url" 2>/dev/null)
        if [ -n "$response" ]; then
            echo "$response"
            return 0
        fi
        echo "[警告] 镜像 API 请求失败，尝试直连..."
    fi

    wget -q --timeout=15 -O- "$url" 2>/dev/null
}

get_latest_release() {
    local owner="$1"
    local repo="$2"

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "[错误] 仓库信息不完整"
        return 1
    fi

    local api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
    local response
    response=$(_fetch_github_api "$api_url" "Releases: $owner/$repo")

    if [ -z "$response" ]; then
        echo "[错误] 无法获取 GitHub Releases: $owner/$repo"
        return 1
    fi

    echo "$response"
}

get_latest_commit_sha() {
    local owner="$1"
    local repo="$2"
    local branch="${3:-main}"

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "[错误] 仓库信息不完整"
        return 1
    fi

    local api_url="https://api.github.com/repos/${owner}/${repo}/commits/${branch}"
    local response
    response=$(_fetch_github_api "$api_url" "Commits: $owner/$repo")

    if [ -z "$response" ]; then
        echo "[错误] 无法获取最新提交: $owner/$repo"
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r '.sha' 2>/dev/null
    else
        echo "$response" | sed -n 's/ *"sha": *"\([a-f0-9]\{40\}\)".*/\1/p' | head -1
    fi
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
