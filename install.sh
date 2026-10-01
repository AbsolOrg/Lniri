#!/usr/bin/env bash
set -e
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Parse command line arguments
CHECK_ONLY=false
AUTO_BUILD_LDI=false
INSTALL_PREBUILT=true

for arg in "$@"; do
  case "$arg" in
    --check|--doctor)
      CHECK_ONLY=true
      ;;
    --build-libdisplay-info|--fix-libs)
      AUTO_BUILD_LDI=true
      ;;
    --source|--build-from-source)
      INSTALL_PREBUILT=false
      ;;
    --help|-h)
      echo "Lniri (Liquid Glass Niri) Installer & Updater"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --source, --build-from-source       Compile Lniri from source instead of downloading pre-built binary"
      echo "  --check, --doctor                   Check system libraries and dependency compatibility without installing"
      echo "  --build-libdisplay-info, --fix-libs Automatically build and install libdisplay-info 0.3.0 from upstream source"
      echo "  --help, -h                          Show this help message"
      echo ""
      echo "Environment variables:"
      echo "  LNIRI_CHANNEL=release|main          Select binary release version"
      echo "  LNIRI_BUILD=source                  Force build from source"
      exit 0
      ;;
  esac
done

if [ "${LNIRI_BUILD:-}" = "source" ]; then
  INSTALL_PREBUILT=false
fi

# Version comparison helper: returns 0 if $1 >= $2
version_ge() {
  if [ "$1" = "$2" ]; then
    return 0
  fi
  local lowest
  lowest="$(printf "%s\n%s\n" "$1" "$2" | sort -V 2>/dev/null | head -n1)"
  [ "$lowest" = "$2" ]
}

