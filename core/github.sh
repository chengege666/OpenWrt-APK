#!/bin/sh
# core/github.sh - GitHub Releases API 模块

_GITHUB_UA="OpenWrt-APK-Store/1.0"

# 内部函数：通过镜像获取 GitHub API 响应（带请求头）
_fetch_github_api() {
    local url="$1"
    local desc="$2"
    local response=""

    # 有镜像则走镜像
    if [ -n "$GITHUB_MIRROR" ]; then
        local proxied_url="${GITHUB_MIRROR%/}/${url}"
        response=$(wget -q --timeout=15 \
            --user-agent="$_GITHUB_UA" \
            --header="Accept: application/vnd.github+json" \
            -O- "$proxied_url" 2>/dev/null)
        if [ -n "$response" ]; then
            case "$response" in
                [{\[]*) echo "$response"; return 0 ;;
            esac
            echo "[警告] 镜像返回非 JSON 数据，尝试直连..." >&2
        fi
    fi

    # 直连带请求头
    response=$(wget -q --timeout=15 \
        --user-agent="$_GITHUB_UA" \
        --header="Accept: application/vnd.github+json" \
        -O- "$url" 2>/dev/null)
    if [ -n "$response" ]; then
        case "$response" in
            [{\[]*) echo "$response"; return 0 ;;
        esac
    fi

    # 不带请求头再试一次（兼容某些代理/镜像）
    response=$(wget -q --timeout=15 -O- "$url" 2>/dev/null)
    if [ -n "$response" ]; then
        case "$response" in
            [{\[]*) echo "$response"; return 0 ;;
        esac
    fi

    return 1
}

# 解析 JSON 字段（优先 jsonfilter，次选 jq，最后 sed）
_json_get() {
    local json="$1"
    local expr="$2"

    if command -v jsonfilter >/dev/null 2>&1; then
        echo "$json" | jsonfilter -e "$expr" 2>/dev/null
    elif command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r "$expr" 2>/dev/null
    else
        return 1
    fi
}

# 获取所有下载 URL（优先 jsonfilter，回退 sed）
_get_urls_from_json() {
    local json="$1"
    local urls

    urls=$(_json_get "$json" '@.assets[*].browser_download_url')
    if [ -n "$urls" ]; then
        echo "$urls"
        return 0
    fi

    # sed 回退
    echo "$json" | sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p'
}

# HTML 回退：从 Release 页面解析下载链接
_fetch_asset_urls_fallback() {
    local owner="$1"
    local repo="$2"
    local tag="$3"

    local html_url="https://github.com/${owner}/${repo}/releases/expanded_assets/${tag}"
    local html
    html=$(wget -q --timeout=15 --user-agent="$_GITHUB_UA" -O- "$html_url" 2>/dev/null)
    [ -z "$html" ] && return 1

    # 提取所有下载链接，拼接完整 URL
    echo "$html" | grep -o '/[^"'"'"']*' | grep "/releases/download/" | sort -u | sed 's|^|https://github.com|'
}

get_latest_release() {
    local owner="$1"
    local repo="$2"

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "[错误] 仓库信息不完整" >&2
        return 1
    fi

    local api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
    local response
    response=$(_fetch_github_api "$api_url" "Releases: $owner/$repo")

    if [ -z "$response" ]; then
        echo "[错误] 无法获取 GitHub Releases: $owner/$repo" >&2
        return 1
    fi

    echo "$response"
}

get_latest_commit_sha() {
    local owner="$1"
    local repo="$2"
    local branch="${3:-main}"

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "[错误] 仓库信息不完整" >&2
        return 1
    fi

    local api_url="https://api.github.com/repos/${owner}/${repo}/commits/${branch}"
    local response
    response=$(_fetch_github_api "$api_url" "Commits: $owner/$repo")

    if [ -z "$response" ]; then
        echo "[错误] 无法获取最新提交: $owner/$repo" >&2
        return 1
    fi

    local sha
    sha=$(_json_get "$response" '@.sha')
    if [ -n "$sha" ]; then
        echo "$sha"
        return 0
    fi

    # sed 回退
    echo "$response" | sed -n 's/ *"sha": *"\([a-f0-9]\{40\}\)".*/\1/p' | head -1
}

get_release_tag() {
    local json="$1"

    local tag
    tag=$(_json_get "$json" '@.tag_name')
    if [ -n "$tag" ]; then
        echo "$tag"
        return 0
    fi

    # sed 回退
    echo "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
}

get_download_urls() {
    local json="$1"
    local owner="$2"
    local repo="$3"
    local tag="$4"

    # 1. 优先从 JSON 提取
    local urls
    urls=$(_get_urls_from_json "$json")
    if [ -n "$urls" ]; then
        echo "$urls"
        return 0
    fi

    # 2. JSON 无数据，尝试 HTML 回退
    if [ -n "$owner" ] && [ -n "$repo" ] && [ -n "$tag" ]; then
        echo "[回退] 尝试从 Release 页面解析下载链接..." >&2
        urls=$(_fetch_asset_urls_fallback "$owner" "$repo" "$tag")
        if [ -n "$urls" ]; then
            echo "$urls"
            return 0
        fi
    fi

    return 1
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

# 通用版本回退：在旧版本中查找第一个包含指定资产匹配模式的版本
# 输出：第一行 = tag，后续行 = 匹配资产的下载 URL（含多行）
# 参数：
#   $1 - owner
#   $2 - repo
#   $3 - 跳过版本 tag（当前最新版）
#   $4 - URL 匹配模式（awk regex，如 "\\.apk$"）
#   $5 - 名称额外匹配模式（可选，awk regex，如 "luci-app-taskplan-"）
find_asset_in_older_releases() {
    local owner="$1"
    local repo="$2"
    local skip_tag="$3"
    local url_pattern="$4"
    local name_pattern="$5"

    [ -z "$owner" ] || [ -z "$repo" ] && return 1

    local api_url="https://api.github.com/repos/${owner}/${repo}/releases?per_page=30"
    local releases_list
    releases_list=$(_fetch_github_api "$api_url" "Releases list: $owner/$repo")
    [ -z "$releases_list" ] && return 1

    # awk 解析 tag + browser_download_url，找到第一个匹配的版本
    local result
    result=$(echo "$releases_list" | awk -v skip="$skip_tag" -v upat="$url_pattern" -v npat="$name_pattern" '
    BEGIN { tag = ""; found = 0; output = "" }
    /"tag_name":/ {
        if (found && tag != "" && tag != skip) {
            print tag
            print output
            exit 0
        }
        gsub(/.*"tag_name": *"/, "");
        gsub(/".*/, "");
        tag = $0;
        found = 0;
        output = "";
    }
    /"browser_download_url":/ {
        gsub(/.*"browser_download_url": *"/, "");
        gsub(/".*/, "");
        url = $0;
        if (url ~ upat) {
            if (npat == "" || url ~ npat) {
                found = 1;
                if (output != "") output = output "\n";
                output = output url;
            }
        }
    }
    END {
        if (found && tag != "" && tag != skip) {
            print tag
            print output
        }
    }
    ')

    [ -z "$result" ] && return 1
    echo "$result"
    return 0
}
