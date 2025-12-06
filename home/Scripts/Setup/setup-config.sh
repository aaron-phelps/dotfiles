#!/bin/bash

# Arch Linux Setup - Deploy config files from dotfiles
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

CONFIG_SRC="$DOTFILES_DIR/config"
CONFIG_DEST="$HOME/.config"
EXCLUDE_FILE="$DOTFILES_DIR/dotfile_exclude.txt"
DOTFILE_LIST="$DOTFILES_DIR/dotfile_manage_add.txt"

print_status "Deploying config files from $CONFIG_SRC to $CONFIG_DEST..."

if [ ! -d "$CONFIG_SRC" ]; then
    print_warning "Directory $CONFIG_SRC not found, skipping config deployment"
    echo "skipped (not found)"
    exit 0
fi

# Create .config directory if it doesn't exist
mkdir -p "$CONFIG_DEST"

# Check if there's anything to copy
if [ -z "$(ls -A "$CONFIG_SRC" 2>/dev/null)" ]; then
    print_warning "No config files found in $CONFIG_SRC"
    echo "skipped (empty)"
    exit 0
fi

# Build rsync exclusions
rsync_excludes=()

# Exclude items from dotfile_exclude.txt
if [ -f "$EXCLUDE_FILE" ]; then
    print_status "Using exclusions from $EXCLUDE_FILE"
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
        if [[ "$pattern" == .config/* ]]; then
            relative_pattern="${pattern#.config/}"
            rsync_excludes+=("--exclude=$relative_pattern")
        fi
    done < "$EXCLUDE_FILE"
fi

# Also exclude items that will be symlinked by manage-dotfiles
if [ -f "$DOTFILE_LIST" ]; then
    print_status "Excluding items managed as symlinks"
    while IFS= read -r item || [ -n "$item" ]; do
        [[ "$item" =~ ^#.*$ || -z "$item" ]] && continue
        if [[ "$item" == .config/* ]]; then
            relative_pattern="${item#.config/}"
            rsync_excludes+=("--exclude=$relative_pattern")
        fi
    done < "$DOTFILE_LIST"
fi

rsync -a "${rsync_excludes[@]}" "$CONFIG_SRC/" "$CONFIG_DEST/"

print_success "Config files copied to $CONFIG_DEST"

# List what was copied
CONFIG_COUNT=$(find "$CONFIG_SRC" -maxdepth 1 -mindepth 1 | wc -l)
print_status "Deployed $CONFIG_COUNT configuration directories/files"
echo "deployed ($CONFIG_COUNT items)"