# Detect installed libdisplay-info version, SONAME, and library path
detect_libdisplay_info() {
  LDI_VER=""
  LDI_SONAME=""
  LDI_PATH=""
  LDI_STATUS="missing" # missing, outdated, or ok

  # 1. Check pkg-config
  if command -v pkg-config >/dev/null 2>&1; then
    LDI_VER="$(pkg-config --modversion libdisplay-info 2>/dev/null || true)"
  fi

  # 2. Check package managers if pkg-config didn't return a version
  if [ -z "$LDI_VER" ]; then
    if command -v rpm >/dev/null 2>&1; then
      LDI_VER="$(rpm -q --qf '%{VERSION}' libdisplay-info 2>/dev/null || rpm -q --qf '%{VERSION}' libdisplay-info-devel 2>/dev/null || true)"
      LDI_VER="$(echo "$LDI_VER" | grep -v 'package.*is not installed' || true)"
    elif command -v dpkg-query >/dev/null 2>&1; then
      LDI_VER="$(dpkg-query -W -f='${Version}' libdisplay-info-dev 2>/dev/null || dpkg-query -W -f='${Version}' libdisplay-info3 2>/dev/null || dpkg-query -W -f='${Version}' libdisplay-info2 2>/dev/null || dpkg-query -W -f='${Version}' libdisplay-info1 2>/dev/null || true)"
      LDI_VER="$(echo "$LDI_VER" | sed -E 's/^[0-9]+://; s/-.*$//')"
    elif command -v pacman >/dev/null 2>&1; then
      LDI_VER="$(pacman -Q libdisplay-info 2>/dev/null | awk '{print $2}' | sed -E 's/-.*$//' || true)"
    fi
  fi

  # 3. Check filesystem for shared libraries and SONAMEs across common library locations
  local search_dirs=("/usr/local/lib" "/usr/local/lib64" "/usr/lib64" "/usr/lib" "/usr/lib/x86_64-linux-gnu" "/usr/lib/aarch64-linux-gnu" "$HOME/.local/lib")

  # Priority: check for .so.3 first (0.3.0+)
  for dir in "${search_dirs[@]}"; do
    if [ -f "$dir/libdisplay-info.so.3" ] || compgen -G "$dir/libdisplay-info.so.3*" >/dev/null 2>&1; then
      LDI_PATH="$(ls "$dir"/libdisplay-info.so.3* 2>/dev/null | head -n1)"
      LDI_SONAME="libdisplay-info.so.3"
      break
    fi
  done

  # If .so.3 not found, check for .so.2 (0.2.x, e.g. Fedora 41-43)
  if [ -z "$LDI_SONAME" ]; then
    for dir in "${search_dirs[@]}"; do
      if [ -f "$dir/libdisplay-info.so.2" ] || compgen -G "$dir/libdisplay-info.so.2*" >/dev/null 2>&1; then
        LDI_PATH="$(ls "$dir"/libdisplay-info.so.2* 2>/dev/null | head -n1)"
        LDI_SONAME="libdisplay-info.so.2"
        break
      fi
    done
  fi

  # If .so.2 not found, check for .so.1 (0.1.x)
  if [ -z "$LDI_SONAME" ]; then
    for dir in "${search_dirs[@]}"; do
      if [ -f "$dir/libdisplay-info.so.1" ] || compgen -G "$dir/libdisplay-info.so.1*" >/dev/null 2>&1; then
        LDI_PATH="$(ls "$dir"/libdisplay-info.so.1* 2>/dev/null | head -n1)"
        LDI_SONAME="libdisplay-info.so.1"
        break
      fi
    done
  fi

  # If generic .so found without version in filename, query readelf
  if [ -z "$LDI_SONAME" ]; then
    for dir in "${search_dirs[@]}"; do
      if [ -f "$dir/libdisplay-info.so" ]; then
        LDI_PATH="$dir/libdisplay-info.so"
        if command -v readelf >/dev/null 2>&1; then
          LDI_SONAME="$(readelf -d "$LDI_PATH" 2>/dev/null | grep SONAME | grep -o 'libdisplay-info\.so\.[0-9]*' || true)"
        fi
        break
      fi
    done
  fi

  # Determine status
  if [ "$LDI_SONAME" = "libdisplay-info.so.3" ]; then
    LDI_STATUS="ok"
    if [ -z "$LDI_VER" ]; then
      LDI_VER=">=0.3.0"
    fi
  elif [ -n "$LDI_VER" ] && version_ge "$LDI_VER" "0.3.0"; then
    LDI_STATUS="ok"
  elif [ -n "$LDI_VER" ] && ! version_ge "$LDI_VER" "0.3.0"; then
    LDI_STATUS="outdated"
  elif [ "$LDI_SONAME" = "libdisplay-info.so.2" ] || [ "$LDI_SONAME" = "libdisplay-info.so.1" ]; then
    LDI_STATUS="outdated"
  else
    LDI_STATUS="missing"
  fi
}

# Compile and install libdisplay-info 0.3.0 into /usr/local
build_and_install_libdisplay_info() {
  echo ""
  echo -e "${CYAN}${BOLD}==> Building & installing libdisplay-info 0.3.0 from upstream source...${RESET}"
  local build_tmp
  build_tmp="$(mktemp -d)"

  echo -e "==> Ensuring build tools (meson, ninja, git, compiler)..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y meson ninja-build git gcc || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y 2>/dev/null || true
    sudo apt-get install -y meson ninja-build git build-essential || true
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y meson ninja git gcc || true
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm meson ninja git gcc || true
  fi

  echo -e "==> Fetching libdisplay-info v0.3.0..."
  if git clone --depth 1 --branch 0.3.0 https://gitlab.freedesktop.org/emersion/libdisplay-info.git "$build_tmp/libdisplay-info" 2>/dev/null || \
     git clone --depth 1 https://gitlab.freedesktop.org/emersion/libdisplay-info.git "$build_tmp/libdisplay-info"; then
    cd "$build_tmp/libdisplay-info"
    meson setup build --prefix=/usr/local --buildtype=release
    ninja -C build
    sudo ninja -C build install

    # Configure ld.so.conf.d for /usr/local/lib and /usr/local/lib64
    if [ -d "/etc/ld.so.conf.d" ]; then
      echo -e "/usr/local/lib\n/usr/local/lib64" | sudo tee /etc/ld.so.conf.d/lniri-local-lib.conf >/dev/null 2>&1 || true
    fi
    sudo ldconfig 2>/dev/null || true
    rm -rf "$build_tmp"
    echo -e "${GREEN}${BOLD}==> libdisplay-info 0.3.0 successfully installed to /usr/local!${RESET}"
    detect_libdisplay_info
    return 0
  else
    echo -e "${RED}==> Failed to clone libdisplay-info from GitLab.${RESET}"
    rm -rf "$build_tmp"
    return 1
  fi
}

