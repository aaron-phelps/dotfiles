#!/bin/bash

# Arch Linux Setup - Sync AUR packages from aur_pkglist_min.txt
# Installs missing AUR packages and optionally removes unlisted ones
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

AUR_PKGLIST="$DOTFILES_DIR/aur_pkglist_min.txt"

# Parse arguments
SKIP_REMOVAL=false
AUTO_REMOVE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-removal)
            SKIP_REMOVAL=true
            shift
            ;;
        --auto-remove)
            AUTO_REMOVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-removal    Only install packages, don't remove unlisted ones"
            echo "  --auto-remove     Remove unlisted packages without prompting"
            echo "  -h, --help        Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check for yay
if ! command_exists yay; then
    print_error "yay is not installed. Run setup-yay.sh first."
    exit 1
fi

# Check for package list
if [ ! -f "$AUR_PKGLIST" ]; then
    print_error "File $AUR_PKGLIST not found!"
    exit 1
fi

# Read desired AUR packages
mapfile -t DESIRED_AUR_PACKAGES < <(grep -v '^#' "$AUR_PKGLIST" | grep -v '^$')

# Install AUR packages
print_status "Installing AUR packages from $AUR_PKGLIST..."
if [ ${#DESIRED_AUR_PACKAGES[@]} -gt 0 ]; then
    print_status "Installing ${#DESIRED_AUR_PACKAGES[@]} AUR packages..."
    yay -S --needed --noconfirm "${DESIRED_AUR_PACKAGES[@]}" || print_warning "Some AUR packages may have failed to install"
    print_success "AUR package installation complete"
else
    print_warning "No AUR packages found in aur_pkglist_min.txt"
fi

# Remove unlisted AUR packages
if [ "$SKIP_REMOVAL" = true ]; then
    print_status "Skipping AUR package removal (--skip-removal specified)"
else
    print_status "Checking for AUR packages to remove..."

    # Get installed AUR packages
    mapfile -t INSTALLED_AUR < <(pacman -Qqm)

    # Find AUR packages to remove
    AUR_TO_REMOVE=()
    for pkg in "${INSTALLED_AUR[@]}"; do
        # Skip if in desired AUR packages list
        if [[ " ${DESIRED_AUR_PACKAGES[*]} " =~ " ${pkg} " ]]; then
            continue
        fi
        # Skip yay itself
        if [[ "$pkg" == "yay" ]]; then
            continue
        fi
        AUR_TO_REMOVE+=("$pkg")
    done

    if [ ${#AUR_TO_REMOVE[@]} -gt 0 ]; then
        print_warning "The following ${#AUR_TO_REMOVE[@]} AUR packages will be removed:"
        printf '%s\n' "${AUR_TO_REMOVE[@]}"

        if [ "$AUTO_REMOVE" = true ]; then
            REPLY="y"
        else
            read -p "Do you want to proceed? (y/N): " -n 1 -r
            echo
        fi

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            yay -R --noconfirm "${AUR_TO_REMOVE[@]}" || print_warning "Some AUR packages could not be removed"
            print_success "AUR package removal complete"
        else
            print_warning "AUR package removal skipped"
        fi
    else
        print_success "No AUR packages to remove"
    fi
fi

echo "synchronized (${#DESIRED_AUR_PACKAGES[@]} packages)"
