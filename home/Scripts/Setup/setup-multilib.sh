#!/bin/bash

# Arch Linux Setup - Enable multilib repository
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Enabling multilib repository..."

if grep -q "^\[multilib\]" /etc/pacman.conf; then
    print_success "multilib is already enabled"
    echo "already enabled"
    exit 0
fi

print_warning "Enabling multilib repository..."
sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

# If the above didn't work (repo might be completely commented), try alternative
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
fi

sudo pacman -Sy
print_success "multilib repository enabled and database synchronized"
echo "enabled"
