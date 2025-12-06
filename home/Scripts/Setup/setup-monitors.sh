#!/bin/bash

# Arch Linux Setup - Configure Hyprland monitors
# Wrapper for ~/Scripts/update-hyprland-monitors.sh
# Can be run standalone or called from setup-git.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

MONITOR_SCRIPT="$SCRIPTS_ROOT/update-hyprland-monitors.sh"

print_status "Configuring Hyprland monitors..."

# Check for display
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    print_warning "No display available for monitor configuration"
    print_status "Run this script again from within Hyprland, or run:"
    echo ""
    echo "  ~/Scripts/update-hyprland-monitors.sh"
    echo ""
    echo "pending (no display)"
    exit 0
fi

# Check for monitor script
if [ ! -f "$MONITOR_SCRIPT" ]; then
    print_warning "$MONITOR_SCRIPT not found, skipping monitor configuration"
    echo "skipped (script not found)"
    exit 0
fi

chmod +x "$MONITOR_SCRIPT"

if "$MONITOR_SCRIPT"; then
    print_success "Monitor configuration complete"
    echo "configured"
else
    print_warning "Monitor setup encountered an issue"
    echo "failed"
    exit 1
fi
