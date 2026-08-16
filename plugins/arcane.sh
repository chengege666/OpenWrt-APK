#!/bin/sh
# plugins/arcane.sh - Arcane (Docker面板) 插件模块

install_arcane() {
    echo ""
    echo "================================"
    echo " 安装 Arcane (Docker面板)"
    echo "================================"
    echo ""

    if ! command -v docker >/dev/null 2>&1; then
        echo "[错误] 未检测到 Docker 环境，请先安装 Docker。"
        return 1
    fi

    echo "[配置] 正在准备 Arcane 目录..."
    local arcane_dir="/opt/arcane"
    local data_dir="$arcane_dir/data"
    local projects_dir="$arcane_dir/projects"

    mkdir -p "$data_dir" "$projects_dir"

    echo "[配置] 正在生成随机密钥..."
    local enc_key
    local jwt_secret
    if command -v openssl >/dev/null 2>&1; then
        enc_key=$(openssl rand -hex 16)
        jwt_secret=$(openssl rand -hex 16)
    else
        enc_key=$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32)
        jwt_secret=$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32)
    fi

    echo "[配置] 正在生成 docker-compose.yml..."
    cat > "$arcane_dir/docker-compose.yml" <<EOF
services:
  arcane:
    image: ghcr.io/getarcaneapp/manager:latest
    container_name: arcane
    ports:
      - '3552:3552'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - ./projects:/app/data/projects
    environment:
      - APP_URL=http://localhost:3552
      - ENCRYPTION_KEY=$enc_key
      - JWT_SECRET=$jwt_secret
      - TZ=Asia/Shanghai
    restart: unless-stopped
EOF

    echo "[启动] 正在拉取镜像并启动容器..."
    cd "$arcane_dir" || return 1
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    local status=$?
    if [ $status -eq 0 ]; then
        echo "[成功] Arcane 已启动，访问地址: http://<路由器IP>:3552"
        echo "[账号] 默认用户名: arcane"
        echo "[账号] 默认密码:   arcane-admin"
        echo "[提示] 首次登录后会强制要求修改密码，请妥善保存。"
        show_success
    else
        echo "[错误] Arcane 启动失败。"
        echo "[提示] 如果您看到 'failed to mount /tmp/containerd-mount... err: invalid argument'，这通常是因为 OpenWrt 系统底层的 overlayfs 不支持 index=off 或者当前所在的文件系统不支持 overlay 挂载。"
        echo "[修复建议] 请检查 Docker 的存储驱动设置，或将 Docker 根目录移动到 ext4/f2fs 分区。"
        return 1
    fi
}

uninstall_arcane() {
    echo ""
    echo "================================"
    echo " 卸载 Arcane (Docker面板)"
    echo "================================"
    echo ""

    local arcane_dir="/opt/arcane"

    if [ -d "$arcane_dir" ]; then
        echo "[卸载] 正在停止 Arcane 容器..."
        cd "$arcane_dir" || return 1
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose down
        else
            docker compose down
        fi
        cd - >/dev/null || true
    else
        echo "[提示] 未找到 Arcane 目录，尝试强制删除容器..."
        docker rm -f arcane 2>/dev/null || true
    fi

    echo "[清理] 正在删除 Arcane 配置和数据目录 ($arcane_dir)..."
    rm -rf "$arcane_dir"

    echo "[清理] 正在删除镜像缓存..."
    docker rmi ghcr.io/getarcaneapp/manager:latest 2>/dev/null || true

    echo "[成功] 卸载清理完成"
}

update_arcane() {
    echo ""
    echo "================================"
    echo " 更新 Arcane (Docker面板)"
    echo "================================"
    echo ""

    local arcane_dir="/opt/arcane"

    if [ ! -d "$arcane_dir" ]; then
        echo "[错误] 未找到 Arcane 目录，可能未安装或安装路径异常。"
        return 1
    fi

    echo "[更新] 正在拉取最新镜像并重启..."
    cd "$arcane_dir" || return 1
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose pull
        docker-compose up -d
    else
        docker compose pull
        docker compose up -d
    fi

    local status=$?
    if [ $status -eq 0 ]; then
        echo "[成功] Arcane 更新完成"
        show_success
    else
        echo "[错误] Arcane 更新失败"
        return 1
    fi
}