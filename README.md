# Lniri - Liquid Glass Engine for Niri

- A liquid-glass optical refraction and background effect engine for the [Niri](https://github.com/niri-wm/niri) scrollable-tiling Wayland compositor.
     
https://github.com/user-attachments/assets/b98440ec-ffa4-47c4-9473-23d51ceb8d4d

https://github.com/user-attachments/assets/4df0c81e-beb1-4ede-903e-5af182120164

## Quick Start: One-Liner Install & Update

Install Lniri or update an existing installation directly with a single command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TattvaOrg/Lniri/main/install.sh)"
```

### Why this installer is smart:
- **Side-by-Side Installation**: Installs as a separate `Lniri (Liquid Glass)` session alongside your standard `niri`. Both can be chosen at your login manager (GDM, SDDM, Ly, Greetd).
- **Auto-Detects Existing Installations**: Automatically switches into **Update Mode** and lets you choose between:
  - **1) Main branch**: Cutting-edge upstream commits.
  - **2) Latest release**: Stable tagged releases of Niri.
- **Persistent Build Cache**: Maintains the Niri source and build cache in `~/.local/share/lniri/niri/target`. Subsequent runs and updates compile incrementally in seconds without recompiling all dependencies from scratch.
- **Dependency & Library Compatibility Guard**: Preflight checks verify essential graphics libraries, ensuring `libdisplay-info >= 0.3.0` (SONAME `libdisplay-info.so.3`) is present. Warns clearly if outdated versions (e.g. Fedora 41-43 shipping 0.2.0) are found to prevent login black screens, and offers automated compilation with `--build-libdisplay-info`.
- **Diagnostic Mode (`--check`)**: Run `./install.sh --check` anytime to verify all compositor and display dependencies without installing.
- **Hands-Free**: Prompts for `sudo` once at the beginning and keeps the session active in the background until installation finishes.

---

```mermaid
flowchart TD

subgraph group_session["Session &amp; distribution"]
  node_installer["Installer<br/>[install.sh]"]
  node_uninstaller["Uninstaller<br/>shell removal<br/>[uninstall.sh]"]
  node_desktop_entry["Desktop entry<br/>display-manager entry<br/>[lniri.desktop]"]
  node_session_launcher["Session launcher<br/>session script"]
  node_user_service["Lniri user service<br/>systemd user unit<br/>[lniri.service]"]
  node_portal_config["Portal configuration<br/>Wayland portal config<br/>[lniri-portals.conf]"]
end

subgraph group_compositor["Compositor integration"]
  node_mapped_layers["Mapped layer lifecycle<br/>compositor render bridge<br/>[mapped.rs]"]
  node_render_helpers["Render helper API<br/>render integration module<br/>[mod.rs]"]
end

subgraph group_effects["Effect rendering"]
  node_background_effect["Background effect pass<br/>background capture pass"]
  node_framebuffer_effect["Framebuffer composition<br/>framebuffer pass"]
  node_xray["Xray sampling<br/>background sampling helper<br/>[xray.rs]"]
  node_liquid_glass["Liquid-glass optics<br/>effect parameter interface<br/>[liquid_glass.rs]"]
  node_shader_bindings["Shader bindings<br/>Rust GLSL boundary<br/>[mod.rs]"]
  node_clipped_shader["Clipped surface shader<br/>GLSL fragment shader"]
  node_kwin_shader["KWin glass reference<br/>reference GLSL shader<br/>[kwin-glass.frag]"]
end

subgraph group_config["Configuration &amp; Nix"]
  node_appearance_config["Appearance model<br/>config parsing<br/>[appearance.rs]"]
  node_example_config["Example KDL config<br/>window-rule config<br/>[config.kdl]"]
  node_nix_flake["Nix package entry<br/>Nix flake<br/>[flake.nix]"]
  node_nixos_module["NixOS module<br/>NixOS deployment module<br/>[nixos-module.nix]"]
  node_home_manager_module["Home Manager module<br/>Home Manager deployment module"]
end

node_installer -->|"installs"| node_session_launcher
node_installer -->|"installs"| node_desktop_entry
node_installer -->|"installs"| node_user_service
node_uninstaller -.->|"removes installed artifacts"| node_installer
node_desktop_entry -->|"launches"| node_session_launcher
node_session_launcher -->|"starts compositor session"| node_mapped_layers
node_user_service -->|"runs"| node_mapped_layers
node_portal_config -.->|"configures portal environment"| node_session_launcher
node_mapped_layers -->|"invokes"| node_render_helpers
node_render_helpers -->|"coordinates"| node_background_effect
node_background_effect -->|"samples background through"| node_xray
node_background_effect -->|"renders within"| node_framebuffer_effect
node_framebuffer_effect -->|"composites effect"| node_liquid_glass
node_liquid_glass -->|"passes GPU parameters"| node_shader_bindings
node_shader_bindings -->|"loads"| node_clipped_shader
node_example_config -->|"provides window rules"| node_appearance_config
node_appearance_config -->|"supplies optics settings"| node_liquid_glass
node_nix_flake -->|"exposes"| node_nixos_module
node_nix_flake -->|"exposes"| node_home_manager_module
node_nixos_module -->|"deploys session"| node_session_launcher
node_home_manager_module -->|"deploys session"| node_session_launcher
node_kwin_shader -.->|"documents alternate model"| node_liquid_glass