# Display warning block and prompt to build libdisplay-info
warn_outdated_libdisplay_info() {
  echo ""
  echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${YELLOW}${BOLD}║  ⚠️  WARNING: Outdated libdisplay-info detected: ${RED}${LDI_VER:-unknown}${RESET}${YELLOW}${BOLD} (SONAME: ${RED}${LDI_SONAME:-none}${RESET}${YELLOW}${BOLD})                        ║${RESET}"
  echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${YELLOW}║ Lniri requires ${BOLD}libdisplay-info >= 0.3.0${RESET}${YELLOW} (SONAME: ${BOLD}libdisplay-info.so.3${RESET}${YELLOW}).                       ║${RESET}"
  echo -e "${YELLOW}║                                                                                          ║${RESET}"
  echo -e "${YELLOW}║ Systems with older libdisplay-info (e.g. Fedora 41-43 with 0.2.0, or distros with       ║${RESET}"
  echo -e "${YELLOW}║ 0.1.x) fail during EDID decoding / CVT timing initialization. This causes the            ║${RESET}"
  echo -e "${YELLOW}║ compositor to fail on startup, producing a black screen and immediately booting back     ║${RESET}"
  echo -e "${YELLOW}║ into the display manager login screen!                                                   ║${RESET}"
  echo -e "${YELLOW}║                                                                                          ║${RESET}"
  echo -e "${YELLOW}║ Resolution options:                                                                      ║${RESET}"
  echo -e "${YELLOW}║   1) Let this installer build & install it automatically:                                ║${RESET}"
  echo -e "${YELLOW}║        ${GREEN}./install.sh --build-libdisplay-info${RESET}${YELLOW}                                              ║${RESET}"
  echo -e "${YELLOW}║   2) Or compile manually:                                                                ║${RESET}"
  echo -e "${YELLOW}║        git clone --depth 1 --branch 0.3.0 https://gitlab.freedesktop.org/emersion/libdisplay-info.git /tmp/ldi ║${RESET}"
  echo -e "${YELLOW}║        cd /tmp/ldi && meson setup build --prefix=/usr/local && ninja -C build            ║${RESET}"
  echo -e "${YELLOW}║        sudo ninja -C build install && sudo ldconfig                                      ║${RESET}"
  echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  if [ "$AUTO_BUILD_LDI" = "true" ]; then
    build_and_install_libdisplay_info
  elif [ "$CHECK_ONLY" = "false" ] && ([ -t 0 ] || [ -c /dev/tty ]); then
    read -r -p "Would you like Lniri installer to compile & install libdisplay-info 0.3.0 into /usr/local now? [y/N]: " USER_LDI_BUILD </dev/tty || USER_LDI_BUILD="N"
    case "$USER_LDI_BUILD" in
      y|Y|yes|YES)
        build_and_install_libdisplay_info
        ;;
      *)
        echo -e "${YELLOW}==> Continuing installation with existing library. Note: you may need to update libdisplay-info if you experience login black-screen issues.${RESET}"
        ;;
    esac
  fi
}

