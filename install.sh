#!/usr/bin/env bash
set -e

# Detect if Lniri is already installed
IS_UPDATE=false
if command -v lniri >/dev/null 2>&1 || [ -f "/usr/local/bin/lniri" ]; then
  IS_UPDATE=true
fi

echo "=========================================================="
if [ "$IS_UPDATE" = "true" ]; then
  echo "          Lniri (Liquid Glass) Updater                    "
else
  echo "          Lniri (Liquid Glass Niri) Installer             "
fi
echo "=========================================================="
echo ""

# If Lniri is already installed, handle update channel selection
TARGET_CHANNEL="${LNIRI_CHANNEL:-}"
if [ "$IS_UPDATE" = "true" ]; then
  CURRENT_VER="$(lniri --version 2>/dev/null || echo 'installed')"
  echo "==> Existing Lniri installation detected: $CURRENT_VER"
  echo "==> Switching to Update Mode."
  echo ""

  if [ -z "$TARGET_CHANNEL" ]; then
    echo "Select update channel:"
    echo "  1) Main branch (cutting-edge git main) [Default]"
    echo "  2) Latest release (stable release tag)"
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
  echo "==> Selected channel: $TARGET_CHANNEL"
  echo ""
fi

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
  echo "==> Using local repository at: $BUILD_DIR"
else
  BUILD_DIR="${LNIRI_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
  if [ ! -d "$BUILD_DIR/.git" ]; then
    echo "==> Cloning Lniri into persistent directory: $BUILD_DIR..."
    mkdir -p "$(dirname "$BUILD_DIR")"
    git clone https://github.com/AbsolOrg/Lniri.git "$BUILD_DIR"
  fi
fi

# Switch branch or tag based on target channel
cd "$BUILD_DIR"
if [ "$IS_UPDATE" = "true" ]; then
  git fetch --tags origin || true
  if [ "$TARGET_CHANNEL" = "release" ]; then
    LATEST_TAG="$(git tag -l --sort=-v:refname | head -n1)"
    if [ -n "$LATEST_TAG" ]; then
      echo "==> Checking out latest release tag: $LATEST_TAG..."
      git checkout "$LATEST_TAG"
    else
      echo "==> No release tags found in repository yet; falling back to main branch..."
      git checkout main
      git pull --rebase origin main
    fi
  else
    echo "==> Updating to latest main branch..."
    git checkout main
    git pull --rebase origin main
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

if [ "$IS_UPDATE" = "true" ]; then
cat <<'DONE_MSG'

==========================================================
      Lniri (Liquid Glass) was successfully updated!
==========================================================

Binaries updated:
  /usr/local/bin/lniri
  /usr/local/bin/Lniri (symlink)
  /usr/local/bin/lniri-session

If you are currently inside an active Lniri session,
you can reload your configuration or restart your session
to apply the changes.

DONE_MSG
else
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

To update later:
  Re-run the one-liner command to switch channels (main or release)

To uninstall:
  ./uninstall.sh

DONE_MSG
fi