click node_installer "https://github.com/tattvaorg/lniri/blob/main/install.sh"
click node_uninstaller "https://github.com/tattvaorg/lniri/blob/main/uninstall.sh"
click node_desktop_entry "https://github.com/tattvaorg/lniri/blob/main/resources/lniri.desktop"
click node_session_launcher "https://github.com/tattvaorg/lniri/blob/main/resources/lniri-session"
click node_user_service "https://github.com/tattvaorg/lniri/blob/main/resources/lniri.service"
click node_portal_config "https://github.com/tattvaorg/lniri/blob/main/resources/lniri-portals.conf"
click node_mapped_layers "https://github.com/tattvaorg/lniri/blob/main/src/layer/mapped.rs"
click node_render_helpers "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/mod.rs"
click node_background_effect "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/background_effect.rs"
click node_framebuffer_effect "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/framebuffer_effect.rs"
click node_xray "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/xray.rs"
click node_liquid_glass "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/liquid_glass.rs"
click node_shader_bindings "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/shaders/mod.rs"
click node_clipped_shader "https://github.com/tattvaorg/lniri/blob/main/src/render_helpers/shaders/clipped_surface.frag"
click node_appearance_config "https://github.com/tattvaorg/lniri/blob/main/niri-config/src/appearance.rs"
click node_example_config "https://github.com/tattvaorg/lniri/blob/main/config.kdl"
click node_nix_flake "https://github.com/tattvaorg/lniri/blob/main/flake.nix"
click node_nixos_module "https://github.com/tattvaorg/lniri/blob/main/nix/nixos-module.nix"
click node_home_manager_module "https://github.com/tattvaorg/lniri/blob/main/nix/home-manager-module.nix"
click node_kwin_shader "https://github.com/tattvaorg/lniri/blob/main/resources/shaders/kwin-glass.frag"

classDef toneNeutral fill:#f8fafc,stroke:#334155,stroke-width:1.5px,color:#0f172a
classDef toneBlue fill:#dbeafe,stroke:#2563eb,stroke-width:1.5px,color:#172554
classDef toneAmber fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f
classDef toneMint fill:#dcfce7,stroke:#16a34a,stroke-width:1.5px,color:#14532d
classDef toneRose fill:#ffe4e6,stroke:#e11d48,stroke-width:1.5px,color:#881337
classDef toneIndigo fill:#e0e7ff,stroke:#4f46e5,stroke-width:1.5px,color:#312e81
classDef toneTeal fill:#ccfbf1,stroke:#0f766e,stroke-width:1.5px,color:#134e4a
class node_installer,node_uninstaller,node_desktop_entry,node_session_launcher,node_user_service,node_portal_config toneBlue
class node_mapped_layers,node_render_helpers toneAmber
class node_background_effect,node_framebuffer_effect,node_xray,node_liquid_glass,node_shader_bindings,node_clipped_shader,node_kwin_shader toneMint
class node_appearance_config,node_example_config,node_nix_flake,node_nixos_module,node_home_manager_module toneRose
```

## How to Launch

1. **From your Display Manager (GDM, SDDM, Ly, Greetd):**  
   Select **Lniri (Liquid Glass)** from the session dropdown.

2. **From a TTY:**
   ```bash
   exec /usr/local/bin/lniri-session
   ```

3. **Standalone binary:**
   ```bash
   lniri
   # or
   Lniri
   ```
   
---

## Configuration & Terminal Setup

> **Looking for complete terminal configs (Alacritty, Kitty, Ghostty), wallpaper daemon setups, and ready-to-use presets?**  
> Check out the [**Complete Setup Template & Guide (template.md)**](template.md).  
> **Looking for detailed shader optics, KWin Glass presets, and parameters?**  
> See the [**Shader Guide & Reference (shaders.md)**](shaders.md).

Lniri reads standard Niri configuration files in the following order:
1. `~/.config/lniri/config.kdl`
2. `~/.config/niri/config.kdl` (seamless fallback for existing configs)
3. Custom path via `$LNIRI_CONFIG` or `$NIRI_CONFIG`

>[!IMPORTANT]
> After installing it, your niri will show an error because you are editing a niri/config.kdl, so make sure that to use your niri again, remove all Lniri config from config.kdl. By only this, your main niri will work again, and to validate it, use lniri validate

### Basic Liquid Glass Window Rule

Add the following to your `config.kdl`:

```kdl
// Enable rounded corners (crucial for curved glass refraction)
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}

