#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "          Lniri (Liquid Glass Niri) Installer             "
echo "=========================================================="
echo ""

# 1. Ask for sudo credentials upfront and keep token alive
echo "==> Requesting administrator privileges (sudo)..."
sudo -v

# Keep-alive loop in background so sudo never times out during build
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null || true' EXIT

# 2. Determine target repository location
DEFAULT_INSTALL_DIR="$HOME/.local/share/lniri"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

if [ -f "$SCRIPT_DIR/Cargo.toml" ] && grep -q "lniri" "$SCRIPT_DIR/Cargo.toml" 2>/dev/null; then
  BUILD_DIR="$SCRIPT_DIR"
  echo "==> Building directly from current directory: $BUILD_DIR"
else
  BUILD_DIR="${LNIRI_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
  if [ -d "$BUILD_DIR/.git" ]; then
    echo "==> Updating Lniri repository in $BUILD_DIR..."
    git -C "$BUILD_DIR" fetch --depth=1 origin main
    git -C "$BUILD_DIR" reset --hard origin/main
  else
    echo "==> Cloning Lniri into persistent directory: $BUILD_DIR..."
    mkdir -p "$(dirname "$BUILD_DIR")"
    git clone --depth=1 https://github.com/AbsolOrg/Lniri.git "$BUILD_DIR"
  fi
fi

# 3. Detect package manager and install build dependencies
echo "==> Checking build dependencies..."
if command -v pacman >/dev/null 2>&1; then
  ARCH_PKGS=(rust cargo pkgconf clang libxkbcommon libinput seatd pango cairo pipewire wayland)
  MISSING_PKGS=()
  for pkg in "${ARCH_PKGS[@]}"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      MISSING_PKGS+=("$pkg")
    fi
  done
  if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "==> Installing missing dependencies: ${MISSING_PKGS[*]}..."
    sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
  fi
elif command -v apt-get >/dev/null 2>&1; then
  echo "==> Ensuring build dependencies with apt-get..."
  sudo apt-get update -y
  sudo apt-get install -y build-essential cargo rustc pkg-config clang \
    libxkbcommon-dev libinput-dev libseat-dev libpango1.0-dev libcairo2-dev \
    libpipewire-0.3-dev libsystemd-dev libwayland-dev libgbm-dev libdisplay-info-dev libudev-dev
elif command -v dnf >/dev/null 2>&1; then
  echo "==> Ensuring build dependencies with dnf..."
  sudo dnf install -y cargo rust pkgconf-pkg-config clang \
    libxkbcommon-devel libinput-devel libseat-devel pango-devel cairo-devel \
    pipewire-devel systemd-devel wayland-devel mesa-libgbm-devel libdisplay-info-devel
fi

# 4. Build Lniri using persistent target cache
echo "==> Building Lniri in release mode (target folder cached in $BUILD_DIR/target)..."
cd "$BUILD_DIR"
cargo build --release --bin lniri

# 5. Install binaries
echo "==> Installing /usr/local/bin/lniri..."
sudo install -Dm755 "$BUILD_DIR/target/release/lniri" /usr/local/bin/lniri
sudo ln -sf /usr/local/bin/lniri /usr/local/bin/Lniri

# 6. Install session wrapper
echo "==> Installing /usr/local/bin/lniri-session..."
sudo install -Dm755 "$BUILD_DIR/resources/lniri-session" /usr/local/bin/lniri-session

# 7. Install systemd user service and target
echo "==> Installing systemd user units..."
mkdir -p "$HOME/.local/share/systemd/user"
install -Dm644 "$BUILD_DIR/resources/lniri.service" "$HOME/.local/share/systemd/user/lniri.service"
install -Dm644 "$BUILD_DIR/resources/lniri-shutdown.target" "$HOME/.local/share/systemd/user/lniri-shutdown.target"
systemctl --user daemon-reload 2>/dev/null || true

# 8. Register Wayland session
echo "==> Registering Wayland session entry..."
sudo mkdir -p /usr/share/wayland-sessions
sudo install -Dm644 "$BUILD_DIR/resources/lniri.desktop" /usr/share/wayland-sessions/lniri.desktop

if [ -d /usr/share/xdg-desktop-portal ]; then
  sudo install -Dm644 "$BUILD_DIR/resources/lniri-portals.conf" /usr/share/xdg-desktop-portal/lniri-portals.conf 2>/dev/null || true
fi

# 9. Initial config if none exists
if [ ! -f "$HOME/.config/lniri/config.kdl" ] && [ ! -f "$HOME/.config/niri/config.kdl" ]; then
  echo "==> Setting up default configuration at ~/.config/lniri/config.kdl..."
  mkdir -p "$HOME/.config/lniri"
  if [ -f "$BUILD_DIR/config.kdl" ]; then
    cp "$BUILD_DIR/config.kdl" "$HOME/.config/lniri/config.kdl"
  elif [ -f "$BUILD_DIR/resources/default-config.kdl" ]; then
    cp "$BUILD_DIR/resources/default-config.kdl" "$HOME/.config/lniri/config.kdl"
  fi
fi

cat <<'DONE_MSG'

==========================================================
    Lniri (Liquid Glass) was successfully installed!
==========================================================

Binaries:
  /usr/local/bin/lniri
  /usr/local/bin/Lniri (symlink)
  /usr/local/bin/lniri-session

How to start:
  - Select "Lniri (Liquid Glass)" in your Display / Login Manager (GDM, SDDM, Ly, etc.)
  - Or from a TTY: exec lniri-session

Configuration:
  ~/.config/lniri/config.kdl (or ~/.config/niri/config.kdl)

To uninstall:
  ./uninstall.sh

DONE_MSG
