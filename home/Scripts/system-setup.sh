#!/bin/bash

# Arch Linux System Setup Script
# This script configures the system based on package lists in ~/dotfiles/

set -e  # Exit on error

# Colors for output
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
NC=$(printf '\033[0m')

# Status tracking
STATUS_YAY="pending"
STATUS_MULTILIB="pending"
STATUS_OFFICIAL_PKGS="pending"
STATUS_AUR_PKGS="pending"
STATUS_SDDM="pending"
STATUS_DIRECTORIES="pending"
STATUS_WALLPAPER="pending"
STATUS_CONFIG="pending"
STATUS_GIT="pending"
STATUS_DOTFILES="pending"
STATUS_MONITOR="pending"

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

# Make sure all Scripts are executable and owned by user for modifications as needed
sudo chattr -R -i ~/Scripts/ 2>/dev/null || true
sudo chown -R $USER:$USER ~/Scripts/
chmod -R +x ~/Scripts/

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
    STATUS_YAY="installed"
else
    print_success "yay is already installed"
    STATUS_YAY="already installed"
fi

# Step 1: Enable multilib repository
print_status "Step 1: Enabling multilib repository..."
if grep -q "^\[multilib\]" /etc/pacman.conf; then
    print_success "multilib is already enabled"
    STATUS_MULTILIB="already enabled"
else
    print_warning "Enabling multilib repository..."
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # If the above didn't work (repo might be completely commented), try alternative
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    fi

    sudo pacman -Sy
    print_success "multilib repository enabled and database synchronized"
    STATUS_MULTILIB="enabled"
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
    STATUS_OFFICIAL_PKGS="synchronized (${#DESIRED_PACKAGES[@]} packages)"
else
    print_warning "No packages found in pkglist_min.txt"
    STATUS_OFFICIAL_PKGS="skipped (empty list)"
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
    STATUS_AUR_PKGS="synchronized (${#DESIRED_AUR_PACKAGES[@]} packages)"
else
    print_warning "No AUR packages found in aur_pkglist_min.txt"
    STATUS_AUR_PKGS="skipped (empty list)"
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

    # Copy SDDM theme from dotfiles if present
    if [ -d ~/dotfiles/sddm-themes/sugar-dark ]; then
        print_status "Installing sugar-dark SDDM theme..."
        sudo cp -r ~/dotfiles/sddm-themes/sugar-dark /usr/share/sddm/themes/
    fi

    # Set SDDM background image
    SDDM_BG="$HOME/dotfiles/sddm_background.jpg"
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
    STATUS_SDDM="configured and enabled"
else
    print_warning "SDDM not installed, skipping display manager configuration"
    STATUS_SDDM="skipped (not installed)"
fi

# Step 6: Create directories
print_status "Step 6: Creating directories..."
mkdir -p ~/Pictures/Wallpapers
mkdir -p ~/Videos/Recordings
print_success "Directories created: ~/Pictures/Wallpapers and ~/Videos/Recordings"
STATUS_DIRECTORIES="created"

# Step 7: Move wallpaper
print_status "Step 7: Moving default wallpaper..."
if [ -f ~/dotfiles/wallpaper_default.jpg ]; then
    cp -f ~/dotfiles/wallpaper_default.jpg ~/Pictures/Wallpapers/
    print_success "Wallpaper copied to ~/Pictures/Wallpapers/"
    STATUS_WALLPAPER="copied"
else
    print_warning "Wallpaper file ~/dotfiles/wallpaper_default.jpg not found"
    STATUS_WALLPAPER="skipped (not found)"
fi

# Step 8: Copy config files
print_status "Step 8: Copying config files from ~/dotfiles/config/ to ~/.config/..."
if [ ! -d ~/dotfiles/config ]; then
    print_warning "Directory ~/dotfiles/config/ not found, skipping config deployment"
    STATUS_CONFIG="skipped (not found)"
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
        STATUS_CONFIG="deployed ($CONFIG_COUNT items)"
    else
        print_warning "No config files found in ~/dotfiles/config/"
        STATUS_CONFIG="skipped (empty)"
    fi
fi

print_status "Performing final cleanup..."
sudo pacman -Sc --noconfirm
yay -Sc --noconfirm

# Step 9: Configure Git
print_status "Step 9: Configuring Git..."

SETUP_GIT="$HOME/Scripts/setup-git.sh"
DOTFILE_MANAGE="$HOME/Scripts/manage-dotfiles.sh"
GIT_SETUP_SUCCESS=false

if [ ! -f "$SETUP_GIT" ]; then
    print_warning "$SETUP_GIT not found, skipping Git configuration"
    STATUS_GIT="skipped (script not found)"
elif ! command -v gh &> /dev/null; then
    print_warning "GitHub CLI (gh) not installed. Add 'github-cli' to your package list."
    STATUS_GIT="skipped (gh not installed)"