# Check all major libraries
check_system_libraries() {
  echo -e "${CYAN}${BOLD}==> Checking system graphics and compositor library dependencies...${RESET}"
  local warn_count=0

  # 1. libdisplay-info check
  detect_libdisplay_info
  if [ "$LDI_STATUS" = "ok" ]; then
    echo -e "  [✔] libdisplay-info: ${GREEN}${LDI_VER}${RESET} (${LDI_SONAME:-so.3}, >= 0.3.0) at ${LDI_PATH:-system}"
  elif [ "$LDI_STATUS" = "outdated" ]; then
    echo -e "  [!] libdisplay-info: ${RED}${LDI_VER:-unknown} (outdated, minimum: 0.3.0 / libdisplay-info.so.3)${RESET} at ${LDI_PATH:-unknown}"
    warn_count=$((warn_count + 1))
    warn_outdated_libdisplay_info
  else
    echo -e "  [?] libdisplay-info: ${YELLOW}not detected${RESET} (minimum: 0.3.0 / libdisplay-info.so.3)"
    warn_count=$((warn_count + 1))
    warn_outdated_libdisplay_info
  fi

  # Helper for other libraries
  check_library_dependency() {
    local name="$1"
    local min_v="$2"
    local desc="$3"
    local curr=""

    if command -v pkg-config >/dev/null 2>&1; then
      curr="$(pkg-config --modversion "$name" 2>/dev/null || true)"
    fi

    if [ -n "$curr" ]; then
      if version_ge "$curr" "$min_v"; then
        echo -e "  [✔] $name: ${GREEN}$curr${RESET} (>= $min_v)"
      else
        echo -e "  [!] $name: ${YELLOW}$curr (outdated, recommended: >= $min_v)${RESET} — $desc"
        warn_count=$((warn_count + 1))
      fi
    else
      echo -e "  [?] $name: ${CYAN}not detected via pkg-config${RESET} (recommended: >= $min_v) — $desc"
    fi
  }

  check_library_dependency "wayland-server" "1.21.0" "Core Wayland compositor protocol"
  check_library_dependency "libinput" "1.21.0" "Pointer and touch input handling"
  check_library_dependency "xkbcommon" "1.0.0" "Keyboard mapping and layout handling"
  check_library_dependency "libpipewire-0.3" "0.3.0" "Screen capture and portal streaming"
  check_library_dependency "libseat" "0.5.0" "Seat management and VT switching"
  check_library_dependency "pango" "1.44.0" "Font layout and text rendering"
  check_library_dependency "cairo" "1.16.0" "2D vector graphics rendering"
  check_library_dependency "gbm" "21.0.0" "Mesa Generic Buffer Management for DRM/KMS"

  echo ""
  if [ "$warn_count" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}==> All core library dependencies are compatible and up to date!${RESET}"
  else
    echo -e "${YELLOW}==> System check completed with $warn_count warning(s).${RESET}"
  fi
  echo ""
}

# Fast-path for diagnostic check
if [ "$CHECK_ONLY" = "true" ]; then
  check_system_libraries
  exit 0
fi

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

# Run system library checks before proceeding
check_system_libraries

# Update channel selection
TARGET_CHANNEL="${LNIRI_CHANNEL:-}"
if [ "$IS_UPDATE" = "true" ]; then
  CURRENT_VER="$(lniri --version 2>/dev/null || echo 'installed')"
  echo -e "==> Existing Lniri installation detected: ${GREEN}$CURRENT_VER${RESET}"
  echo -e "==> Switching to ${BOLD}Update Mode${RESET}."
  echo ""

  if [ -z "$TARGET_CHANNEL" ]; then
    echo -e "Select binary release version:"
    echo -e "  1) ${BOLD}Latest release${RESET} (stable v0.1.5) [Default]"
    echo -e "  2) ${BOLD}Rolling main${RESET} (continuous cutting-edge binary)"
    echo ""

    if [ -t 0 ] || [ -c /dev/tty ]; then
      read -r -p "Enter choice [1 or 2] (default: 1): " USER_CHOICE </dev/tty || USER_CHOICE="1"
    else
      USER_CHOICE="1"
    fi

    case "$USER_CHOICE" in
      2|main|rolling)
        TARGET_CHANNEL="main"
        ;;
      *)
        TARGET_CHANNEL="release"
        ;;
    esac
  fi
  echo -e "==> Selected binary channel: ${GREEN}$TARGET_CHANNEL${RESET}"
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
    git clone https://github.com/TattvaOrg/Lniri.git "$OVERLAY_SRC_DIR"
  fi
