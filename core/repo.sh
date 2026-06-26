#!/bin/sh
# core/repo.sh - 软件源管理模块

REPO_DISTFEEDS="/etc/apk/repositories.d/distfeeds.list"
REPO_BACKUP="/etc/apk-store-repo.backup"

# 切换前备份原始源文件（仅首次备份）
repo_backup_first() {
    if [ ! -f "$REPO_BACKUP" ] && [ -f "$REPO_DISTFEEDS" ]; then
        cp -f "$REPO_DISTFEEDS" "$REPO_BACKUP"
        echo "[备份] 原始源文件已备份至 ${REPO_BACKUP}"
    fi
}

# 检测目标源文件是否存在
repo_check_file() {
    if [ ! -f "$REPO_DISTFEEDS" ]; then
        echo "[错误] 未找到源文件: ${REPO_DISTFEEDS}"
        return 1
    fi
    return 0
}

# 将所有已知镜像恢复为 downloads.openwrt.org，确保能从任意源切换
_repo_reset_all() {
    sed -i 's|mirrors\.ustc\.edu\.cn/openwrt|downloads.openwrt.org|g' "$REPO_DISTFEEDS"
    sed -i 's|mirrors\.tuna\.tsinghua\.edu\.cn/openwrt|downloads.openwrt.org|g' "$REPO_DISTFEEDS"
}

