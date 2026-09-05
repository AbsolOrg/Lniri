#!/usr/bin/env bash
set -e

# ==============================================================================
# Lniri - Liquid Glass Compositor Installer & Updater
# Repository: https://github.com/AbsolOrg/Lniri
# ==============================================================================

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# Detect if Lniri is already installed
IS_UPDATE=false
if command -v lniri >/dev/null 2>&1 || [ -f "/usr/local/bin/lniri" ]; then
  IS_UPDATE=true
fi

echo -e "${CYAN}${BOLD}==========================================================${RESET}"
if [ "$IS_UPDATE" = "true" ]; then
  echo -e "${CYAN}${BOLD}          Lniri (Liquid Glass) Updater                    ${RESET}"
else
  echo -e "${CYAN}${BOLD}          Lniri (Liquid Glass Niri) Installer             ${RESET}"
fi
echo -e "${CYAN}${BOLD}==========================================================${RESET}"
echo ""

# Update channel selection
TARGET_CHANNEL="${LNIRI_CHANNEL:-}"
if [ "$IS_UPDATE" = "true" ]; then
  CURRENT_VER="$(lniri --version 2>/dev/null || echo 'installed')"
  echo -e "==> Existing Lniri installation detected: ${GREEN}$CURRENT_VER${RESET}"
  echo -e "==> Switching to ${BOLD}Update Mode${RESET}."
  echo ""

  if [ -z "$TARGET_CHANNEL" ]; then
    echo -e "Select update channel for Niri upstream codebase:"
    echo -e "  1) ${BOLD}Main branch${RESET} (cutting-edge git commits) [Default]"
    echo -e "  2) ${BOLD}Latest release${RESET} (stable tagged release of Niri)"
    echo ""

    if [ -t 0 ] || [ -c /dev/tty ]; then
      read -r -p "Enter choice [1 or 2] (default: 1): " USER_CHOICE </dev/tty || USER_CHOICE="1"
    else
      USER_CHOICE="1"
    fi

    case "$USER_CHOICE" in
      2|release|stable)
        TARGET_CHANNEL="release"
        ;;
      *)
        TARGET_CHANNEL="main"
        ;;
    esac
  fi
  echo -e "==> Selected channel: ${GREEN}$TARGET_CHANNEL${RESET}"
  echo ""
else
  TARGET_CHANNEL="${LNIRI_CHANNEL:-main}"
fi

# 1. Ask for sudo credentials upfront and keep token alive in background
echo -e "==> Requesting administrator privileges (sudo)..."
sudo -v

while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null || true' EXIT

# 2. Setup paths
LNIRI_BASE_DIR="$HOME/.local/share/lniri"
NIRI_SRC_DIR="$LNIRI_BASE_DIR/niri"
OVERLAY_SRC_DIR=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [ -f "$SCRIPT_DIR/src/render_helpers/liquid_glass.rs" ]; then
  OVERLAY_SRC_DIR="$SCRIPT_DIR"
  echo -e "==> Using local Lniri overlay files from: ${GREEN}$OVERLAY_SRC_DIR${RESET}"
else
  OVERLAY_SRC_DIR="$LNIRI_BASE_DIR/overlay"
  mkdir -p "$OVERLAY_SRC_DIR"
  if [ -d "$OVERLAY_SRC_DIR/.git" ]; then
    echo -e "==> Fetching latest Lniri overlay from GitHub..."
    git -C "$OVERLAY_SRC_DIR" pull --rebase origin main || true
  else
    echo -e "==> Downloading Lniri overlay files..."
    git clone https://github.com/AbsolOrg/Lniri.git "$OVERLAY_SRC_DIR"
  fi
fi

# 3. Detect package manager and install build dependencies
echo -e "==> Checking and installing build dependencies..."
if command -v pacman >/dev/null 2>&1; then
  ARCH_PKGS=(git rust cargo pkgconf clang libxkbcommon libinput seatd pango cairo pipewire wayland)
  MISSING_PKGS=()
  for pkg in "${ARCH_PKGS[@]}"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      MISSING_PKGS+=("$pkg")
    fi
  done
  if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo -e "==> Installing missing dependencies: ${MISSING_PKGS[*]}..."
    sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
  fi