fi

# 2.5 Architecture detection & Pre-compiled GitHub Release Fast-Path
ARCH="$(uname -m)"
LNIRI_REPO="${LNIRI_REPO:-TattvaOrg/Lniri}"
INSTALL_PREBUILT=true
for arg in "$@"; do
  if [ "$arg" = "--source" ] || [ "$arg" = "--build-from-source" ]; then
    INSTALL_PREBUILT=false
  fi
done
if [ "${LNIRI_BUILD:-}" = "source" ]; then
  INSTALL_PREBUILT=false
fi

BINARY_INSTALLED=false
if [ "$INSTALL_PREBUILT" = "true" ]; then
  echo -e "==> Checking for pre-compiled binary release from GitHub (${GREEN}$LNIRI_REPO${RESET} - $ARCH)..."
  DOWNLOAD_URL=""

  # Build list of direct candidate URLs to check
  CANDIDATE_URLS=()
  if [ -n "${LNIRI_VERSION:-}" ]; then
    CANDIDATE_URLS+=(
      "https://github.com/$LNIRI_REPO/releases/download/$LNIRI_VERSION/lniri-$ARCH"
      "https://github.com/$LNIRI_REPO/releases/download/$LNIRI_VERSION/lniri"
      "https://github.com/$LNIRI_REPO/releases/download/$LNIRI_VERSION/lniri-$ARCH.tar.gz"
      "https://github.com/$LNIRI_REPO/releases/download/v$LNIRI_VERSION/lniri-$ARCH"
    )
  fi

  if [ "$TARGET_CHANNEL" = "main" ]; then
    CANDIDATE_URLS+=(
      "https://github.com/$LNIRI_REPO/releases/download/rolling/lniri-$ARCH"
      "https://github.com/$LNIRI_REPO/releases/download/rolling/lniri"
      "https://github.com/$LNIRI_REPO/releases/download/rolling/lniri-$ARCH.tar.gz"
      "https://github.com/$LNIRI_REPO/releases/download/0.1.5/lniri-$ARCH"
      "https://github.com/$LNIRI_REPO/releases/download/0.1.5/lniri"
      "https://github.com/$LNIRI_REPO/releases/download/0.1.5/lniri-$ARCH.tar.gz"
    )
  else
    CANDIDATE_URLS+=(
      "https://github.com/$LNIRI_REPO/releases/download/0.1.5/lniri-$ARCH"
      "https://github.com/$LNIRI_REPO/releases/download/0.1.5/lniri"
      "https://github.com/$LNIRI_REPO/releases/download/0.1.5/lniri-$ARCH.tar.gz"
      "https://github.com/$LNIRI_REPO/releases/latest/download/lniri-$ARCH"
      "https://github.com/$LNIRI_REPO/releases/latest/download/lniri"
      "https://github.com/$LNIRI_REPO/releases/download/rolling/lniri-$ARCH"
      "https://github.com/$LNIRI_REPO/releases/download/rolling/lniri"
    )
  fi

  for cand in "${CANDIDATE_URLS[@]}"; do
    if curl -sIL "$cand" 2>/dev/null | grep -qE "HTTP/[123\.]* (200|302)"; then
      DOWNLOAD_URL="$cand"
      break
    fi
  done

  # Fallback to GitHub API if candidate check misses
  if [ -z "$DOWNLOAD_URL" ]; then
    LATEST_JSON="$(curl -sSL "https://api.github.com/repos/$LNIRI_REPO/releases/latest" 2>/dev/null || true)"
    DOWNLOAD_URL="$(echo "$LATEST_JSON" | grep -o "https://[^\"]*releases/download/[^\"]*/lniri-$ARCH" | head -n1 || true)"
  fi
  if [ -z "$DOWNLOAD_URL" ]; then
    RELEASES_JSON="$(curl -sSL "https://api.github.com/repos/$LNIRI_REPO/releases" 2>/dev/null || true)"
    DOWNLOAD_URL="$(echo "$RELEASES_JSON" | grep -o "https://[^\"]*releases/download/[^\"]*/lniri-$ARCH" | head -n1 || true)"
  fi

  if [ -n "$DOWNLOAD_URL" ]; then
    echo -e "==> Pre-compiled binary found: ${GREEN}$DOWNLOAD_URL${RESET}"
    echo -e "==> Downloading Lniri release binary..."

    if [[ "$DOWNLOAD_URL" == *.tar.gz ]]; then
      TMP_DIR="$(mktemp -d)"
      if curl -fL --progress-bar "$DOWNLOAD_URL" -o "$TMP_DIR/bundle.tar.gz"; then
        tar -xzf "$TMP_DIR/bundle.tar.gz" -C "$TMP_DIR"
        FOUND_BIN="$(find "$TMP_DIR" -type f \( -name "lniri" -o -name "lniri-$ARCH" \) | head -n1)"
        if [ -n "$FOUND_BIN" ]; then
          chmod +x "$FOUND_BIN"
          sudo install -Dm755 "$FOUND_BIN" /usr/local/bin/lniri
          sudo ln -sf /usr/local/bin/lniri /usr/local/bin/Lniri
          echo -e "==> Pre-compiled binary successfully installed to ${GREEN}/usr/local/bin/lniri${RESET}!"
          BINARY_INSTALLED=true
        fi
      fi
      rm -rf "$TMP_DIR"
    else
      TMP_BIN="$(mktemp)"
      if curl -fL --progress-bar "$DOWNLOAD_URL" -o "$TMP_BIN"; then
        chmod +x "$TMP_BIN"
        sudo install -Dm755 "$TMP_BIN" /usr/local/bin/lniri
        sudo ln -sf /usr/local/bin/lniri /usr/local/bin/Lniri
        rm -f "$TMP_BIN"
        echo -e "==> Pre-compiled binary successfully installed to ${GREEN}/usr/local/bin/lniri${RESET}!"
        BINARY_INSTALLED=true
      else
        rm -f "$TMP_BIN"
      fi
    fi

    # Ensure runtime library compatibility (e.g. libdisplay-info.so.3)
    if [ "$BINARY_INSTALLED" = "true" ]; then
      mkdir -p "$HOME/.local/lib"
      if [ -d "/etc/ld.so.conf.d" ]; then
        echo -e "/usr/local/lib\n/usr/local/lib64" | sudo tee /etc/ld.so.conf.d/lniri-local-lib.conf >/dev/null 2>&1 || true
        sudo ldconfig 2>/dev/null || true
      fi

      NEEDED_SONAME=""
      if command -v readelf >/dev/null 2>&1; then
        NEEDED_SONAME="$(readelf -d /usr/local/bin/lniri 2>/dev/null | grep NEEDED | grep "libdisplay-info" | grep -o 'libdisplay-info\.so\.[0-9]*' || true)"
      fi
      if [ -z "$NEEDED_SONAME" ]; then
        NEEDED_SONAME="libdisplay-info.so.3"
      fi

      FOUND_LIB="$(find /usr/local/lib /usr/local/lib64 /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu "$HOME/.local/lib" -name "$NEEDED_SONAME*" 2>/dev/null | head -n1)"
      if [ -n "$FOUND_LIB" ]; then
        echo -e "==> Linking runtime dependency: ${GREEN}$FOUND_LIB${RESET} ($NEEDED_SONAME)..."
        ln -sf "$FOUND_LIB" "$HOME/.local/lib/$NEEDED_SONAME" 2>/dev/null || true
        sudo ln -sf "$FOUND_LIB" "/usr/local/lib/$NEEDED_SONAME" 2>/dev/null || true
        sudo ldconfig 2>/dev/null || true
      else
        echo -e "${YELLOW}==> Warning: $NEEDED_SONAME not found in standard system library paths.${RESET}"
        echo -e "${YELLOW}    If you encounter a black screen or crashes on login, run: ./install.sh --build-libdisplay-info${RESET}"
      fi
    fi
  fi

  if [ "$BINARY_INSTALLED" = "false" ]; then
    echo -e "${YELLOW}==> Warning: No pre-compiled binary could be downloaded for $ARCH from GitHub releases.${RESET}"
    echo -e "By default, Lniri installs pre-built binaries in seconds and avoids compiling on your system."
    echo -e "If you wish to force compiling from source, please re-run with: ${BOLD}$0 --source${RESET}"
    exit 1
  fi
