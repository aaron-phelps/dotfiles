#!/bin/bash

# Arch Linux Setup - Sync official packages from pkglist_min.txt
# Installs missing packages and optionally removes unlisted ones
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

PKGLIST="$DOTFILES_DIR/pkglist_min.txt"
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

# Check for package list
if [ ! -f "$PKGLIST" ]; then
    print_error "File $PKGLIST not found!"
    exit 1
fi

# Read desired packages
mapfile -t DESIRED_PACKAGES < <(grep -v '^#' "$PKGLIST" | grep -v '^$')

# Install packages
print_status "Installing official packages from $PKGLIST..."
if [ ${#DESIRED_PACKAGES[@]} -gt 0 ]; then
    print_status "Installing ${#DESIRED_PACKAGES[@]} packages..."
    sudo pacman -S --needed --noconfirm "${DESIRED_PACKAGES[@]}" || print_warning "Some packages may have failed to install"
    print_success "Package installation complete"
else
    print_warning "No packages found in pkglist_min.txt"
fi

# Remove unlisted packages
if [ "$SKIP_REMOVAL" = true ]; then
    print_status "Skipping package removal (--skip-removal specified)"
else
    print_status "Checking for packages to remove..."

    # Read AUR package list to avoid removing them
    if [ -f "$AUR_PKGLIST" ]; then
        mapfile -t DESIRED_AUR_PACKAGES < <(grep -v '^#' "$AUR_PKGLIST" | grep -v '^$') 2>/dev/null || DESIRED_AUR_PACKAGES=()
    else
        DESIRED_AUR_PACKAGES=()
    fi

    # Get explicitly installed official packages (not from AUR)
    mapfile -t INSTALLED_OFFICIAL < <(pacman -Qqe | grep -vxFf <(pacman -Qqm))

    # Find packages to remove
    PACKAGES_TO_REMOVE=()
    for pkg in "${INSTALLED_OFFICIAL[@]}"; do
        # Skip if in desired packages list
        if [[ " ${DESIRED_PACKAGES[*]} " =~ " ${pkg} " ]]; then
            continue
        fi
        # Skip yay
        if [[ "$pkg" == "yay" ]]; then
            continue
        fi
        PACKAGES_TO_REMOVE+=("$pkg")
    done

    if [ ${#PACKAGES_TO_REMOVE[@]} -gt 0 ]; then
        print_warning "The following ${#PACKAGES_TO_REMOVE[@]} packages will be removed:"
        printf '%s\n' "${PACKAGES_TO_REMOVE[@]}"

        if [ "$AUTO_REMOVE" = true ]; then
            REPLY="y"
        else
            read -p "Do you want to proceed? (y/N): " -n 1 -r
            echo
        fi

        if [[ $REPLY =~ ^[Yy]$ ]]; then
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
    ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
    if [ -n "$ORPHANS" ]; then
        sudo pacman -R --noconfirm $ORPHANS
        print_success "Orphaned dependencies removed"
    else
        print_success "No orphaned dependencies found"
    fi
fi

echo "synchronized (${#DESIRED_PACKAGES[@]} packages)"
