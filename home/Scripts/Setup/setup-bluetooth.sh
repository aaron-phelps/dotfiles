#!/bin/bash
# Arch Linux Setup - Enable Bluetooth
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"
check_not_root
print_status "Configuring Bluetooth..."

# Enable and start bluetooth service
if systemctl list-unit-files bluetooth.service &> /dev/null; then
    sudo systemctl enable --now bluetooth.service
    print_success "Bluetooth service enabled"
else
    print_warning "Bluetooth service not found (bluez may not be installed)"
    echo "skipped (service not found)"
    exit 0
fi

# Unblock bluetooth
if command_exists rfkill; then
    sudo rfkill unblock bluetooth
    print_success "Bluetooth unblocked"
else
    print_warning "rfkill not found, skipping unblock"
fi

# Configure blueman - disable StatusNotifierItem plugin (use StatusIcon instead)
if command_exists blueman-applet; then
    gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"
    print_success "Blueman configured (StatusNotifierItem disabled)"
fi
echo "enabled"