repo_ustc() {
    repo_check_file || return
    repo_backup_first
    _repo_reset_all

    echo ""
    echo "[修改] 正在切换至中科大源..."
    sed -i 's|downloads.openwrt.org|mirrors.ustc.edu.cn/openwrt|g' "$REPO_DISTFEEDS"
    echo "[完成] 已切换至中科大源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_tsinghua() {
    repo_check_file || return
    repo_backup_first
    _repo_reset_all

    echo ""
    echo "[修改] 正在切换至清华源..."
    sed -i 's|downloads.openwrt.org|mirrors.tuna.tsinghua.edu.cn/openwrt|g' "$REPO_DISTFEEDS"
    echo "[完成] 已切换至清华源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_official() {
    repo_check_file || return
    repo_backup_first
    _repo_reset_all

    echo ""
    echo "[修改] 正在切换至官方源..."
    echo "[完成] 已切换至官方源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_restore() {
    if [ ! -f "$REPO_BACKUP" ]; then
        echo ""
        echo "[错误] 未找到备份文件，无法恢复"
        echo ""
        return
    fi

    echo ""
    echo "[恢复] 正在从备份恢复原始源文件..."
    cp -f "$REPO_BACKUP" "$REPO_DISTFEEDS"
    echo "[完成] 已恢复为默认源"
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

repo_show_current() {
    echo ""
    echo "================================"
    echo " 当前软件源"
    echo "================================"
    if [ ! -f "$REPO_DISTFEEDS" ]; then
        echo "[提示] 未找到源文件: ${REPO_DISTFEEDS}"
        echo ""
        return
    fi

    local name="未知源"
    if grep -q "mirrors.ustc.edu.cn" "$REPO_DISTFEEDS" 2>/dev/null; then
        name="中科大源 (USTC)"
    elif grep -q "mirrors.tuna.tsinghua.edu.cn" "$REPO_DISTFEEDS" 2>/dev/null; then
        name="清华源 (Tsinghua)"
    elif grep -q "downloads.openwrt.org" "$REPO_DISTFEEDS" 2>/dev/null; then
        name="官方源 (Official)"
    fi
    echo "当前源: ${name}"
    echo ""
    cat "$REPO_DISTFEEDS"
    echo ""
}

# 测试源延迟（ms）
repo_test_url() {
    local url="$1"
    local name="$2"
    local timeout=3

    # 从 URL 提取域名
    local domain
    domain=$(echo "$url" | sed 's|https\?://||;s|/.*$||')

    # 先用 ping 测 ICMP 延迟
    local result
    result=$(ping -c 1 -W "$timeout" "$domain" 2>/dev/null)
    local rc=$?

    if [ $rc -eq 0 ] && [ -n "$result" ]; then
        local time_val
        time_val=$(echo "$result" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -1)
        if [ -n "$time_val" ]; then
            local int_ms
            int_ms=$(echo "$time_val" | awk '{print int($1)}')
            if [ "$int_ms" -ge 1000 ] 2>/dev/null; then
                echo "  ${name}: ${time_val} ms (ping)"
            else
                echo "  ${name}: ${int_ms} ms (ping)"
            fi
            return
        fi
    fi

    # ping 失败时用 curl 兜底（绕过代理直连测试 HTTP 延迟）
    local curl_result
    curl_result=$(curl --noproxy '*' -o /dev/null -s -w '%{time_total}' --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null)
    local curl_rc=$?

    if [ $curl_rc -eq 0 ] && [ -n "$curl_result" ]; then
        local curl_ms
        curl_ms=$(echo "$curl_result" | awk '{printf "%.1f", $1 * 1000}')
        local int_curl_ms
        int_curl_ms=$(echo "$curl_result" | awk '{print int($1 * 1000)}')
        if [ "$int_curl_ms" -eq 0 ] 2>/dev/null; then
            echo "  ${name}: < 1 ms (curl)"
        elif [ "$int_curl_ms" -ge 1000 ] 2>/dev/null; then
            local sec
            sec=$(echo "$curl_result" | awk '{printf "%.2f", $1}')
            echo "  ${name}: ${sec} s (curl)"
        else
            echo "  ${name}: ${int_curl_ms} ms (curl)"
        fi
    else
        echo "  ${name}: 超时 / 不可达"
    fi
}

repo_test_latency() {
    echo ""
    echo "================================"
    echo " 测试源延迟"
    echo "================================"
    echo ""

    echo "正在测试以下源延迟:"
    echo ""

    repo_test_url "https://mirrors.ustc.edu.cn/openwrt/" "中科大源 (USTC)"
    repo_test_url "https://mirrors.tuna.tsinghua.edu.cn/openwrt/" "清华源 (Tsinghua)"
    repo_test_url "https://downloads.openwrt.org/" "官方源 (Official)"

    echo ""
}

repo_update() {
    echo ""
    echo "[更新] 正在刷新软件列表..."
    apk update
    echo ""
}

# 测速并自动应用最快源
_repo_get_latency_ms() {
    local url="$1"
    local domain
    domain=$(echo "$url" | sed 's|https\?://||;s|/.*$||')

    # 优先 ping
    local result
    result=$(ping -c 1 -W 3 "$domain" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        local time_val
        time_val=$(echo "$result" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -1)
        if [ -n "$time_val" ]; then
            echo "$(echo "$time_val" | awk '{printf "%.0f", $1}')"
            return 0
        fi
    fi

    # ping 失败用 curl 兜底
    local curl_result
    curl_result=$(curl --noproxy '*' -o /dev/null -s -w '%{time_total}' --connect-timeout 3 --max-time 3 "$url" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$curl_result" ]; then
        local curl_ms
        curl_ms=$(echo "$curl_result" | awk '{printf "%.0f", $1 * 1000}')
        echo "$curl_ms"
        return 0
    fi

    return 1
}

repo_test_and_apply() {
    echo ""
    echo "========================================"
    echo " 测速并自动应用最快源"
    echo "========================================"
    echo ""

    local result_file="/tmp/repo_speed_result.$$"
    rm -f "$result_file"

    # 逐行测速，避免管道子 shell 导致变量作用域问题
    _repo_test_one "ustc" "中科大源 (USTC)" "https://mirrors.ustc.edu.cn/openwrt/" "$result_file"
    _repo_test_one "tsinghua" "清华源 (Tsinghua)" "https://mirrors.tuna.tsinghua.edu.cn/openwrt/" "$result_file"
    _repo_test_one "official" "官方源 (Official)" "https://downloads.openwrt.org/" "$result_file"

    # 找出最快源（逐行比较，避免 sort 兼容性问题）
    if [ -f "$result_file" ]; then
        local best_key="" best_name="" best_url="" best_ms=99999

        while IFS='|' read -r k n u m; do
            [ -z "$k" ] && continue
            if [ "$m" -lt "$best_ms" ] 2>/dev/null; then
                best_key="$k"; best_name="$n"; best_url="$u"; best_ms="$m"
            fi
        done < "$result_file"
        rm -f "$result_file"

        if [ -n "$best_key" ]; then

            echo ""
            echo "========================================"
            echo " 最快源: ${best_name} - ${best_ms} ms"
            echo "========================================"
            echo ""

            printf "是否切换至 %s？(y/n): " "$best_name"
            local confirm
            read -r confirm < /dev/tty 2>/dev/null || read -r confirm
            case "$(echo "$confirm" | tr 'a-z' 'A-Z')" in
                Y|YES)
                    case "$best_key" in
                        ustc) repo_ustc ;;
                        tsinghua) repo_tsinghua ;;
                        official) repo_official ;;
                    esac
                    echo "[完成] 已切换至 ${best_name}"
                    ;;
                *)
                    echo "[取消] 未切换"
                    ;;
            esac
        fi
    else
        echo ""
        echo "[错误] 所有源均不可达"
    fi

    wait_for_enter
}

# 内部：测速单个源并记录结果到文件
_repo_test_one() {
    local key="$1"
    local name="$2"
    local url="$3"
    local outfile="$4"

    printf "  测速 %s ... " "$name"
    local ms
    ms=$(_repo_get_latency_ms "$url")
    if [ -n "$ms" ]; then
        echo "${ms} ms"
        echo "${key}|${name}|${url}|${ms}" >> "$outfile"
    else
        echo "超时 / 不可达"
    fi
}

# 软件源修改菜单（由 store.sh 回调）
modify_repo() {
    while true; do
        show_repo_menu
        printf "请选择: "
        read_input

        case "$choice" in
            1)
                repo_ustc
                wait_for_enter
                ;;
            2)
                repo_tsinghua
                wait_for_enter
                ;;
            3)
                repo_official
                wait_for_enter
                ;;
            4)
                repo_restore
                wait_for_enter
                ;;
            5)
                repo_show_current
                wait_for_enter
                ;;
            6)
                repo_test_latency
                wait_for_enter
                ;;
            7)
                repo_update
                wait_for_enter
                ;;
            8)
                repo_test_and_apply
                ;;
            0)
                return
                ;;
            *)
                echo "[错误] 无效输入，请重新选择"
                sleep 1
                ;;
        esac
    done
}
