# Lniri - Liquid Glass Engine for Niri

A liquid-glass optical refraction and background effect engine for the [Niri](https://github.com/niri-wm/niri) scrollable-tiling Wayland compositor.

---

## Quick Start: One-Liner Install & Update

Install Lniri or update an existing installation directly with a single command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AbsolOrg/Lniri/main/install.sh)"
```

### Why this installer is smart:
- **Side-by-Side Installation**: Installs as a separate `Lniri (Liquid Glass)` session alongside your standard `niri`. Both can be chosen at your login manager (GDM, SDDM, Ly, Greetd).
- **Auto-Detects Existing Installations**: Automatically switches into **Update Mode** and lets you choose between:
  - **1) Main branch**: Cutting-edge upstream commits.
  - **2) Latest release**: Stable tagged releases of Niri.
- **Persistent Build Cache**: Maintains the Niri source and build cache in `~/.local/share/lniri/niri/target`. Subsequent runs and updates compile incrementally in seconds without recompiling all dependencies from scratch.
- **Hands-Free**: Prompts for `sudo` once at the beginning and keeps the session active in the background until installation finishes.

---

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

## Gallery & Effects

### Dynamic Glass & Wallpaper Reflections


### Video Demo (Live Wallpaper + Shadows)

---

## Configuration & Terminal Setup

> **Looking for complete terminal configs (Alacritty, Kitty, Ghostty), wallpaper daemon setups, and ready-to-use presets?**  
> Check out the [**Complete Setup Template & Guide (template.md)**](template.md).

Lniri reads standard Niri configuration files in the following order:
1. `~/.config/lniri/config.kdl`
2. `~/.config/niri/config.kdl` (seamless fallback for existing configs)
3. Custom path via `$LNIRI_CONFIG` or `$NIRI_CONFIG`

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
        blur true
        xray true
        liquid-glass {
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

## Parameters Breakdown

| Parameter | Type | Typical Range | Description |
| :--- | :--- | :--- | :--- |
| `refraction-strength` | float | `1.0` – `6.0` | Overall magnitude of the optical refraction. |
| `power-factor` | float | `2.0` – `15.0` | Falloff curve from the window edge inward (lower = wider glass bevel). |
| `refraction-power` | float | `0.5` – `2.0` | Exponential power applied to displacement vectors. |
| `fringing` | float | `0.0` – `1.0` | Chromatic dispersion (RGB prism fringing along edges). |
| `edge-lighting` | float | `0.0` – `1.0` | Blends wallpaper colors dynamically onto window borders. |
| `glow-weight` | float | `0.0` – `0.2` | Synthetic white highlight along the rim (`0.0` for pure optical glass). |
| `saturation` | float | `0.5` – `1.5` | Color saturation multiplier of the refracted background. |
| `vibrancy` | float | `0.0` – `0.5` | Luminance and vibrancy boost for glass substrates. |
| `adaptive-dim` | float | `0.0` – `0.5` | Darkens glass over very bright wallpapers for readability (`0.0` for pure clear glass). |
| `adaptive-boost` | float | `0.0` – `0.5` | Lightens glass over very dark wallpapers. |
| `physical-refraction` | float | `0.0` or `1.0` | `0.0` = SDF normal mode; `1.0` = center-directed Snell mode. |
| `lens-distortion` | float | `0.0` – `0.5` | Subtle barrel lens distortion across the window surface. |

---

## Manual Installation (from Git)

```bash
git clone https://github.com/AbsolOrg/Lniri.git
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

- Liquid glass shader effects inspired by [kwin-effects-glass](https://github.com/4v3ngR/kwin-effects-glass) and based on [Niri-glass](https://github.com/zaroutt/Niri-glass).
