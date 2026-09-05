# Lniri - Liquid Glass Compositor for Wayland

**[English](README.md)** | **[中文](README.zh-CN.md)**

A scrollable-tiling Wayland compositor featuring an integrated **liquid-glass refraction** and background effect engine.

<p align="center">
  <img width="1920" height="1080" alt="Lniri Liquid Glass Preview" src="https://github.com/user-attachments/assets/a10b40c7-b147-4dfa-8208-28ebb4003cfc" />
</p>

---

## ⚡ Quick Start: One-Liner Install

Install or update Lniri directly with a single command. The installer will prompt for your `sudo` password once upfront, keep the credential alive during compilation, automatically install required dependencies, build Lniri with a persistent cached `target/` directory for fast updates, and register your Wayland session:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AbsolOrg/Lniri/main/install.sh)"
```

> **Why this installer is smart:**
> - **Auto-Detects Existing Installs**: If Lniri is already installed, running this command automatically enters **Update Mode** and lets you choose your update channel:
>   - **Main branch**: Get the cutting-edge latest commits.
>   - **Latest release**: Stay on stable tagged releases.
> - **Zero-recompile on updates**: Maintains a persistent build cache in `~/.local/share/lniri/target`, so future runs and updates take seconds instead of compiling from scratch.
> - **Hands-free**: Asks for `sudo` once at the beginning and keeps the session active in the background until installation finishes.
> - **Self-contained**: Installs standalone binaries (`lniri`, `Lniri`, and `lniri-session`), systemd user units, and the Wayland session entry without requiring upstream `niri` to be installed first.

---

## 🚀 How to Launch

1. **From your Display Manager (GDM, SDDM, Ly, Greetd):**
   Select **Lniri (Liquid Glass)** from the session list at login.

2. **From a TTY:**
   ```bash
   exec lniri-session
   ```

3. **Standalone binary:**
   ```bash
   lniri
   # or
   Lniri
   ```

---

## 🖼️ Gallery & Examples

### Dynamic Glass & Wallpaper Reflections

<img width="1920" height="1080" alt="Glass Effect 1" src="https://github.com/user-attachments/assets/8cad6485-b685-4bc9-b22e-8cf7801cd15a" />

<img width="1920" height="1080" alt="Glass Effect 2" src="https://github.com/user-attachments/assets/fccc46f0-9cda-488b-b0e1-5939d36676cf" />

<img width="1920" height="1080" alt="Glass Effect 3" src="https://github.com/user-attachments/assets/ff3f0d17-3bf1-42e8-9660-e291189321f9" />

<img width="1920" height="1080" alt="Glass Effect 4" src="https://github.com/user-attachments/assets/eaeda5ef-1fe3-4e51-8466-10e461240021" />

### Video Demo (Live Wallpaper + Shadows)

https://github.com/user-attachments/assets/4fceeaaf-4ff1-4c4d-adcf-af52cd33a912

### With XRay Disabled

<img width="1920" height="1080" alt="XRay False" src="https://github.com/user-attachments/assets/049102f2-d7c9-4d0b-8862-671c34c61d18" />

---

## ⚙️ Configuration

Lniri looks for configuration files in the following order:
1. `~/.config/lniri/config.kdl`
2. `~/.config/niri/config.kdl` (seamless fallback for existing niri configs)
3. Custom path via `$LNIRI_CONFIG` or `$NIRI_CONFIG`

### Full Liquid Glass Example

Add the following to your `config.kdl`:

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

### Frosted Glass Look

For a subtler frosted glass look:

```kdl
saturation 0.9
vibrancy 0.2
adaptive-dim 0.25
adaptive-boost 0.25
```

<img width="462" height="276" alt="Frosted Glass" src="https://github.com/user-attachments/assets/ef2949f8-c8b7-4805-a2b5-7aaa87507525" />

### Minimal / Zero Glass

With all parameters set to 0 (except saturation = 1):

```kdl
saturation 1.0
```

<img width="462" height="276" alt="Zero Glass" src="https://github.com/user-attachments/assets/991553ad-66d0-4a62-8519-8ce3b04bdcc0" />

### Parameters Breakdown

- **`refraction-strength`**: Intensity of the background optical refraction.
- **`fringing`**: Chromatic dispersion effect (RGB prism fringing along edges).
  <br/><img width="243" height="63" alt="Fringing" src="https://github.com/user-attachments/assets/56d589e5-ffa1-46e9-a58a-996d015070e9" />
- **`edge-lighting`**: Blend wallpaper colors dynamically along window borders.
  <br/><img width="533" height="320" alt="Edge Lighting 1" src="https://github.com/user-attachments/assets/91d4b152-8bec-47dc-b4dd-6f10a30a441d" />
  <br/><img width="531" height="329" alt="Edge Lighting 2" src="https://github.com/user-attachments/assets/c4ba4a55-a3cd-49b5-ae15-fdf9154650c4" />
- **`vibrancy`** & **`saturation`**: Color pop and vibrancy enhancement underneath the glass layer.
- **`adaptive-dim`** & **`adaptive-boost`**: Dynamic contrast adaptation against high and low-luminance backgrounds.

---

## ❄️ Nix / NixOS (Flake)

Lniri includes a complete standalone Flake:

```bash
# Try it out directly
nix run github:AbsolOrg/Lniri

# Or drop into a shell with lniri
nix shell github:AbsolOrg/Lniri
```

### In NixOS Configuration

```nix
{
  inputs.lniri.url = "github:AbsolOrg/Lniri";

  outputs = { self, nixpkgs, lniri, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        lniri.nixosModules.default
        {
          programs.lniri.enable = true;
        }
      ];
    };
  };
}
```

---

## 🛠️ Manual Installation (from Git)

If you prefer to clone and inspect the source yourself:

```bash
git clone https://github.com/AbsolOrg/Lniri.git
cd Lniri
./install.sh
```

Because the `target/` directory remains in the repository, any subsequent runs of `./install.sh` or `cargo build --release` are incremental and very fast.

---

## 🗑️ Uninstallation

To cleanly remove Lniri and all registered services and desktop files:

```bash
./uninstall.sh
```

---

## 📜 Credits & License

- Forked and evolved from [niri](https://github.com/niri-wm/niri) (licensed under GPL-3.0-or-later).
- Liquid glass shader effects inspired by [kwin-effects-glass](https://github.com/4v3ngR/kwin-effects-glass) and [Niri-glass](https://github.com/zaroutt/Niri-glass).