fi

if [ "$BINARY_INSTALLED" = "false" ]; then
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

  # Check if libdisplay-info is outdated after distro packages are installed
  detect_libdisplay_info
  if [ "$LDI_STATUS" = "outdated" ] || [ "$LDI_STATUS" = "missing" ]; then
    echo -e "${YELLOW}==> Note: System package manager installed an outdated or missing libdisplay-info (${LDI_VER:-$LDI_SONAME}).${RESET}"
    echo -e "${YELLOW}    Lniri source build requires libdisplay-info >= 0.3.0.${RESET}"
    warn_outdated_libdisplay_info
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
  if [ -f "$OVERLAY_SRC_DIR/src/layer/mapped.rs" ]; then
    cp -f "$OVERLAY_SRC_DIR/src/layer/mapped.rs" "$NIRI_SRC_DIR/src/layer/"
  fi

  # 6. Build Lniri incrementally using persistent target/ cache
  echo -e "==> Compiling Lniri (target cache in ${GREEN}$NIRI_SRC_DIR/target${RESET})..."
  cargo build --release --bin niri

  # 7. Install standalone binary as /usr/local/bin/lniri (leaving normal niri intact)
  echo -e "==> Installing binary to /usr/local/bin/lniri..."
  sudo install -Dm755 "$NIRI_SRC_DIR/target/release/niri" /usr/local/bin/lniri
  sudo ln -sf /usr/local/bin/lniri /usr/local/bin/Lniri
