#!/bin/sh
# core/network.sh - 网络工具模块

CACHE_DIR="/root/apk-store/cache"
MAX_RETRIES=3
RETRY_DELAY=5

# GitHub 镜像加速配置
MIRROR_CONFIG="/root/apk-store/mirror.conf"
[ -f "$MIRROR_CONFIG" ] && . "$MIRROR_CONFIG"

check_internet() {
    wget -q --spider --timeout=5 https://github.com 2>/dev/null
    return $?
}

download_file() {
    local url="$1"
    local output="$2"
    local retries=0

    if [ -z "$url" ]; then
        echo "[错误] 下载链接为空"
        return 1
    fi

    if [ -z "$output" ]; then
        echo "[错误] 输出路径为空"
        return 1
    fi

    mkdir -p "$(dirname "$output")"

    # 如果启用了镜像且是 GitHub 链接，优先走镜像
    local primary_url="$url"
    local fallback_url=""

    if [ -n "$GITHUB_MIRROR" ] && echo "$url" | grep -q "github\\.com"; then
        primary_url="${GITHUB_MIRROR%/}/${url}"
        fallback_url="$url"
        echo "[镜像] 使用加速镜像: $GITHUB_MIRROR"
    fi

    # 尝试主 URL（可能是镜像）
    retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        echo "[下载] $(basename "$output") (尝试 $((retries + 1))/$MAX_RETRIES)"
        
        if wget -q --timeout=30 -O "$output" "$primary_url" 2>/dev/null; then
            if [ -f "$output" ] && [ -s "$output" ]; then
                echo "[成功] 下载完成: $output"
                return 0
            else
                echo "[警告] 下载文件为空，重试..."
                rm -f "$output"
            fi
        else
            echo "[警告] 下载失败，重试..."
            rm -f "$output"
        fi

        retries=$((retries + 1))
        sleep $RETRY_DELAY
    done

    # 有回退 URL 则尝试直连
    if [ -n "$fallback_url" ]; then
        echo "[回退] 镜像下载失败，尝试直连..."
        retries=0
        while [ $retries -lt $MAX_RETRIES ]; do
            echo "[下载] $(basename "$output") (直连 $((retries + 1))/$MAX_RETRIES)"
            
            if wget -q --timeout=30 -O "$output" "$fallback_url" 2>/dev/null; then
                if [ -f "$output" ] && [ -s "$output" ]; then
                    echo "[成功] 下载完成: $output"
                    return 0
                else
                    rm -f "$output"
                fi
            fi
            retries=$((retries + 1))
            sleep $RETRY_DELAY
        done
    fi

    echo "[错误] 下载失败: $(basename "$output")"
    return 1
}

cleanup_cache() {
    echo "[清理] 清理缓存目录: $CACHE_DIR"
    rm -rf "$CACHE_DIR"
    mkdir -p "$CACHE_DIR"
}

init_cache() {
    mkdir -p "$CACHE_DIR"
}

# 设置 GitHub 镜像加速地址
# 参数 $1: 镜像地址（可选，缺省使用 https://gh.1231818.xyz/）
set_github_mirror() {
    local mirror_url="${1:-https://gh.1231818.xyz/}"

    mkdir -p "$(dirname "$MIRROR_CONFIG")"
    echo "# GitHub 镜像加速配置"  > "$MIRROR_CONFIG"
    echo "GITHUB_MIRROR=\"${mirror_url}\"" >> "$MIRROR_CONFIG"
    GITHUB_MIRROR="$mirror_url"

    echo "[成功] GitHub 镜像加速已启用: ${mirror_url}"
}

# 关闭 GitHub 镜像加速
disable_github_mirror() {
    if [ -f "$MIRROR_CONFIG" ]; then
        rm -f "$MIRROR_CONFIG"
        unset GITHUB_MIRROR
        echo "[成功] GitHub 镜像加速已关闭"
    else
        echo "[提示] 镜像加速未启用，无需关闭"
    fi
}
