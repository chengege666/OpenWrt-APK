#!/bin/sh
# core/network.sh - 网络工具模块

CACHE_DIR="/root/apk-store/cache"
MAX_RETRIES=3
RETRY_DELAY=5

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

    while [ $retries -lt $MAX_RETRIES ]; do
        echo "[下载] $url (尝试 $((retries + 1))/$MAX_RETRIES)"
        
        if wget -q --timeout=30 -O "$output" "$url" 2>/dev/null; then
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

    echo "[错误] 下载失败: $url"
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
