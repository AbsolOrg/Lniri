#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "               Lniri Uninstaller                          "
echo "=========================================================="
echo ""

# Refuse if an lniri session is currently active
if systemctl --user -q is-active lniri.service 2>/dev/null; then
  echo "lniri.service is currently active (your running session)."
  echo "Log out first, then run this script from a TTY:"
  echo "  pkill -9 lniri"
  echo ""
  echo "After logging out, re-run uninstall.sh."
  exit 1
fi

# Stop and disable the unit if it's loaded
if systemctl --user -q is-enabled lniri.service 2>/dev/null; then
  systemctl --user disable --now lniri.service 2>/dev/null || true
fi

echo "Removing binaries (/usr/local/bin/lniri, Lniri, lniri-session)..."
sudo rm -f /usr/local/bin/lniri
sudo rm -f /usr/local/bin/Lniri
sudo rm -f /usr/local/bin/lniri-session

# Also cleanup legacy niri-glass binaries if present
sudo rm -f /usr/local/bin/niri-glass
sudo rm -f /usr/local/bin/niri-glass-session

echo "Removing session desktop entries..."
sudo rm -f /usr/share/wayland-sessions/lniri.desktop
sudo rm -f /usr/share/wayland-sessions/niri-glass.desktop
sudo rm -f /usr/share/xdg-desktop-portal/lniri-portals.conf 2>/dev/null || true

echo "Removing systemd user units..."
rm -f "$HOME/.local/share/systemd/user/lniri.service"
rm -f "$HOME/.local/share/systemd/user/lniri-shutdown.target"
rm -f "$HOME/.local/share/systemd/user/niri-glass.service"

echo "Reloading systemd user units..."
systemctl --user daemon-reload 2>/dev/null || true

echo ""
echo "Lniri has been completely uninstalled."
echo ""