elif [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    if "$SETUP_GIT"; then
        GIT_SETUP_SUCCESS=true
        print_success "Git configuration complete"
        STATUS_GIT="configured"
    else
        print_warning "Git setup encountered an issue"
        STATUS_GIT="failed"
    fi
else
    print_warning "No display available for Git authentication."
    print_status "After reboot with a display, run:"
    echo ""
    echo "  ~/Scripts/setup-git.sh"
    echo ""
    print_status "This will complete both Git setup and dotfile linking."
    STATUS_GIT="pending (no display)"
fi

# Step 10: Create dotfile symlinks
print_status "Step 10: Creating dotfile symlinks from ~/dotfiles/dotfile_manage_add.txt..."
DOTFILE_LIST="$HOME/dotfiles/dotfile_manage_add.txt"

if [ ! -f "$DOTFILE_LIST" ]; then
    print_warning "File $DOTFILE_LIST not found, skipping dotfile linking"
    STATUS_DOTFILES="skipped (list not found)"
elif [ ! -f "$DOTFILE_MANAGE" ]; then
    print_warning "File $DOTFILE_MANAGE not found, skipping dotfile linking"
    STATUS_DOTFILES="skipped (script not found)"
elif [ "$GIT_SETUP_SUCCESS" = false ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    # Git setup didn't run due to no display, skip dotfile linking too (setup_git.sh will handle it)
    print_warning "Skipping dotfile linking (will run via setup_git.sh after reboot)"
    STATUS_DOTFILES="pending (via setup_git.sh)"
else
    # Ensure manage script is executable
    chmod +x "$DOTFILE_MANAGE"

    # Read items and add each one
    mapfile -t DOTFILE_ITEMS < <(grep -v '^#' "$DOTFILE_LIST" | grep -v '^$')

    if [ ${#DOTFILE_ITEMS[@]} -gt 0 ]; then
        print_status "Linking ${#DOTFILE_ITEMS[@]} dotfile items..."
        DOTFILE_SUCCESS=0
        DOTFILE_FAILED=0
        FAILED_ITEMS=()
        for item in "${DOTFILE_ITEMS[@]}"; do
            print_status "  Adding: $item"
            if "$DOTFILE_MANAGE" add "$item"; then
                DOTFILE_SUCCESS=$((DOTFILE_SUCCESS + 1))
            else
                print_warning "Failed to add $item"
                DOTFILE_FAILED=$((DOTFILE_FAILED + 1))
                FAILED_ITEMS+=("$item")
            fi
        done
        print_success "Dotfile linking complete"
        if [ $DOTFILE_FAILED -eq 0 ]; then
            STATUS_DOTFILES="linked ($DOTFILE_SUCCESS items)"
        else
            STATUS_DOTFILES="partial ($DOTFILE_SUCCESS linked, $DOTFILE_FAILED failed)"
            print_warning "To retry failed items, run:"
            for failed_item in "${FAILED_ITEMS[@]}"; do
                echo "  ~/Scripts/manage-dotfiles.sh add \"$failed_item\""
            done
        fi
    else
        print_warning "No items found in $DOTFILE_LIST"
        STATUS_DOTFILES="skipped (empty list)"
    fi
fi

# Step 11: Configure Hyprland monitors
print_status "Step 11: Configuring Hyprland monitors..."

MONITOR_SCRIPT="$HOME/Scripts/update-hyprland-monitors.sh"

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    print_warning "No display available for monitor configuration."
    print_status "After reboot into Hyprland, run:"
    echo ""
    echo "  ~/Scripts/update-hyprland-monitors.sh"
    echo ""
    STATUS_MONITOR="pending (no display)"
elif [ ! -f "$MONITOR_SCRIPT" ]; then
    print_warning "$MONITOR_SCRIPT not found, skipping monitor configuration"
    STATUS_MONITOR="skipped (script not found)"
else
    chmod +x "$MONITOR_SCRIPT"
    if "$MONITOR_SCRIPT"; then
        print_success "Monitor configuration complete"
        STATUS_MONITOR="configured"
    else
        print_warning "Monitor setup encountered an issue"
        STATUS_MONITOR="failed"
    fi
fi

print_success "System setup complete!"
echo
print_status "Summary:"
echo "  • yay AUR helper: $STATUS_YAY"
echo "  • multilib repository: $STATUS_MULTILIB"
echo "  • Official packages: $STATUS_OFFICIAL_PKGS"
echo "  • AUR packages: $STATUS_AUR_PKGS"
echo "  • SDDM: $STATUS_SDDM"
echo "  • Directories: $STATUS_DIRECTORIES"
echo "  • Wallpaper: $STATUS_WALLPAPER"
echo "  • Config files: $STATUS_CONFIG"
echo "  • Git: $STATUS_GIT"
echo "  • Dotfile symlinks: $STATUS_DOTFILES"
echo "  • Monitor config: $STATUS_MONITOR"
echo
print_warning "Please reboot your system for all changes to take effect."
