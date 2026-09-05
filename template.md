# Lniri Liquid Glass - Complete Setup Template & Configuration Guide

This template contains everything you need to achieve the liquid-glass refraction effect in **Lniri** as showcased in the screenshots. It includes complete configuration files for your compositor, terminals, and wallpaper daemons, plus curated aesthetic presets and troubleshooting advice.

---

## 📋 Table of Contents

1. [How the Liquid Glass Effect Works](#1-how-the-liquid-glass-effect-works)
2. [Lniri Compositor Configuration (`config.kdl`)](#2-lniri-compositor-configuration-configkdl)
3. [Terminal Configurations](#3-terminal-configurations)
   - [Kitty (`kitty.conf`)](#kitty-configkittykittyconf)
   - [Alacritty (`alacritty.toml`)](#alacritty-configalacrittyalacrittytoml)
   - [Ghostty (`config`)](#ghostty-configghosttyconfig)
   - [Foot (`foot.ini`)](#foot-configfootfootini)
4. [Wallpaper Daemon Configuration (Mandatory)](#4-wallpaper-daemon-configuration-mandatory)
   - [Option A: Hyprpaper](#option-a-hyprpaper-recommended)
   - [Option B: Swaybg](#option-b-swaybg-lightweight)
   - [Option C: SWWW](#option-c-swww-animated)
5. [Curated Glass Presets](#5-curated-glass-presets)
   - [Preset 1: Liquid Prism (README Look)](#preset-1-liquid-prism-readme-look)
   - [Preset 2: Frosted Smoked Glass (High Contrast)](#preset-2-frosted-smoked-glass-high-contrast)
   - [Preset 3: Cyberpunk Neon Rim](#preset-3-cyberpunk-neon-rim)
   - [Preset 4: Subtle Crystal](#preset-4-subtle-crystal)
6. [Glass Shader Parameters Reference](#6-glass-shader-parameters-reference)
7. [Step-by-Step Setup Guide](#7-step-by-step-setup-guide)
8. [Troubleshooting & FAQ](#8-troubleshooting--faq)

---

## 1. How the Liquid Glass Effect Works

Lniri implements real-time GLSL fragment shaders (`clipped_surface.frag`) to refract background elements. Understanding this architecture prevents the most common setup mistakes:

```
┌────────────────────────────────────────────────────────┐
│  Desktop Wallpaper Layer (Wayland Layer::Background)   │  ◄── Must be active! (hyprpaper / swaybg)
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│   Lniri Liquid Glass Shader Engine                     │  ◄── Samples wallpaper via `xray true`
│   (Refraction, Curvature SDF, Glow, Fringing)          │      Calculates rounded edges from corner radius
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│   Transparent Terminal Window                          │  ◄── Terminal opacity must be between 0.4 - 0.7
│   (Kitty / Alacritty / Ghostty with alpha background)  │      Internal app blurs must be disabled
└────────────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> **A wallpaper daemon is mandatory!** In Wayland, if no wallpaper tool is running, the desktop layer is pitch black (`#000000`). Bending pure black pixels results in pure black ($0 \times \text{anything} = 0$), hiding all liquid glass reflections and edge highlights.

---

## 2. Lniri Compositor Configuration (`config.kdl`)

Lniri searches for its config at:
1. `~/.config/lniri/config.kdl`
2. `~/.config/niri/config.kdl`

Add the following rules to your `config.kdl`:

```kdl
// ============================================================================
// 1. GLOBAL WINDOW CORNER RADIUS (Crucial for curved glass refraction)
// ============================================================================
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}

// ============================================================================
// 2. LIQUID GLASS WINDOW RULES
// ============================================================================

// Kitty Terminal
window-rule {
    match app-id="kitty"
    draw-border-with-background false
    background-effect {
        blur true
        xray true
        liquid-glass {
            refraction-strength 4.0
            power-factor 3.0
            refraction-power 1.5
            glow-weight 0.12
            edge-lighting 0.8
            saturation 1.1
            vibrancy 0.35
            adaptive-dim 0.15
            adaptive-boost 0.25
            physical-refraction 0.0
            lens-distortion 0.2
            fringing 0.5
        }
    }
}

// Alacritty Terminal
window-rule {
    match app-id="Alacritty"
    draw-border-with-background false
    background-effect {
        blur true
        xray true
        liquid-glass {
            refraction-strength 4.0
            power-factor 3.0
            refraction-power 1.5
            glow-weight 0.12
            edge-lighting 0.8
            saturation 1.1
            vibrancy 0.35
            adaptive-dim 0.15
            adaptive-boost 0.25
            physical-refraction 0.0
            lens-distortion 0.2
            fringing 0.5
        }
    }
}

// Ghostty Terminal
window-rule {
    match app-id="com.mitchellh.ghostty"
    draw-border-with-background false
    background-effect {
        blur true
        xray true
        liquid-glass {
            refraction-strength 4.0
            power-factor 3.0
            refraction-power 1.5
            glow-weight 0.12
            edge-lighting 0.8
            saturation 1.1
            vibrancy 0.35
            adaptive-dim 0.15
            adaptive-boost 0.25
            physical-refraction 0.0
            lens-distortion 0.2
            fringing 0.5
        }
    }
}

// Universal Rule (Applies liquid glass to any transparent window)
// window-rule {
//     match app-id=".*"
//     draw-border-with-background false
//     background-effect {
//         blur true
//         xray true
//         liquid-glass {
//             refraction-strength 3.5
//             power-factor 4.0
//             refraction-power 1.2
//             glow-weight 0.08
//             edge-lighting 0.6
//             saturation 1.05
//             vibrancy 0.3
//             adaptive-dim 0.15
//             adaptive-boost 0.2
//             fringing 0.4
//         }
//     }
// }

// ============================================================================
// 3. KEYBINDINGS (Open Kitty)
// ============================================================================
binds {
    Mod+Return hotkey-overlay-title="Open Terminal (Kitty)" { spawn "kitty"; }
    Mod+T hotkey-overlay-title="Open Terminal (Kitty)" { spawn "kitty"; }
}

// ============================================================================
// 4. AUTOSTART WALLPAPER DAEMON
// ============================================================================
spawn-at-startup "hyprpaper"
// Or if you use swaybg:
// spawn-at-startup "swaybg" "-i" "/path/to/wallpaper.png" "-m" "fill"
```

---

## 3. Terminal Configurations

For the glass effect to be visible, your terminal must have transparency enabled and internal blur disabled (so Lniri handles the optical shader rendering).

### Kitty (`~/.config/kitty/kitty.conf`)

```ini
# ============================================================================
# Kitty Liquid Glass Settings
# ============================================================================

# 1. Background Opacity (0.45 - 0.60 recommended for liquid glass)
background_opacity 0.50

# 2. Base Background Color (Darker base improves contrast against bright glass)
background #050505

# 3. Enable Dynamic Opacity Shortcuts (Optional: tweak opacity on the fly)
dynamic_background_opacity yes

# 4. Disable Kitty's Internal Blur (CRITICAL: lets Lniri compositor render refraction)
background_blur 0

# 5. Window Padding (Adds spacing between text and glowing glass borders)
window_padding_width 12

# 6. Text dimming
dim_opacity 0.1
```

> [!TIP]
> In Kitty, with `dynamic_background_opacity yes`, you can dynamically adjust opacity using `Ctrl+Shift+A > m` (more transparent) and `Ctrl+Shift+A > l` (less transparent).

---

### Alacritty (`~/.config/alacritty/alacritty.toml`)

```toml
[window]
# Background Opacity (0.0 = completely invisible, 1.0 = opaque)
opacity = 0.50
blur = true
dynamic_padding = true
padding = { x = 12, y = 12 }

[colors.primary]
background = "#050505"
foreground = "#D8DEE9"
```

---

### Ghostty (`~/.config/ghostty/config`)

```ini
background-opacity = 0.50
background-blur-radius = 0
window-padding-x = 12
window-padding-y = 12
background = #050505
```

---

### Foot (`~/.config/foot/foot.ini`)

```ini
[main]
pad=12x12

[colors]
alpha=0.50
background=050505
```

---

## 4. Wallpaper Daemon Configuration (Mandatory)

Liquid glass requires an active background image in Wayland's `Layer::Background`.

### Option A: Hyprpaper (Recommended)

1. Create or edit `~/.config/hypr/hyprpaper.conf`:
   ```ini
   # Preload the image into memory
   preload = /home/USERNAME/Pictures/Wallpapers/wallpaper.png

   # Assign wallpaper to all monitors
   wallpaper {
       monitor = 
       path = /home/USERNAME/Pictures/Wallpapers/wallpaper.png
       fit_mode = cover
   }

   # Disable splash text
   splash = false
   ```
   *(Replace `/home/USERNAME/Pictures/Wallpapers/wallpaper.png` with your actual image path).*

2. Test manually:
   ```bash
   killall hyprpaper 2>/dev/null; hyprpaper &
   ```

3. Autostart in `config.kdl`:
   ```kdl
   spawn-at-startup "hyprpaper"
   ```

---

### Option B: Swaybg (Lightweight & Simple)

If you prefer `swaybg` (no config file needed):
```bash
sudo pacman -S --needed swaybg    # Arch / CachyOS
# or: sudo apt install swaybg      # Debian / Ubuntu
# or: sudo dnf install swaybg      # Fedora
```

Autostart directly in `~/.config/lniri/config.kdl`:
```kdl
spawn-at-startup "swaybg" "-i" "/home/USERNAME/Pictures/Wallpapers/wallpaper.png" "-m" "fill"
```

---

### Option C: SWWW (Animated Transitions)

Install `swww` and add to `config.kdl`:
```kdl
spawn-at-startup "swww-daemon"
```
Change wallpapers on the fly with animated transitions:
```bash
swww img /path/to/wallpaper.png --transition-type wipe --transition-duration 2
```

---

## 5. Curated Glass Presets

Swap the `liquid-glass { ... }` block in your `config.kdl` to match your personal aesthetic preference:

### Preset 1: Liquid Prism (README Look)
*Maximum chromatic aberration, vivid edge-lighting, and dramatic optical curvature.*

```kdl
liquid-glass {
    refraction-strength 4.0
    power-factor 3.0
    refraction-power 1.5
    glow-weight 0.12
    edge-lighting 0.8
    saturation 1.1
    vibrancy 0.35
    adaptive-dim 0.15
    adaptive-boost 0.25
    physical-refraction 0.0
    lens-distortion 0.2
    fringing 0.5
}
```

---

### Preset 2: Frosted Smoked Glass (High Contrast)
*Subtle optical refraction, reduced fringing, and optimized text legibility for coding.*

```kdl
liquid-glass {
    refraction-strength 2.5
    power-factor 8.0
    refraction-power 1.0
    glow-weight 0.001
    edge-lighting 0.25
    saturation 0.95
    vibrancy 0.15
    adaptive-dim 0.30
    adaptive-boost 0.20
    physical-refraction 0.0
    lens-distortion 0.0
    fringing 0.1
}
```

---

### Preset 3: Cyberpunk Neon Rim
*Intense chromatic dispersion (rainbow prism border) and high vibrancy.*

```kdl
liquid-glass {
    refraction-strength 5.0
    power-factor 2.5
    refraction-power 1.8
    glow-weight 0.18
    edge-lighting 1.0
    saturation 1.25
    vibrancy 0.45
    adaptive-dim 0.10
    adaptive-boost 0.35
    physical-refraction 0.0
    lens-distortion 0.25
    fringing 0.75
}
```

---

### Preset 4: Subtle Crystal
*Ultra-clean, crisp, minimal distortion.*

```kdl
liquid-glass {
    refraction-strength 1.8
    power-factor 12.0
    refraction-power 0.8
    glow-weight 0.0001
    edge-lighting 0.2
    saturation 1.0
    vibrancy 0.1
    adaptive-dim 0.2
    adaptive-boost 0.15
    physical-refraction 0.0
    lens-distortion 0.0
    fringing 0.0
}
```

---

## 6. Glass Shader Parameters Reference

| Parameter | Type | Typical Range | Description |
| :--- | :--- | :--- | :--- |
| `refraction-strength` | float | `1.0` – `6.0` | Overall magnitude of the background optical refraction. |
| `power-factor` | float | `2.0` – `15.0` | Falloff curve from the window edge inward (lower = wider glass bevel, higher = concentrated at rim). |
| `refraction-power` | float | `0.5` – `2.0` | Exponential power applied to the displacement vector. |
| `fringing` | float | `0.0` – `1.0` | Chromatic dispersion (splits red/green/blue wavelengths along refractive curves). |
| `edge-lighting` | float | `0.0` – `1.0` | Dynamically samples and blends the background wallpaper colors onto window borders. |
| `glow-weight` | float | `0.0` – `0.3` | Soft illuminated halo intensity along the perimeter. |
| `saturation` | float | `0.5` – `1.5` | Color saturation multiplier of the refracted background. |
| `vibrancy` | float | `0.0` – `0.5` | Color pop and luminance boosting for the glass substrate. |
| `adaptive-dim` | float | `0.0` – `0.5` | Automatically darkens glass over very bright wallpapers to keep dark text readable. |
| `adaptive-boost` | float | `0.0` – `0.5` | Automatically boosts luminance over dark wallpapers. |
| `physical-refraction` | float | `0.0` or `1.0` | `0.0` = SDF normal mode (pushes outward); `1.0` = center-directed Snell mode. |
| `lens-distortion` | float | `0.0` – `0.5` | Subtle fish-eye barrel distortion across the window surface. |

---

## 7. Step-by-Step Setup Guide

### Step 1: Install or Update Lniri
Run the official one-liner:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AbsolOrg/Lniri/main/install.sh)"
```

### Step 2: Configure Wallpaper
Set up `~/.config/hypr/hyprpaper.conf` with a colorful, high-contrast wallpaper (scenery, anime, or abstract art works best) and launch it:
```bash
hyprpaper &
```

### Step 3: Copy Window Rules to `config.kdl`
Paste the `window-rule` and `geometry-corner-radius` sections from [Section 2](#2-lniri-compositor-configuration-configkdl) into `~/.config/lniri/config.kdl` (or `~/.config/niri/config.kdl`).

### Step 4: Configure Your Terminal
Set transparency to `0.50` and disable internal blur in `~/.config/kitty/kitty.conf` or `~/.config/alacritty/alacritty.toml`.

### Step 5: Reload Lniri Live
Apply all changes immediately without restarting your session:
```bash
lniri msg action load-config-file
```

### Step 6: Launch Terminal
Press **`Mod+T`** or **`Mod+Return`** (or run `kitty &`) to see your liquid glass terminal!

---

## 8. Troubleshooting & FAQ

### Q: Why is my terminal background completely black?
**Cause**: No wallpaper daemon is running in `Layer::Background`.
**Solution**:
1. Check if a wallpaper daemon is running: `pgrep -l "hyprpaper|swaybg|swww"`.
2. Start one: `hyprpaper &` or `swaybg -i /path/to/image.png -m fill &`.
3. Add `spawn-at-startup "hyprpaper"` to your `config.kdl`.

### Q: Why are my window corners sharp rectangles instead of rounded glass?
**Cause**: `geometry-corner-radius` is commented out or disabled.
**Solution**: Ensure your `config.kdl` includes:
```kdl
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}
```

### Q: The glass effect works, but text is difficult to read.
**Solution**:
- Increase `adaptive-dim` to `0.25` or `0.30` in `config.kdl`.
- Increase terminal background opacity slightly (e.g. from `0.50` to `0.65` in `kitty.conf`).
- Use bold fonts or a dark base color (`background #050505`).

### Q: Mod+T opens Alacritty instead of Kitty.
**Solution**: Change the spawn command in `config.kdl`:
```kdl
Mod+T hotkey-overlay-title="Open Terminal" { spawn "kitty"; }
```
Then run `lniri msg action load-config-file`.
