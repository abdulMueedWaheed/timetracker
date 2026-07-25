#!/bin/bash

set -euo pipefail

echo "=== Time Tracker Installer ==="

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGE_DIR="${CURRENT_DIR}/package"
TRACKER_SOURCE="${CURRENT_DIR}/tracker"

PLASMA_DIR="${HOME}/.local/share/plasma/plasmoids"
INSTALL_TRACKER_DIR="${HOME}/.local/share/timetracker/app"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${USER_SYSTEMD_DIR}/timetracker.service"

# Read the real Id straight from metadata.json instead of hardcoding it here,
# so this can never drift out of sync with the actual package.
PLASMOID_ID="$(grep -oP '"Id"\s*:\s*"\K[^"]+' "${PACKAGE_DIR}/metadata.json" || true)"
if [[ -z "$PLASMOID_ID" ]]; then
    echo "Could not read KPlugin.Id from ${PACKAGE_DIR}/metadata.json — aborting."
    exit 1
fi
echo "Plasmoid Id: $PLASMOID_ID"

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

# Exact match (^...$) instead of a loose substring grep
if $KPACKAGE_TOOL --type Plasma/Applet --list | grep -qE "^${PLASMOID_ID}\$"; then
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

# Sanity check: make sure the script is actually runnable as-is
# (correct shebang, points at an interpreter that exists).
if ! head -n1 "$SERVICE_PATH" | grep -q '^#!'; then
    echo "Warning: ${SERVICE_PATH} has no shebang line — systemd needs one to execute it directly."
fi

###############################################################################
# Install systemd service (only the FIRST time)
###############################################################################

SERVICE_ALREADY_INSTALLED=false
if [[ -f "$SERVICE_FILE" ]]; then
    SERVICE_ALREADY_INSTALLED=true
fi

if [[ "$SERVICE_ALREADY_INSTALLED" == false ]]; then
    echo "Installing systemd service (first-time setup)..."
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

    systemctl --user daemon-reload
    systemctl --user enable --now timetracker.service
else
    echo "systemd service already installed — skipping unit creation."

    # This is the important part: the unit already existed, but we just
    # replaced the code it runs. If it's currently running, restart it
    # so it actually picks up the new tracker code instead of silently
    # continuing to run the old version in memory.
    if systemctl --user is-active --quiet timetracker.service; then
        echo "Restarting service to pick up updated tracker code..."
        systemctl --user restart timetracker.service
    else
        echo "Service exists but wasn't running — starting it..."
        systemctl --user start timetracker.service
    fi
fi

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