elif command -v apt-get >/dev/null 2>&1; then
  echo -e "==> Ensuring build dependencies with apt-get..."
  sudo apt-get update -y
  sudo apt-get install -y git build-essential cargo rustc pkg-config clang \
    libxkbcommon-dev libinput-dev libseat-dev libpango1.0-dev libcairo2-dev \
    libpipewire-0.3-dev libsystemd-dev libwayland-dev libgbm-dev libdisplay-info-dev libudev-dev
elif command -v dnf >/dev/null 2>&1; then
  echo -e "==> Ensuring build dependencies with dnf..."
  sudo dnf install -y git cargo rust pkgconf-pkg-config clang \
    libxkbcommon-devel libinput-devel libseat-devel pango-devel cairo-devel \
    pipewire-devel systemd-devel wayland-devel mesa-libgbm-devel libdisplay-info-devel
elif command -v zypper >/dev/null 2>&1; then
  echo -e "==> Ensuring build dependencies with zypper..."
  sudo zypper install -y git cargo rust clang pkg-config libxkbcommon-devel libinput-devel \
    libseat-devel pango-devel cairo-devel pipewire-devel systemd-devel wayland-devel
fi

# 4. Clone or update upstream Niri in persistent cache directory
mkdir -p "$LNIRI_BASE_DIR"
if [ ! -d "$NIRI_SRC_DIR/.git" ]; then
  echo -e "==> Cloning upstream official Niri repository into persistent build directory..."
  git clone https://github.com/niri-wm/niri.git "$NIRI_SRC_DIR"
else
  echo -e "==> Updating upstream Niri source repository..."
  git -C "$NIRI_SRC_DIR" fetch --tags origin
fi

cd "$NIRI_SRC_DIR"
if [ "$TARGET_CHANNEL" = "release" ]; then
  LATEST_TAG="$(git tag -l 'v*' --sort=-v:refname | head -n1)"
  if [ -n "$LATEST_TAG" ]; then
    echo -e "==> Checking out upstream Niri release tag: ${GREEN}$LATEST_TAG${RESET}..."
    git checkout -f "$LATEST_TAG"
  else
    echo -e "==> No release tags found; checking out main branch..."
    git checkout -f main
    git pull --rebase origin main
  fi
else
  echo -e "==> Checking out upstream Niri main branch..."
  git checkout -f main
  git pull --rebase origin main
fi

# 5. Apply Lniri liquid glass overlay
echo -e "==> Applying Lniri liquid-glass extension files..."
mkdir -p "$NIRI_SRC_DIR/src/render_helpers/shaders"
mkdir -p "$NIRI_SRC_DIR/niri-config/src"
mkdir -p "$NIRI_SRC_DIR/src/layer"

cp -f "$OVERLAY_SRC_DIR/src/render_helpers/liquid_glass.rs" "$NIRI_SRC_DIR/src/render_helpers/"
cp -f "$OVERLAY_SRC_DIR/src/render_helpers/background_effect.rs" "$NIRI_SRC_DIR/src/render_helpers/"
cp -f "$OVERLAY_SRC_DIR/src/render_helpers/framebuffer_effect.rs" "$NIRI_SRC_DIR/src/render_helpers/"
cp -f "$OVERLAY_SRC_DIR/src/render_helpers/xray.rs" "$NIRI_SRC_DIR/src/render_helpers/"
cp -f "$OVERLAY_SRC_DIR/src/render_helpers/mod.rs" "$NIRI_SRC_DIR/src/render_helpers/"
cp -f "$OVERLAY_SRC_DIR/src/render_helpers/shaders/clipped_surface.frag" "$NIRI_SRC_DIR/src/render_helpers/shaders/"
cp -f "$OVERLAY_SRC_DIR/src/render_helpers/shaders/mod.rs" "$NIRI_SRC_DIR/src/render_helpers/shaders/"
cp -f "$OVERLAY_SRC_DIR/niri-config/src/appearance.rs" "$NIRI_SRC_DIR/niri-config/src/"
cp -f "$OVERLAY_SRC_DIR/src/layer/mapped.rs" "$NIRI_SRC_DIR/src/layer/"

