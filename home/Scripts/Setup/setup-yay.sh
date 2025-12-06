#!/bin/bash

# Arch Linux Setup - Install yay AUR helper
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Checking for yay AUR helper..."

if command_exists yay; then
    print_success "yay is already installed"
    echo "installed"
    exit 0
fi

print_warning "yay not found. Installing yay..."

# Install base-devel and git if not present
sudo pacman -S --needed --noconfirm base-devel git

# Clone and build yay
cd /tmp
if [ -d "yay" ]; then
    rm -rf yay
fi
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ~

print_success "yay installed successfully"
echo "installed"
