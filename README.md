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
- 插件更新
- 支持管道安装（wget -O- | sh）

## 一键安装

```sh
wget -O- https://raw.githubusercontent.com/chengege666/OpenWrt-APK/main/install.sh | sh
```

## 短链接
```sh
bash <(curl -sL vpsx.1231818.xyz)
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
│   └── ui.sh             # 用户界面模块
└── plugins/
    ├── openclash.sh      # OpenClash 插件
    ├── passwall.sh       # PassWall 插件
    ├── mosdns.sh         # MosDNS 插件
    ├── adguardhome.sh    # AdGuardHome 插件
    ├── docker.sh         # Docker 插件
    ├── ddns.sh           # DDNS 插件
    └── tailscale.sh      # Tailscale 插件
```

## 支持的插件

| 插件 | 说明 |
|------|------|
| OpenClash | 透明代理工具 |
| PassWall | 科学上网插件 |
| MosDNS | DNS 分流解析 |
| AdGuardHome | 广告过滤 |
| Docker | 容器管理 |
| DDNS | 动态域名解析 |
| Tailscale | 虚拟组网 |

## 使用方式

运行 `store.sh` 后显示主菜单：

```
================================
 OpenWrt APK Store
================================

1. OpenClash
2. PassWall
3. MosDNS
4. AdGuardHome
5. Docker
6. DDNS
7. Tailscale
8. 卸载插件
9. 更新插件
0. 退出

请选择:
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
