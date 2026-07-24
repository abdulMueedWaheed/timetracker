#!/bin/bash

set -euo pipefail

echo "=== Time Tracker Installer ==="

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLASMOID_ID="com.github.abdulMueedWaheed.timetracker"

PACKAGE_DIR="${CURRENT_DIR}/package"
TRACKER_SOURCE="${CURRENT_DIR}/tracker"

PLASMA_DIR="${HOME}/.local/share/plasma/plasmoids"
INSTALL_TRACKER_DIR="${HOME}/.local/share/timetracker/app"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"

mkdir -p "$PLASMA_DIR"
mkdir -p "$INSTALL_TRACKER_DIR"
mkdir -p "$USER_SYSTEMD_DIR"

###############################################################################
# Install / Upgrade Plasma Widget
###############################################################################

if command -v kpackagetool6 >/dev/null 2>&1; then
    KPACKAGE_TOOL="kpackagetool6"
elif command -v kpackagetool5 >/dev/null 2>&1; then
    KPACKAGE_TOOL="kpackagetool5"
else
    echo "Neither kpackagetool6 nor kpackagetool5 was found."
    exit 1
fi

echo "Installing Plasma widget..."

if $KPACKAGE_TOOL --type Plasma/Applet --list | grep -q "$PLASMOID_ID"; then
    $KPACKAGE_TOOL --type Plasma/Applet --upgrade "$PACKAGE_DIR"
else
    $KPACKAGE_TOOL --type Plasma/Applet --install "$PACKAGE_DIR"
fi

###############################################################################
# Install Tracker
###############################################################################

echo "Installing tracker..."

rm -rf "$INSTALL_TRACKER_DIR"
cp -r "$TRACKER_SOURCE" "$INSTALL_TRACKER_DIR"

SERVICE_PATH="${INSTALL_TRACKER_DIR}/service.py"
chmod +x "$SERVICE_PATH"

###############################################################################
# Install systemd service
###############################################################################

SERVICE_FILE="${USER_SYSTEMD_DIR}/timetracker.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Desktop Time Tracker Service
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_TRACKER_DIR}
ExecStart=${SERVICE_PATH}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

###############################################################################
# Enable service
###############################################################################

systemctl --user daemon-reload
systemctl --user enable --now timetracker.service

echo
echo "========================================"
echo "Time Tracker installed successfully!"
echo "========================================"
echo
echo "Widget ID : $PLASMOID_ID"
echo "Tracker   : $INSTALL_TRACKER_DIR"
echo "Service   : timetracker.service"
echo
echo "Useful commands:"
echo "  systemctl --user status timetracker.service"
echo "  journalctl --user -u timetracker.service -f"