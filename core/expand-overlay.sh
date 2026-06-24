#!/bin/sh
# core/expand-overlay.sh - overlay 管理（扩容 / 还原）
# 调用方式: expand_overlay
# 子菜单:
#   1. 扩容 overlay
#   2. 还原 overlay（恢复到内部存储）

expand_overlay() {
    while true; do
        echo ""
        echo "================================"
        echo " Overlay 管理"
        echo "================================"
        echo ""
        echo "  1. 扩容 overlay"
        echo "  2. 还原 overlay（恢复到内部存储）"
        echo "  0. 返回"
        echo ""
        printf "请选择: "; read -r sel < /dev/tty 2>/dev/null || read -r sel
        sel=$(echo "$sel" | tr -d '\r\n ')

        case "$sel" in
            1) _do_expand_overlay; wait_for_enter ;;
            2) _revert_overlay; wait_for_enter ;;
            0) return ;;
            *) echo "[错误] 无效选择"; sleep 1 ;;
        esac
    done
}

# ============================================================
# 扩容 overlay
# ============================================================
_do_expand_overlay() {
    echo ""
    echo "============================================"
    echo " OpenWrt overlay 自定义扩容"
    echo "============================================"
    echo ""

    # 前置检查
    [ "$(id -u)" = "0" ] || { echo "[错误] 请使用 root 用户执行"; return 1; }
    mount | grep -q "overlayfs:/overlay on /" || {
        echo "[错误] 当前系统未使用 overlayfs"
        mount | grep " on / " || true
        return 1
    }

    # 检测当前 overlay 来源
    local overlay_src
    overlay_src=$(df /overlay 2>/dev/null | awk 'NR==2{print $1}')
    echo "当前 /overlay 来源: $overlay_src"
    case "$overlay_src" in
        /dev/mmcblk*|/dev/sd*|/dev/nvme*|/dev/vd*|/dev/xvd*)
            echo "  已是完整分区，无需扩容"
            return 0
            ;;
    esac
    echo ""

    # 安装必要工具
    echo "[安装] 必要工具..."
    local pkg_mgr="apk"
    command -v apk >/dev/null 2>&1 || pkg_mgr="opkg"
    for pkg in block-mount e2fsprogs kmod-fs-ext4 parted; do
        if [ "$pkg_mgr" = "apk" ]; then
            apk info -e "$pkg" >/dev/null 2>&1 && continue
            echo "  $pkg ..."; apk add "$pkg" >/dev/null 2>&1 || echo "  [失败] $pkg"
        else
            opkg list-installed 2>/dev/null | grep -q "^${pkg} " && continue
            echo "  $pkg ..."; opkg install "$pkg" >/dev/null 2>&1 || echo "  [失败] $pkg"
        fi
    done

    # 列出可用磁盘
    local tmpfile="/tmp/expand_disks.$$"
    : > "$tmpfile"
    local idx=1
    for d in /dev/mmcblk[0-9] /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z] /dev/xvd[a-z]; do
        [ -b "$d" ] || continue
        local sz end_mb free_mb model
        sz=$(parted -m "$d" unit MiB print 2>/dev/null | awk -F: 'NR==2{gsub(/MiB/,"",$2); print int($2)}')
        [ -n "$sz" ] || continue
        end_mb=$(parted -m "$d" unit MiB print 2>/dev/null | awk -F: 'END{print $3}')
        end_mb="${end_mb%MiB}"; end_mb=$(printf "%.0f" "$end_mb" 2>/dev/null || echo 0)
        [ -n "$end_mb" ] || continue
        free_mb=$((sz - end_mb)); [ "$free_mb" -ge 512 ] || continue
        model=$(cat "/sys/block/$(basename "$d")/device/model" 2>/dev/null || echo "-")
        echo "$idx $d $sz $free_mb" >> "$tmpfile"
        echo "  [$idx] $d | ${model} | 总: ${sz}MiB | 可用: ${free_mb}MiB"
        idx=$((idx + 1))
    done

    local cnt=$(wc -l < "$tmpfile" | tr -d ' ')
    [ "$cnt" -gt 0 ] || { rm -f "$tmpfile"; echo "[错误] 无可用磁盘"; return 1; }

    # 选择磁盘
    local disk=""
    if [ "$cnt" -eq 1 ]; then
        disk=$(awk 'NR==1{print $2}' "$tmpfile"); echo "自动选择: $disk"
    else
        printf "选择磁盘编号: "; read -r sel < /dev/tty 2>/dev/null || read -r sel
        sel=$(echo "$sel" | tr -d '\r\n ')
        disk=$(awk -v id="$sel" '$1==id{print $2}' "$tmpfile")
        [ -n "$disk" ] || { rm -f "$tmpfile"; echo "[错误] 无效选择"; return 1; }
    fi

    local disk_sz free_mb
    disk_sz=$(awk -v d="$disk" '$2==d{print $3}' "$tmpfile")
    free_mb=$(awk -v d="$disk" '$2==d{print $4}' "$tmpfile")
    rm -f "$tmpfile"
    local max_mb=$((free_mb - 16))
    [ "$max_mb" -ge 512 ] || { echo "[错误] 可用空间不足 512MiB"; return 1; }
    echo "  可用: ${free_mb}MiB, 最大 overlay: ${max_mb}MiB"
    echo ""

    # 选择大小
    echo "选择 overlay 大小："
    echo "  1. 用满剩余空间（推荐）"
    echo "  2. 自定义大小（单位 MiB，如 4096=4G）"
    echo ""
    printf "请选择 [1/2] (默认 1): "; read -r mode_sel < /dev/tty 2>/dev/null || read -r mode_sel
    mode_sel=$(echo "$mode_sel" | tr -d '\r\n ')

    local size_mb=0
    case "$mode_sel" in
        2)
            echo "最大可用: ${max_mb}MiB"
            printf "输入大小 (MiB, 默认 4096): "; read -r si < /dev/tty 2>/dev/null || read -r si
            si=$(echo "$si" | tr -d '\r\n ' | tr 'A-Z' 'a-z')
            case "$si" in
                ""|4096) size_mb=4096 ;;
                all)     size_mb=$max_mb ;;
                [0-9]*)  size_mb=$si ;;
                *)       size_mb=4096 ;;
            esac
            ;;
        *)
            size_mb=$max_mb
            echo "  使用全部剩余空间: ${size_mb}MiB"
            ;;
    esac
    [ "$size_mb" -ge 512 ]  || size_mb=512
    [ "$size_mb" -le "$max_mb" ] || size_mb=$max_mb

    local end_mb
    end_mb=$(parted -m "$disk" unit MiB print 2>/dev/null | awk -F: 'END{print $3}')
    end_mb="${end_mb%MiB}"; end_mb=$(printf "%.0f" "$end_mb" 2>/dev/null || echo 0)
    local start=$((end_mb + 1)) finish=$((start + size_mb))
    echo "  起始: ${start}MiB, 结束: ${finish}MiB, 大小: ${size_mb}MiB"
    echo ""

    # 最终确认
    echo "[警告] 即将修改分区表！"
    printf "确认继续？(y/N): "; read -r confirm < /dev/tty 2>/dev/null || read -r confirm
    [ "$(echo "$confirm" | tr 'a-z' 'A-Z')" = "Y" ] || { echo "[取消]"; return 0; }

    # 检查/创建分区表
    local label
    label=$(parted -m "$disk" unit MiB print 2>/dev/null | awk -F: 'NR==2{print $6}')
    if [ -z "$label" ] || [ "$label" = "unknown" ]; then
        echo "[分区表] 无分区表，创建 GPT"
        parted -s "$disk" mklabel gpt
        sleep 2
    fi

    # 创建分区
    echo "[创建] 分区 ${start}MiB - ${finish}MiB"
    parted -s "$disk" unit MiB mkpart primary ext4 "${start}" "${finish}"
    sleep 3; partprobe "$disk" 2>/dev/null || true; sleep 3; block info >/dev/null 2>&1 || true; sleep 2

    # 获取新分区设备名（取 parted 输出中最后一个分区的编号）
    local pn
    pn=$(parted -m "$disk" unit MiB print 2>/dev/null | awk -F: 'NR>2{last=$1}END{print last}')
    local new_part=""
    case "$disk" in /dev/mmcblk*|/dev/nvme*) new_part="${disk}p${pn}" ;; *) new_part="${disk}${pn}" ;; esac
    [ -b "$new_part" ] || { echo "[错误] 分区未出现: $new_part"; return 1; }
    echo "  新分区: $new_part"

    # 格式化
    echo "[格式化] ext4 (openwrt_overlay)"
    mkfs.ext4 -F -L openwrt_overlay "$new_part"

    # 迁移数据
    echo "[迁移] overlay 数据..."
    mkdir -p /mnt/new_overlay
    mount "$new_part" /mnt/new_overlay && tar -C /overlay -cpf - . | tar -C /mnt/new_overlay -xpf -
    sync; umount /mnt/new_overlay
    echo "  完成"

    # 写入 fstab
    local uuid=$(block info "$new_part" | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')
    [ -n "$uuid" ] || { echo "[错误] 无法获取 UUID"; return 1; }
    uci -q delete fstab.universal_overlay || true
    uci set fstab.universal_overlay="mount"
    uci set fstab.universal_overlay.target="/overlay"
    uci set fstab.universal_overlay.uuid="$uuid"
    uci set fstab.universal_overlay.fstype="ext4"
    uci set fstab.universal_overlay.enabled="1"
    uci set fstab.universal_overlay.enabled_fsck="1"
    uci commit fstab
    /etc/init.d/fstab enable 2>/dev/null || true

    # 写入 rc.local fallback（sysupgrade -n 后 fstab 丢失时的兜底）
    local rc_local="/etc/rc.local"
    local fallback_marker="# EXPAND_OVERLAY_FALLBACK"
    if grep -q "$fallback_marker" "$rc_local" 2>/dev/null; then
        # 已有 fallback，更新 UUID
        sed -i "/$fallback_marker/,/^fi/d" "$rc_local"
    fi
    # 在 exit 0 之前插入
    sed -i '/^exit 0/i '"$fallback_marker"'\nif ! mount | grep -q " /overlay "; then\n  [ -b /dev/disk/by-uuid/'"$uuid"' ] && mount /dev/disk/by-uuid/'"$uuid"' /overlay 2>/dev/null || true\nfi' "$rc_local"
    chmod +x "$rc_local"
    echo "  [rc.local] fallback 已写入（UUID: $uuid）"

    echo ""
    echo "================================"
    echo " overlay 扩容完成"
    echo "  分区: $new_part"
    echo "  UUID: $uuid"
    echo "  大小: ${size_mb}MiB"
    echo "================================"
    printf "立即重启？(y/N): "; read -r rb < /dev/tty 2>/dev/null || read -r rb
    [ "$(echo "$rb" | tr 'a-z' 'A-Z')" = "Y" ] && reboot || echo "稍后手动: reboot"
}