fi

# 8. Install session script
echo -e "==> Installing session script /usr/local/bin/lniri-session..."
if [ -f "$OVERLAY_SRC_DIR/resources/lniri-session" ]; then
  sudo install -Dm755 "$OVERLAY_SRC_DIR/resources/lniri-session" /usr/local/bin/lniri-session
  sudo ln -sf /usr/local/bin/lniri-session /usr/bin/lniri-session 2>/dev/null || true
elif [ -f "/usr/bin/niri-session" ]; then
  sudo install -m 755 /usr/bin/niri-session /usr/local/bin/lniri-session
  sudo sed -i \
    -e 's|niri --session|lniri --session|g' \
    -e 's|niri\.service|lniri.service|g' \
    /usr/local/bin/lniri-session
  sudo ln -sf /usr/local/bin/lniri-session /usr/bin/lniri-session 2>/dev/null || true
fi

# 9. Register systemd user unit
echo -e "==> Installing systemd user units..."
mkdir -p "$HOME/.local/share/systemd/user"
mkdir -p "$HOME/.config/systemd/user"
if [ -f "$OVERLAY_SRC_DIR/resources/lniri.service" ]; then
  install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri.service" "$HOME/.local/share/systemd/user/lniri.service"
  install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri.service" "$HOME/.config/systemd/user/lniri.service"
  sudo install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri.service" /usr/lib/systemd/user/lniri.service 2>/dev/null || sudo install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri.service" /etc/systemd/user/lniri.service 2>/dev/null || true
fi
if [ -f "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" ]; then
  install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" "$HOME/.local/share/systemd/user/lniri-shutdown.target"
  install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" "$HOME/.config/systemd/user/lniri-shutdown.target"
  sudo install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" /usr/lib/systemd/user/lniri-shutdown.target 2>/dev/null || sudo install -Dm644 "$OVERLAY_SRC_DIR/resources/lniri-shutdown.target" /etc/systemd/user/lniri-shutdown.target 2>/dev/null || true
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
echo -e "  Check ${CYAN}https://github.com/TattvaOrg/Lniri/blob/main/template.md${RESET} for"
echo -e "  full terminal transparency configs (Alacritty, Kitty, Ghostty) and glass presets."
echo ""
