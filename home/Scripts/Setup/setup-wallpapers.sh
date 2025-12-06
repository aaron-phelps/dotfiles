#!/bin/bash

# Arch Linux Setup - Deploy wallpapers from dotfiles
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

WALLPAPER_SRC="$DOTFILES_DIR/Wallpapers"
WALLPAPER_DEST="$HOME/Pictures/Wallpapers"

print_status "Deploying wallpapers..."

# Ensure destination exists
mkdir -p "$WALLPAPER_DEST"

if [ ! -d "$WALLPAPER_SRC" ]; then
    print_warning "Source directory $WALLPAPER_SRC not found"
    echo "skipped (source not found)"
    exit 0
fi

if [ -z "$(ls -A "$WALLPAPER_SRC" 2>/dev/null)" ]; then
    print_warning "No wallpapers found in $WALLPAPER_SRC"
    echo "skipped (empty source)"
    exit 0
fi

cp -f -r "$WALLPAPER_SRC"/* "$WALLPAPER_DEST/"

WALLPAPER_COUNT=$(find "$WALLPAPER_DEST" -type f | wc -l)
print_success "Wallpapers copied to $WALLPAPER_DEST ($WALLPAPER_COUNT files)"
echo "copied ($WALLPAPER_COUNT files)"
