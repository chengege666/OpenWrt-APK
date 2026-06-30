# OpenWrt APK Store

OpenWrt APK 应用商店 - 一键插件安装系统

适配 OpenWrt / ImmortalWrt / iStoreOS

## 功能特性

- 一键安装/卸载/更新插件
- 自动识别系统架构（x86_64/aarch64/arm/mipsel/mips/riscv64）
- 自动获取 GitHub Releases 最新版本
- 自动修复依赖 & 重启 LuCI
- 系统初始化（时区/中文界面/SFTP/基础工具）
- Overlay 扩容（支持自定义大小 / 还原）
- APK 安装参数配置（--allow-untrusted 开关）
- 支持一键更新全部插件
- 一键配置启动快捷键
- 支持管道安装（wget -O- | sh）

## 一键安装

### GitHub

```sh
wget -O- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh | sh
```

### Gitee

```sh
wget -O- https://gitee.com/chengege666/OpenWrt-APK/raw/main/install.sh | sh
```

### 短链接

```sh
bash <(curl -sL https://lj.1231818.xyz/apk)
```

### 手动安装

#### GitHub

```sh
git clone https://github.com/chengege666/OpenWrt-APK.git
cd OpenWrt-APK
chmod +x store.sh
./store.sh
```

#### Gitee

```sh
git clone https://gitee.com/chengege666/OpenWrt-APK.git
cd OpenWrt-APK
chmod +x store.sh
./store.sh
```

## 目录结构

```
OpenWrt-APK/
├── store.sh              # 主安装器（交互式菜单）
├── install.sh            # 一键安装脚本
├── core/
│   ├── network.sh        # 网络工具模块（下载/缓存/网络检测）
│   ├── github.sh         # GitHub Releases API 模块
│   ├── install.sh        # 安装/卸载/重启模块
│   ├── ui.sh             # 用户界面模块
│   ├── system-init.sh    # 系统初始化（时区/中文/SFTP/工具）
│   ├── expand-overlay.sh # Overlay 扩容 & 还原
│   ├── doctor.sh         # 系统信息查看
│   └── apk-opts.sh       # APK 安装参数配置（--allow-untrusted 开关）
└── plugins/
    ├── openclash.sh          # OpenClash
    ├── passwall.sh           # PassWall
    ├── passwall2.sh          # PassWall2
    ├── mosdns.sh             # MosDNS
    ├── docker.sh             # Docker
    ├── smartdns.sh           # SmartDNS
    ├── lucky.sh              # Lucky
    ├── daed.sh               # Daed
    ├── nikki.sh              # Nikki
    ├── taskplan.sh           # TaskPlan
    ├── istore.sh             # iStore
    ├── luci-app-diskman.sh   # DiskMan
    ├── luci-app-wechatpush.sh# WeChatPush
    ├── luci-theme-argon.sh   # Argon 主题
    └── luci-theme-aurora.sh  # Aurora 主题
```

## 主菜单

```
================================
 OpenWrt APK Store
================================

1.   安装插件
2.   卸载插件
3.   更新插件
4.   一键配置启动快捷键
5.   基础初始化（时区 / 中文 / SFTP / 工具）
6.   自定义 overlay 扩容
7.   查看系统信息
8.   APK 安装参数 (--allow-untrusted)
00.  卸载脚本
000. 更新脚本
0.   退出
```

### 选项说明

| 选项 | 功能 |
|------|------|
| 1 | 安装插件（15+ 插件子菜单） |
| 2 | 卸载插件 |
| 3 | 更新插件（含一键更新全部） |
| 4 | 设置单字母快捷键启动脚本 |
| 5 | 设置时区、安装中文包/SFTP/curl，修复 wget |
| 6 | Overlay 管理（扩容 / 还原到内部存储） |
| 7 | 查看固件版本、架构、磁盘、内存、overlay 使用率 |
| 8 | 开启/关闭 `--allow-untrusted` 签名验证 |

## 系统初始化

安装菜单选项 5，功能包括：

- 设置时区 `Asia/Shanghai`
- 恢复 wget 指向（适配 apk 环境）
- 更新包索引
- 安装基础包：`ca-bundle`、`curl`、`openssh-sftp-server`、中文语言包
- 重启 dropbear 使 SFTP 可用
- 刷新 LuCI 界面

