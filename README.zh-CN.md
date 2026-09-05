# Lniri — Wayland 流体玻璃窗口管理器

**[English](README.md)** | **[中文](README.zh-CN.md)**

一个集成 **流体玻璃折射 (Liquid Glass)** 与背景特效引擎的平铺 Wayland 合成器（基于 Niri）。

<p align="center">
  <img width="1920" height="1080" alt="Lniri Liquid Glass Preview" src="https://github.com/user-attachments/assets/a10b40c7-b147-4dfa-8208-28ebb4003cfc" />
</p>

---

## ⚡ 快速安装：一键命令

使用单行命令直接安装或更新 Lniri。安装脚本会自动请求一次 `sudo` 密码并在后台保持凭据活跃，自动安装所需系统依赖，并在本地维护持久化的 `target/` 缓存目录（以便日后极速更新），同时自动注册 Wayland 会话：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AbsolOrg/Lniri/main/install.sh)"
```

> **该安装脚本的优势：**
> - **自动识别已安装版本**：若检测到系统已安装 Lniri，脚本将自动切换至**更新模式**并提供通道选择：
>   - **主分支 (Main branch)**：获取最新特性与实时代码。
>   - **最新发布版 (Latest release)**：锁定稳定发布的 Tag 版本。
> - **后续更新秒级完成**：在 `~/.local/share/lniri/target` 中保留编译缓存，无需重复从零编译几百个依赖。
> - **免重复输入密码**：只需在开始时输入一次 `sudo` 密码，后台自动保持心跳，无需人工干预直至安装完成。
> - **独立自包含**：自动安装 `lniri`、`Lniri`、`lniri-session` 以及 systemd 用户服务与 Wayland 桌面会话项，无需预先安装上游 niri。

---

## 🚀 如何启动

1. **从显示管理器登录 (GDM, SDDM, Ly, Greetd 等)：**
   在登录会话列表中选择 **Lniri (Liquid Glass)**。

2. **从 TTY 终端启动：**
   ```bash
   exec lniri-session
   ```

3. **直接运行可执行文件：**
   ```bash
   lniri
   # 或
   Lniri
   ```

---

## ⚙️ 配置文件

Lniri 按以下优先级查找配置文件：
1. `~/.config/lniri/config.kdl`
2. `~/.config/niri/config.kdl`（无缝兼容现有 niri 配置）
3. 环境变量 `$LNIRI_CONFIG` 或 `$NIRI_CONFIG`

### 流体玻璃效果示例

在 `config.kdl` 中加入以下内容：

```kdl
window-rule {
    match app-id=".*"
    background-effect {
        blur true
        xray true
        liquid-glass {
            refraction-strength 3.0
            power-factor 10.0
            refraction-power 1.0
            glow-weight 0.0001
            edge-lighting 0.2
            saturation 0.9
            vibrancy 0.2
            adaptive-dim 0.2
            adaptive-boost 0.2
            physical-refraction 0.0
            lens-distortion 0.0
            fringing 0.0
        }
    }
}
```

---

## 🛠️ 从源码手动构建与安装

```bash
git clone https://github.com/AbsolOrg/Lniri.git
cd Lniri
./install.sh
```

仓库内生成的 `target/` 文件夹会自动缓存编译产物，下次编译仅需耗时数秒。

---

## 🗑️ 卸载

运行以下命令即可完整移除 Lniri：

```bash
./uninstall.sh
```
