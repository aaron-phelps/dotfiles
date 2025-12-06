#!/bin/bash

# Arch Linux Setup - Install and enable Hyprland plugins
# Can be run standalone or called from setup-git.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Setting up Hyprland plugins..."

# Check for hyprpm
if ! command_exists hyprpm; then
    print_warning "hyprpm not found. Is Hyprland installed?"
    echo "skipped (hyprpm not found)"
    exit 0
fi

# Check for display
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    print_warning "No display available for Hyprland plugin setup"
    print_status "Run this script again from within a Hyprland session"
    echo "pending (no display)"
    exit 0
fi

# Update hyprpm
print_status "Updating hyprpm..."
hyprpm update || print_warning "hyprpm update had issues"

# Install and enable hyprexpo-plus
print_status "Installing hyprexpo-plus..."
if hyprpm add https://github.com/CerBor/hyprexpo-plus -v; then
    hyprpm enable hyprexpo-plus
    print_success "hyprexpo-plus installed and enabled"
else
    print_warning "Failed to install hyprexpo-plus"
fi

# Install and enable hyprscrolling from hyprland-plugins
print_status "Installing hyprland-plugins (hyprscrolling)..."
if hyprpm add https://github.com/hyprwm/hyprland-plugins -v; then
    hyprpm enable hyprscrolling
    print_success "hyprscrolling installed and enabled"
else
    print_warning "Failed to install hyprland-plugins"
fi

print_success "Hyprland plugin setup complete"
echo "plugins installed"
