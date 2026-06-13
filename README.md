# OpenWrt APK Store

OpenWrt APK 应用商店 - 一键插件安装系统

适配 OpenWrt / ImmortalWrt / iStoreOS

## 功能特性

- 一键安装插件
- 自动识别系统架构（x86_64/aarch64/arm/mipsel/mips/riscv64）
- 自动获取 GitHub Releases 最新版本
- 自动安装依赖
- 自动安装中文包
- 自动修复依赖
- 自动重启 LuCI
- 插件卸载
- 插件更新（支持一键更新全部）
- 一键配置启动快捷键
- 自动更新脚本
- 支持管道安装（wget -O- | sh）

## 一键安装

```sh
wget -O- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh | sh
```

## 短链接
```sh
bash <(curl -sL https://lj.1231818.xyz/apk)
```
## 手动安装

```sh
git clone https://github.com/chengege666/OpenWrt-APK.git
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
│   ├── network.sh        # 网络工具模块
│   ├── github.sh         # GitHub Releases API 模块
│   ├── install.sh        # APK 安装模块
│   ├── apk-opts.sh       # APK 安装参数配置（--allow-untrusted 开关）
│   └── ui.sh             # 用户界面模块
└── plugins/
    ├── openclash.sh      # OpenClash 插件
    ├── passwall2.sh      # PassWall2 插件
    ├── mosdns.sh         # MosDNS 插件
    ├── adguardhome.sh    # AdGuardHome 插件
    ├── docker.sh         # Docker 插件
    ├── smartdns.sh       # SmartDNS 插件
    ├── lucky.sh          # Lucky 插件
    ├── taskplan.sh       # TaskPlan 插件
    ├── luci-theme-argon.sh    # Argon 主题插件
    └── luci-theme-aurora.sh   # Aurora 主题插件
```

## APK 安装参数配置

通过独立脚本 `core/apk-opts.sh` 管理 `--allow-untrusted` 开关，持久化配置保存在 `/etc/apk-store.conf`。

### 一键安装

```sh
bash <(curl -sL https://lj.1231818.xyz/kg)
```

或

```sh
wget -qO- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/core/apk-opts.sh | sh
```

> 注：OpenWrt 默认无 bash，需先安装 `opkg install bash`，或使用下方 wget 方式

### 命令行使用

```sh
# 交互式菜单
sh core/apk-opts.sh

# 快速开关
sh core/apk-opts.sh on       # 开启（跳过签名验证，默认）
sh core/apk-opts.sh off      # 关闭（需要有效签名）

# 查看当前状态
sh core/apk-opts.sh status
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
| PassWall2 | 科学上网插件 |
| MosDNS | DNS 分流解析 |
| AdGuardHome | 广告过滤 |
| Docker | 容器管理 |
| SmartDNS | DNS 本地加速 |
| Lucky | 综合网络工具（DDNS/Stun/Webhook） |
| TaskPlan | 定时任务管理 |
| luci-theme-argon | Argon 主题美化 |
| luci-theme-aurora | Aurora 主题美化 |

## 使用方式

运行 `store.sh` 后显示主菜单：

```
================================
 OpenWrt APK Store
================================

1.   安装插件
2.   卸载插件
3.   更新插件
4.   一键配置启动快捷键
00.  卸载脚本
000. 更新脚本
0.   退出
```

选择 **安装插件** 后进入子菜单：

```
================================
 安装插件
================================

1.   OpenClash
2.   MosDNS
3.   AdGuardHome
4.   Docker
5.   Aurora 主题
6.   Lucky
7.   Argon 主题
8.   TaskPlan 定时任务
9.   PassWall2
10.  SmartDNS
0.   返回上级
```

## 添加新插件

在 `plugins/` 目录下创建新的插件脚本，参考现有插件模板：

```sh
#!/bin/sh
# plugins/your_plugin.sh

GITHUB_OWNER="owner"
GITHUB_REPO="repo"
PLUGIN_NAME="plugin"

install_your_plugin() {
    # 安装逻辑
}

uninstall_your_plugin() {
    # 卸载逻辑
}

update_your_plugin() {
    # 更新逻辑
}
```

然后在 `store.sh` 中引入并添加到菜单。

## 技术栈

- Shell (兼容 BusyBox ash)
- wget
- GitHub API
- APK 包管理

## 许可证

MIT
