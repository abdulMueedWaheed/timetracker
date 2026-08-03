#!/bin/bash

set -euo pipefail

echo "=== Time Tracker Uninstaller ==="

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGE_DIR="${CURRENT_DIR}/package"

PLASMA_DIR="${HOME}/.local/share/plasma/plasmoids"
INSTALL_TRACKER_DIR="${HOME}/.local/share/timetracker/app"
DATA_DIR="${HOME}/.local/share/timetracker"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${USER_SYSTEMD_DIR}/timetracker.service"

PURGE_DATA=false
if [[ "${1:-}" == "--purge-data" ]]; then
    PURGE_DATA=true
fi

# Read the real Id straight from metadata.json, same as install.sh —
# so uninstall always targets exactly what install would have installed.
PLASMOID_ID="$(grep -oP '"Id"\s*:\s*"\K[^"]+' "${PACKAGE_DIR}/metadata.json" || true)"
if [[ -z "$PLASMOID_ID" ]]; then
    echo "Could not read KPlugin.Id from ${PACKAGE_DIR}/metadata.json — aborting."
    exit 1
fi
echo "Plasmoid Id: $PLASMOID_ID"

###############################################################################
# Stop and remove systemd service
###############################################################################

if [[ -f "$SERVICE_FILE" ]]; then
    echo "Stopping tracker service..."
    if systemctl --user is-active --quiet timetracker.service; then
        systemctl --user stop timetracker.service
    fi

    if systemctl --user is-enabled --quiet timetracker.service 2>/dev/null; then
        systemctl --user disable timetracker.service
    fi

    echo "Removing systemd unit file..."
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
else
    echo "No systemd unit found at ${SERVICE_FILE} — skipping."
fi

###############################################################################
# Remove Plasma widget
###############################################################################

if command -v kpackagetool6 >/dev/null 2>&1; then
    KPACKAGE_TOOL="kpackagetool6"
elif command -v kpackagetool5 >/dev/null 2>&1; then
    KPACKAGE_TOOL="kpackagetool5"
else
    echo "Neither kpackagetool6 nor kpackagetool5 was found — skipping widget removal."
    KPACKAGE_TOOL=""
fi

if [[ -n "$KPACKAGE_TOOL" ]]; then
    if $KPACKAGE_TOOL --type Plasma/Applet --list | grep -qE "^${PLASMOID_ID}\$"; then
        echo "Removing Plasma widget..."
        $KPACKAGE_TOOL --type Plasma/Applet --remove "$PLASMOID_ID"
    else
        echo "Widget ${PLASMOID_ID} not found in kpackagetool listing — skipping."
    fi
fi

###############################################################################
# Remove tracker code
###############################################################################

if [[ -d "$INSTALL_TRACKER_DIR" ]]; then
    echo "Removing tracker code at ${INSTALL_TRACKER_DIR}..."
    rm -rf "$INSTALL_TRACKER_DIR"
else
    echo "No tracker code found at ${INSTALL_TRACKER_DIR} — skipping."
fi

###############################################################################
# Optionally remove tracked data (DB, etc.)
###############################################################################

if [[ "$PURGE_DATA" == true ]]; then
    if [[ -d "$DATA_DIR" ]]; then
        echo "Purging all tracked data at ${DATA_DIR}..."
        rm -rf "$DATA_DIR"
    else
        echo "No data directory found at ${DATA_DIR} — nothing to purge."
    fi
else
    if [[ -d "$DATA_DIR" ]]; then
        echo "Keeping tracked data at ${DATA_DIR} (re-run with --purge-data to delete it too)."
    fi
fi

echo
echo "========================================"
echo "Time Tracker uninstalled."
echo "========================================"
echo
if [[ "$PURGE_DATA" == false ]]; then
    echo "Your tracked history was left untouched at:"
    echo "  ${DATA_DIR}"
    echo "Run '$(basename "$0") --purge-data' to remove it as well."
fi