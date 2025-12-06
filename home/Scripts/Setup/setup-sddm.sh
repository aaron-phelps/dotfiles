#!/bin/bash

# Arch Linux Setup - Configure SDDM display manager
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Configuring SDDM display manager..."

if ! command_exists sddm; then
    print_warning "SDDM not installed, skipping display manager configuration"
    echo "skipped (not installed)"
    exit 0
fi

# Disable other display managers if present
for dm in gdm lightdm lxdm xdm ly; do
    if systemctl is-enabled "${dm}.service" &> /dev/null; then
        print_warning "Disabling ${dm}..."
        sudo systemctl disable "${dm}.service"
    fi
done

# Copy SDDM configuration from dotfiles
if [ -f "$DOTFILES_DIR/system/etc/sddm.conf" ]; then
    print_status "Copying SDDM configuration from dotfiles..."
    sudo cp "$DOTFILES_DIR/system/etc/sddm.conf" /etc/sddm.conf
elif [ -f "$DOTFILES_DIR/etc/sddm.conf" ]; then
    print_status "Copying SDDM configuration from dotfiles..."
    sudo cp "$DOTFILES_DIR/etc/sddm.conf" /etc/sddm.conf
else
    print_warning "SDDM config not found in dotfiles, skipping"
fi

# Copy SDDM theme from dotfiles if present
if [ -d "$DOTFILES_DIR/sddm-themes/sugar-dark" ]; then
    print_status "Installing sugar-dark SDDM theme..."
    sudo cp -r "$DOTFILES_DIR/sddm-themes/sugar-dark" /usr/share/sddm/themes/
fi

# Set SDDM background image
SDDM_BG="$DOTFILES_DIR/sddm_background.jpg"
SDDM_THEME_DIR="/usr/share/sddm/themes/sugar-dark"
if [ -f "$SDDM_BG" ] && [ -d "$SDDM_THEME_DIR" ]; then
    print_status "Setting SDDM background image..."
    sudo cp "$SDDM_BG" "$SDDM_THEME_DIR/sddm_background.jpg"
    sudo sed -i 's|^Background=.*|Background="sddm_background.jpg"|' "$SDDM_THEME_DIR/theme.conf"
    print_success "SDDM background configured"
fi

# Create custom Hyprland session desktop file
print_status "Creating Hyprland session desktop file..."
mkdir -p ~/.local/share/wayland-sessions
cat > ~/.local/share/wayland-sessions/hyprland.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF
print_success "Hyprland session desktop file created"

# Enable SDDM
sudo systemctl enable sddm.service
print_success "SDDM configured and enabled"
echo "configured and enabled"
