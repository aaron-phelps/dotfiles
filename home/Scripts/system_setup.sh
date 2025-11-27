#!/bin/bash

# Arch Linux System Setup Script
# This script configures the system based on package lists in ~/dotfiles/

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. It will prompt for sudo when needed."
   exit 1
fi

# Step 0: Install yay if not present
print_status "Step 0: Checking for yay AUR helper..."
if ! command -v yay &> /dev/null; then
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
else
    print_success "yay is already installed"
fi

# Step 1: Enable multilib repository
print_status "Step 1: Enabling multilib repository..."
if grep -q "^\[multilib\]" /etc/pacman.conf; then
    print_success "multilib is already enabled"
else
    print_warning "Enabling multilib repository..."
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # If the above didn't work (repo might be completely commented), try alternative
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    fi

    sudo pacman -Sy
    print_success "multilib repository enabled and database synchronized"
fi

# Step 2: Install packages from pkglist_min.txt
print_status "Step 2: Installing official packages from ~/dotfiles/pkglist_min.txt..."
if [ ! -f ~/dotfiles/pkglist_min.txt ]; then
    print_error "File ~/dotfiles/pkglist_min.txt not found!"
    exit 1
fi

# Read packages and install
mapfile -t DESIRED_PACKAGES < <(grep -v '^#' ~/dotfiles/pkglist_min.txt | grep -v '^$')
if [ ${#DESIRED_PACKAGES[@]} -gt 0 ]; then
    print_status "Installing ${#DESIRED_PACKAGES[@]} packages..."
    sudo pacman -S --needed --noconfirm "${DESIRED_PACKAGES[@]}" || print_warning "Some packages may have failed to install"
    print_success "Package installation complete"
else
    print_warning "No packages found in pkglist_min.txt"
fi

# Step 3: Remove packages not in pkglist_min.txt
print_status "Step 3: Removing official packages not in pkglist_min.txt..."

# Check if AUR package list exists (we need it to avoid removing AUR packages here)
if [ ! -f ~/dotfiles/aur_pkglist_min.txt ]; then
    print_error "File ~/dotfiles/aur_pkglist_min.txt not found!"
    exit 1
fi

# Read AUR package list early so we don't remove them here
mapfile -t DESIRED_AUR_PACKAGES < <(grep -v '^#' ~/dotfiles/aur_pkglist_min.txt | grep -v '^$') 2>/dev/null || DESIRED_AUR_PACKAGES=()

# Get explicitly installed official packages (not from AUR)
mapfile -t INSTALLED_OFFICIAL < <(pacman -Qqe | grep -vxFf <(pacman -Qqm))

# Find packages to remove (installed but not in desired list, and not AUR packages or yay)
PACKAGES_TO_REMOVE=()
for pkg in "${INSTALLED_OFFICIAL[@]}"; do
    # Skip if in desired packages list
    if [[ " ${DESIRED_PACKAGES[*]} " =~ " ${pkg} " ]]; then
        continue
    fi
    # Skip yay (will be managed separately)
    if [[ "$pkg" == "yay" ]]; then
        continue
    fi
    PACKAGES_TO_REMOVE+=("$pkg")
done

if [ ${#PACKAGES_TO_REMOVE[@]} -gt 0 ]; then
    print_warning "The following ${#PACKAGES_TO_REMOVE[@]} packages will be removed:"
    printf '%s\n' "${PACKAGES_TO_REMOVE[@]}"

    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove packages but keep dependencies
        sudo pacman -R --noconfirm "${PACKAGES_TO_REMOVE[@]}" || print_warning "Some packages could not be removed (may be dependencies)"
        print_success "Package removal complete"
    else
        print_warning "Package removal skipped"
    fi
else
    print_success "No packages to remove"
fi

# Clean up orphaned dependencies
print_status "Cleaning up orphaned dependencies..."
ORPHANS=$(pacman -Qdtq)
if [ -n "$ORPHANS" ]; then
    sudo pacman -R --noconfirm $ORPHANS
    print_success "Orphaned dependencies removed"
else
    print_success "No orphaned dependencies found"
fi

# Step 4: Install and manage AUR packages
print_status "Step 4: Installing AUR packages from ~/dotfiles/aur_pkglist_min.txt..."
# Note: DESIRED_AUR_PACKAGES was already loaded in Step 3
if [ ${#DESIRED_AUR_PACKAGES[@]} -gt 0 ]; then
    print_status "Installing ${#DESIRED_AUR_PACKAGES[@]} AUR packages..."
    yay -S --needed --noconfirm "${DESIRED_AUR_PACKAGES[@]}" || print_warning "Some AUR packages may have failed to install"
    print_success "AUR package installation complete"
else
    print_warning "No AUR packages found in aur_pkglist_min.txt"
fi

# Remove AUR packages not in aur_pkglist_min.txt
print_status "Removing AUR packages not in aur_pkglist_min.txt..."

# Get installed AUR packages
mapfile -t INSTALLED_AUR < <(pacman -Qqm)

# Find AUR packages to remove
AUR_TO_REMOVE=()
for pkg in "${INSTALLED_AUR[@]}"; do
    # Skip if in desired AUR packages list
    if [[ " ${DESIRED_AUR_PACKAGES[*]} " =~ " ${pkg} " ]]; then
        continue
    fi
    # Skip yay itself (keep the AUR helper)
    if [[ "$pkg" == "yay" ]]; then
        continue
    fi
    AUR_TO_REMOVE+=("$pkg")
done

if [ ${#AUR_TO_REMOVE[@]} -gt 0 ]; then
    print_warning "The following ${#AUR_TO_REMOVE[@]} AUR packages will be removed:"
    printf '%s\n' "${AUR_TO_REMOVE[@]}"

    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        yay -R --noconfirm "${AUR_TO_REMOVE[@]}" || print_warning "Some AUR packages could not be removed"
        print_success "AUR package removal complete"
    else
        print_warning "AUR package removal skipped"
    fi
else
    print_success "No AUR packages to remove"
fi

# Step 5: Configure SDDM
print_status "Step 5: Configuring SDDM display manager..."
if command -v sddm &> /dev/null; then
    # Disable other display managers if present
    for dm in gdm lightdm lxdm xdm ly; do
        if systemctl is-enabled "${dm}.service" &> /dev/null; then
            print_warning "Disabling ${dm}..."
            sudo systemctl disable "${dm}.service"
        fi
    done

    # Copy SDDM configuration from dotfiles
    if [ -f ~/dotfiles/etc/sddm.conf ]; then
        print_status "Copying SDDM configuration from dotfiles..."
        sudo cp ~/dotfiles/etc/sddm.conf /etc/sddm.conf
    else
        print_warning "~/dotfiles/etc/sddm.conf not found, skipping SDDM config"
    fi

    # Enable SDDM
    sudo systemctl enable sddm.service
    print_success "SDDM configured and enabled"
else
    print_warning "SDDM not installed, skipping display manager configuration"
fi

# Step 6: Create directories
print_status "Step 6: Creating directories..."
mkdir -p ~/Pictures/Wallpapers
mkdir -p ~/Videos/Recordings
print_success "Directories created: ~/Pictures/Wallpapers and ~/Videos/Recordings"

# Step 7: Move wallpaper
print_status "Step 7: Moving default wallpaper..."
if [ -f ~/dotfiles/wallpaper_default.jpg ]; then
    cp -f ~/dotfiles/wallpaper_default.jpg ~/Pictures/Wallpapers/
    print_success "Wallpaper copied to ~/Pictures/Wallpapers/"
else
    print_warning "Wallpaper file ~/dotfiles/wallpaper_default.jpg not found"
fi

# Step 8: Copy config files
print_status "Step 8: Copying config files from ~/dotfiles/config/ to ~/.config/..."
if [ ! -d ~/dotfiles/config ]; then
    print_warning "Directory ~/dotfiles/config/ not found, skipping config deployment"
else
    # Create .config directory if it doesn't exist
    mkdir -p ~/.config

    # Copy all contents from dotfiles/config to .config
    # Using rsync with exclude file if it exists
    if [ "$(ls -A ~/dotfiles/config)" ]; then
        EXCLUDE_FILE="$HOME/dotfiles/dotfile_exclude.txt"
        if [ -f "$EXCLUDE_FILE" ]; then
            # Convert .config/path patterns to just path for rsync
            rsync -a --exclude-from=<(grep -v '^#' "$EXCLUDE_FILE" | grep -v '^$' | sed 's|^\.config/||') ~/dotfiles/config/ ~/.config/
        else
            rsync -a ~/dotfiles/config/ ~/.config/
        fi
        print_success "Config files copied to ~/.config/"

        # List what was copied
        CONFIG_COUNT=$(find ~/dotfiles/config/ -maxdepth 1 -mindepth 1 | wc -l)
        print_status "Deployed $CONFIG_COUNT configuration directories/files"
    else
        print_warning "No config files found in ~/dotfiles/config/"
    fi
fi

print_status "Performing final cleanup..."
sudo pacman -Sc --noconfirm
yay -Sc --noconfirm

# Step 9: Create dotfile symlinks
print_status "Step 9: Creating dotfile symlinks from ~/dotfiles/dotfile_manage_add.txt..."
DOTFILE_LIST="$HOME/dotfiles/dotfile_manage_add.txt"
DOTFILE_MANAGE="$HOME/dotfiles/dotfile_manage.sh"

if [ ! -f "$DOTFILE_LIST" ]; then
    print_warning "File $DOTFILE_LIST not found, skipping dotfile linking"
elif [ ! -f "$DOTFILE_MANAGE" ]; then
    print_warning "File $DOTFILE_MANAGE not found, skipping dotfile linking"
else
    # Ensure manage script is executable
    chmod +x "$DOTFILE_MANAGE"

    # Read items and add each one
    mapfile -t DOTFILE_ITEMS < <(grep -v '^#' "$DOTFILE_LIST" | grep -v '^$')

    if [ ${#DOTFILE_ITEMS[@]} -gt 0 ]; then
        print_status "Linking ${#DOTFILE_ITEMS[@]} dotfile items..."
        for item in "${DOTFILE_ITEMS[@]}"; do
            print_status "  Adding: $item"
            "$DOTFILE_MANAGE" add "$item" || print_warning "Failed to add $item"
        done
        print_success "Dotfile linking complete"
    else
        print_warning "No items found in $DOTFILE_LIST"
    fi
fi

print_success "System setup complete!"
echo
print_status "Summary:"
echo "  • yay AUR helper: installed"
echo "  • multilib repository: enabled"
echo "  • Official packages: synchronized"
echo "  • AUR packages: synchronized"
echo "  • SDDM: configured and enabled"
echo "  • Directories: created"
echo "  • Wallpaper: moved"
echo "  • Config files: deployed"
echo "  • Dotfile symlinks: created"
echo
print_warning "Please reboot your system for all changes to take effect."