## Overlay 扩容

通过菜单选项 6 进入 overlay 管理子菜单：

```
==========================
 Overlay 管理
==========================

  1. 扩容 overlay
  2. 还原 overlay（恢复到内部存储）
  0. 返回
```

### 扩容流程

1. 检测当前 overlay 来源
2. 自动安装必需工具（`block-mount`、`e2fsprogs`、`kmod-fs-ext4`、`parted`）
3. 列出可用磁盘及剩余空间
4. 选择磁盘 → 选择大小（用满剩余空间或自定义）
5. 创建 GPT 分区表（如需要）→ 创建 ext4 分区
6. 迁移现有 overlay 数据 → 写入 fstab 自动挂载
7. 可选立即重启

> 扩容不覆盖固件，所有软件包和配置均迁移到外部分区。
> sysupgrade（保留配置）后正常使用，sysupgrade -n 时 rc.local fallback 自动兜底。

### 还原

- 删除 fstab 配置和 rc.local fallback
- 重启后恢复到内部 loop 存储
- 外部分区数据不会自动删除

## APK 安装参数配置

管理 `--allow-untrusted` 开关，持久化配置保存在 `/etc/apk-store.conf`。影响 LuCI 网页上传安装和命令行 apk add。

### 在菜单中使用

主菜单选 **8** 进入交互式开关。

### 一键独立安装

```sh
# 短链接
bash <(curl -sL https://lj.1231818.xyz/kg)
```
# GitHub 直连
```sh
bash <(curl -sL https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/core/apk-opts.sh)
```
# Gitee 直连
```sh
bash <(curl -sL https://gitee.com/chengege666/OpenWrt-APK/raw/main/core/apk-opts.sh)
```

### 脚本内调用

```sh
. /root/apk-store/core/apk-opts.sh
apk_opts_init
apk add $(apk_get_opts) /path/to/package.apk
```

## 支持的插件

| 插件 | 说明 |
|------|------|
| OpenClash | 透明代理工具 |
| PassWall | 科学上网 |
| PassWall2 | 科学上网 |
| Nikki | 科学上网 |
| Daed | 科学上网 |
| MosDNS | DNS 分流解析 |
| AdGuardHome | 广告过滤 |
| Docker | 容器管理 |
| SmartDNS | DNS 本地加速 |
| Lucky | 综合网络工具（DDNS/Stun/Webhook） |
| TaskPlan | 定时任务管理 |
| iStore | 软件商店 |
| DiskMan | 磁盘管理 |
| WeChatPush | 微信消息推送 |
| Argon 主题 | 后台主题美化 |
| Aurora 主题 | 后台主题美化 |

## 添加新插件

在 `plugins/` 目录下创建新的插件脚本，参考现有插件模板：

```sh
#!/bin/sh
# plugins/your_plugin.sh

install_your_plugin() {
    local owner="owner"
    local repo="repo"
    local plugin_name="plugin"

    # 获取最新 Release
    local release_json
    release_json=$(get_latest_release "$owner" "$repo") || return 1

    local tag
    tag=$(get_release_tag "$release_json")
    echo "[版本] $tag"

    # 获取下载链接
    local all_urls
    all_urls=$(get_download_urls "$release_json" "$owner" "$repo" "$tag")

    # 过滤并下载
    local url
    url=$(echo "$all_urls" | grep "xxx.apk" | head -1)
    # ... 下载、安装逻辑
}

uninstall_your_plugin() {
    uninstall_plugin "luci-app-xxx"
}

update_your_plugin() {
    cleanup_old_cache
    install_your_plugin
}
```

然后在 `store.sh` 中引入并添加到菜单。

### 核心函数说明

| 函数 | 说明 |
|------|------|
| `get_latest_release owner/repo` | 获取最新 Release JSON |
| `get_release_tag json` | 提取版本号 |
| `get_download_urls json owner repo tag` | 获取所有下载链接（含 HTML 回退机制） |
| `download_file url output_path` | 下载文件（含镜像加速、重试） |
| `fix_dependencies` | 修复依赖 |
| `restart_luci` | 重启 LuCI 界面 |

## 技术栈

- Shell（兼容 BusyBox ash）
- wget / curl
- GitHub API
- APK / OPKG 包管理
- parted / ext4 / overlayfs

## 许可证

GPL-3.0