# 6. Build Lniri incrementally using persistent target/ cache
echo -e "==> Compiling Lniri (target cache in ${GREEN}$NIRI_SRC_DIR/target${RESET})..."
cargo build --release --bin niri

# 7. Install standalone binary as /usr/local/bin/lniri (leaving normal niri intact)
echo -e "==> Installing binary to /usr/local/bin/lniri..."
sudo install -Dm755 "$NIRI_SRC_DIR/target/release/niri" /usr/local/bin/lniri
sudo ln -sf /usr/local/bin/lniri /usr/local/bin/Lniri

# 8. Install session script
echo -e "==> Installing session script /usr/local/bin/lniri-session..."
if [ -f "$OVERLAY_SRC_DIR/resources/lniri-session" ]; then
  sudo install -Dm755 "$OVERLAY_SRC_DIR/resources/lniri-session" /usr/local/bin/lniri-session
elif [ -f "/usr/bin/niri-session" ]; then
  sudo install -m 755 /usr/bin/niri-session /usr/local/bin/lniri-session
  sudo sed -i \
    -e 's|niri --session|lniri --session|g' \
    -e 's|niri\.service|lniri.service|g' \
    /usr/local/bin/lniri-session
fi

# 9. Register systemd user unit
echo -e "==> Installing systemd user units..."
mkdir -p "$HOME/.local/share/systemd/user"
if [ -f "$OVERLAY_SRC_DIR/resources/lniri.service" ]; then
  install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri.service" "$HOME/.local/share/systemd/user/lniri.service"
fi
if [ -f "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" ]; then
  install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" "$HOME/.local/share/systemd/user/lniri-shutdown.target"
fi
systemctl --user daemon-reload 2>/dev/null || true

# 10. Register Wayland session entry for Login Managers (GDM, SDDM, Ly, Greetd)
echo -e "==> Registering Wayland session entry..."
sudo mkdir -p /usr/share/wayland-sessions
if [ -f "$OVERLAY_SRC_DIR/resources/lniri.desktop" ]; then
  sudo install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri.desktop" /usr/share/wayland-sessions/lniri.desktop
else
  sudo tee /usr/share/wayland-sessions/lniri.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Lniri (Liquid Glass)
Comment=A scrollable-tiling Wayland compositor with liquid glass effects
Exec=/usr/local/bin/lniri-session
Type=Application
DesktopNames=niri;lniri
EOF
fi

if [ -f "$OVERLAY_SRC_DIR/resources/lniri-portals.conf" ] && [ -d "/usr/share/xdg-desktop-portal" ]; then
  sudo install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri-portals.conf" /usr/share/xdg-desktop-portal/lniri-portals.conf 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}${BOLD}==========================================================${RESET}"
echo -e "${GREEN}${BOLD}  Lniri (Liquid Glass) successfully installed / updated!  ${RESET}"
echo -e "${GREEN}${BOLD}==========================================================${RESET}"
echo ""
echo -e "Both normal ${BOLD}niri${RESET} and ${BOLD}Lniri${RESET} are available side-by-side on your system."
echo ""
echo -e "How to launch:"
echo -e "  • ${BOLD}From Login Manager (GDM/SDDM/Ly):${RESET} Select 'Lniri (Liquid Glass)'"
echo -e "  • ${BOLD}From TTY:${RESET} exec /usr/local/bin/lniri-session"
echo -e "  • ${BOLD}Standalone:${RESET} lniri"
echo ""
echo -e "Setup guide & presets:"
echo -e "  Check ${CYAN}https://github.com/AbsolOrg/Lniri/blob/main/template.md${RESET} for"
echo -e "  full terminal transparency configs (Alacritty, Kitty, Ghostty) and glass presets."
echo ""