// Liquid glass rule for your terminal (Alacritty / Kitty)
window-rule {
    match app-id="Alacritty"
    draw-border-with-background false
    background-effect {
        blur false
        xray true
        liquid-glass {
            liquidity 0.8
            refraction-strength 4.0
            power-factor 3.5
            refraction-power 1.5
            glow-weight 0.0
            edge-lighting 0.5
            saturation 1.1
            vibrancy 0.35
            adaptive-dim 0.0
            adaptive-boost 0.0
            physical-refraction 0.0
            lens-distortion 0.2
            fringing 0.4
        }
    }
}
```

---

## [Ideas](https://github.com/TattvaOrg/Lniri/tree/main/ideas)
<table>
  <tr>
    <td>
<img width="1044" height="664" alt="dolphin" src="https://github.com/user-attachments/assets/59d51b3d-fd18-4695-9798-d184d5d7405c" />
    </td>
    <td>
<img width="1044" height="664" alt="bubble" src="https://github.com/user-attachments/assets/9a94692c-7ff8-4831-826a-422703aa8d16" />
    </td>
  </tr>
</table>

---

## Parameters Breakdown

| Parameter | Type | Typical Range | Description |
| :--- | :--- | :--- | :--- |
| `mode` | string | `"kwin-glass"` or `"liquid"` | Shader engine toggle. `"kwin-glass"` runs the authentic Snell's law + caustic bevel + Oklab pipeline; `"liquid"` runs the fluid water-drop pipeline. Defaults to `"liquid"`. |
| `liquidity` | float | `0.0` – `2.0+` | (`mode "liquid"`) Controls fluid water-drop optics intensity. `0.0` = standard glass, `1.0` = deep liquid water-drop reflection with surface-tension curvature and central magnification (matching kwin-effects-glass rose terminal), `2.0+` = extreme fluid distortion. |
| `refraction-strength` | float | `1.0` – `6.0` | Overall magnitude of the optical refraction ($IOR = 1.0 + \text{strength}$). |
| `power-factor` | float | `2.0` – `15.0` | Falloff curve from the window edge inward (lower = wider glass bevel). |
| `refraction-bevel-intensity` | float | `1.0` – `20.0` | (`mode "kwin-glass"`) Caustic bevel steepness & displacement depth. Default `10.0`. |
| `refraction-offset-strength` | float | `1.0` – `20.0` | (`mode "kwin-glass"`) Corner optical curvature distortion. Default `8.0`. |
| `edge-thickness` | float | `0.05` – `0.35` | Meniscus / bevel border width relative to window dimensions. Default `0.18`. |
| `oklab-saturation` | float | `0.0` or `1.0` | (`mode "kwin-glass"`) Set `1.0` to enable Oklab perceptual color space saturation. |
| `refraction-power` | float | `0.5` – `2.0` | (`mode "liquid"`) Exponential power applied to displacement vectors. |
| `fringing` | float | `0.0` – `1.0` | Chromatic dispersion (RGB prism fringing along edges). |
| `edge-lighting` | float | `0.0` – `1.0` | Blends wallpaper colors dynamically onto window borders. |
| `glow-weight` | float | `0.0` – `0.6` | Dual-highlight and shadow rim profile intensity along the glass boundary. |
| `saturation` | float | `0.5` – `1.5` | Color saturation multiplier of the refracted background. |
| `vibrancy` | float | `0.0` – `0.5` | Luminance and vibrancy boost for glass substrates. |
| `adaptive-dim` | float | `0.0` – `0.5` | Darkens glass over very bright wallpapers for readability (`0.0` for pure clear glass). |
| `adaptive-boost` | float | `0.0` – `0.5` | Lightens glass over very dark wallpapers. |
| `physical-refraction` | float | `0.0` or `1.0` | (`mode "liquid"`) `0.0` = SDF normal mode; `1.0` = center-directed Snell mode. |
| `lens-distortion` | float | `0.0` – `0.5` | Subtle barrel lens distortion across the window surface. |

> [!TIP]
> Standalone GLSL shader available at [`resources/shaders/kwin-glass.frag`](file:///home/cachy/github-p/github-based/glass/Lniri/resources/shaders/kwin-glass.frag).

---

## Manual Installation (from Git)

```bash
git clone https://github.com/TattvaOrg/Lniri.git
cd Lniri
./install.sh
```

---

## Uninstallation

To cleanly remove Lniri and its Wayland session files while leaving standard Niri intact:

```bash
./uninstall.sh
```

---

## Credits & License

- Liquid glass kwin shader effects take from [kwin-effects-glass](https://github.com/4v3ngR/kwin-effects-glass) and project infra is based on [Niri-glass](https://github.com/zaroutt/Niri-glass) rust base and glsl shaders are heavily modified.
