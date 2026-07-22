#!/bin/bash

# Exit on error
set -e

# Get the directory of this script (project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SERVICE_PATH="${SCRIPT_DIR}/package/tracker/service.py"

echo "=== Time Tracker Installer ==="

# 1. Make the service executable
echo "Making service.py executable..."
chmod +x "$SERVICE_PATH"

# 2. Set up the systemd user service
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"

echo "Creating systemd user service file at: ${USER_SYSTEMD_DIR}/timetracker.service"
cat <<EOF > "${USER_SYSTEMD_DIR}/timetracker.service"
[Unit]
Description=Desktop Time Tracker Service
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=${SCRIPT_DIR}/package/tracker
ExecStart=${SERVICE_PATH}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

# 3. Reload systemd user manager, enable, and start the service
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "Enabling and starting timetracker.service..."
systemctl --user enable timetracker.service
systemctl --user restart timetracker.service

echo "Systemd service installed and started successfully."
echo "You can check its status using: systemctl --user status timetracker.service"

# 4. Install the KDE Plasma widget
PLASMOID_ID="com.github.abdulMueedWhaeed.timetracker"

# Ensure local plasma directory structure exists
mkdir -p "${HOME}/.local/share/plasma/plasmoids"

if command -v kpackagetool6 &> /dev/null; then
    echo "KDE Plasma 6 detected (kpackagetool6). Installing widget..."
    # Check if already installed
    if kpackagetool6 --type Plasma/Applet --list | grep -q "$PLASMOID_ID"; then
        echo "Widget is already installed. Upgrading..."
        kpackagetool6 --type Plasma/Applet --upgrade "${SCRIPT_DIR}/package"
    else
        echo "Installing widget..."
        kpackagetool6 --type Plasma/Applet --install "${SCRIPT_DIR}/package"
    fi
elif command -v kpackagetool5 &> /dev/null; then
    echo "KDE Plasma 5 detected (kpackagetool5). Installing widget..."
    if kpackagetool5 --type Plasma/Applet --list | grep -q "$PLASMOID_ID"; then
        echo "Widget is already installed. Upgrading..."
        kpackagetool5 --type Plasma/Applet --upgrade "${SCRIPT_DIR}/package"
    else
        echo "Installing widget..."
        kpackagetool5 --type Plasma/Applet --install "${SCRIPT_DIR}/package"
    fi
else
    echo "Neither kpackagetool6 nor kpackagetool5 found."
    echo "You can install it manually by symlinking the package directory:"
    echo "ln -sfn \"\${SCRIPT_DIR}/package\" \"\${HOME}/.local/share/plasma/plasmoids/\${PLASMOID_ID}\""
fi

echo "=== Installation Completed Successfully ==="
