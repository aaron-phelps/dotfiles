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

# Step 5: Create directories
print_status "Step 5: Creating directories..."
mkdir -p ~/Pictures/Wallpapers
mkdir -p ~/Pictures/Screenshots
mkdir -p ~/Videos/Recordings
print_success "Directories created: ~/Pictures/Wallpapers and ~/Videos/Recordings"

# Step 6: Move wallpaper
print_status "Step 6: Moving default wallpaper..."
if [ -f ~/dotfiles/wallpaper_default.jpg ]; then
    cp ~/dotfiles/wallpaper_default.jpg ~/Pictures/Wallpapers/
    print_success "Wallpaper copied to ~/Pictures/Wallpapers/"
else
    print_warning "Wallpaper file ~/dotfiles/wallpaper_default.jpg not found"
fi

# Final cleanup
print_status "Performing final cleanup..."
sudo pacman -Sc --noconfirm
yay -Sc --noconfirm

print_success "System setup complete!"
echo
print_status "Summary:"
echo "  • yay AUR helper: installed"
echo "  • multilib repository: enabled"
echo "  • Official packages: synchronized"
echo "  • AUR packages: synchronized"
echo "  • Directories: created"
echo "  • Wallpaper: moved"
echo
print_warning "Please reboot your system for all changes to take effect."