# ============================================================
# 还原 overlay 扩容（恢复到内部 loop0）
# ============================================================
_revert_overlay() {
    echo ""
    echo "============================================"
    echo " 还原 overlay 扩容"
    echo "============================================"
    echo ""

    [ "$(id -u)" = "0" ] || { echo "[错误] 请使用 root 用户执行"; return 1; }

    # 检测当前是否在使用外部分区
    local overlay_src
    overlay_src=$(df /overlay 2>/dev/null | awk 'NR==2{print $1}')
    echo "当前 overlay 来源: $overlay_src"

    case "$overlay_src" in
        /dev/loop0|/dev/loop1)
            echo "当前已是内部 loop 设备，无需还原"
            return 0
            ;;
        /dev/mmcblk*|/dev/sd*|/dev/nvme*|/dev/vd*|/dev/xvd*)
            echo "检测到外部分区: $overlay_src"
            ;;
        *)
            echo "[警告] 无法确认 overlay 来源: $overlay_src"
            ;;
    esac

    # 检查是否有 fstab 条目
    local has_fstab=0
    if uci -q get fstab.universal_overlay >/dev/null 2>&1; then
        has_fstab=1
        echo "  [发现] fstab 配置"
    fi

    local has_rc=0
    if grep -q "EXPAND_OVERLAY_FALLBACK" /etc/rc.local 2>/dev/null; then
        has_rc=1
        echo "  [发现] rc.local fallback"
    fi

    if [ "$has_fstab" -eq 0 ] && [ "$has_rc" -eq 0 ]; then
        echo "[提示] 未发现扩容配置，无需还原"
        return 0
    fi

    echo ""
    echo "[警告] 还原后将恢复到内部存储空间"
    echo "  外部分区上的数据不会删除，但不再自动挂载"
    printf "确认还原？(y/N): "; read -r confirm < /dev/tty 2>/dev/null || read -r confirm
    [ "$(echo "$confirm" | tr 'a-z' 'A-Z')" = "Y" ] || { echo "[取消]"; return 0; }
    echo ""

    # 删除 fstab 条目
    if [ "$has_fstab" -eq 1 ]; then
        echo "[删除] fstab 配置"
        uci -q delete fstab.universal_overlay || true
        uci commit fstab
    fi

    # 删除 rc.local fallback
    if [ "$has_rc" -eq 1 ]; then
        echo "[删除] rc.local fallback"
        sed -i '/EXPAND_OVERLAY_FALLBACK/,/^fi/d' /etc/rc.local
    fi

    echo ""
    echo "================================"
    echo " 还原完成"
    echo "================================"
    echo "重启后将恢复到内部存储空间"
    printf "立即重启？(y/N): "; read -r rb < /dev/tty 2>/dev/null || read -r rb
    [ "$(echo "$rb" | tr 'a-z' 'A-Z')" = "Y" ] && reboot || echo "稍后手动: reboot"
}
