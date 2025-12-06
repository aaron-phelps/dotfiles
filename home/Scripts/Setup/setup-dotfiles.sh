#!/bin/bash

# Arch Linux Setup - Create dotfile symlinks
# Reads from ~/dotfiles/dotfile_manage_add.txt and creates symlinks
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

DOTFILE_LIST="$DOTFILES_DIR/dotfile_manage_add.txt"
DOTFILE_MANAGE="$SCRIPTS_ROOT/manage-dotfiles.sh"

print_status "Creating dotfile symlinks from $DOTFILE_LIST..."

# Check for required files
if [ ! -f "$DOTFILE_LIST" ]; then
    print_warning "File $DOTFILE_LIST not found, skipping dotfile linking"
    echo "skipped (list not found)"
    exit 0
fi

if [ ! -f "$DOTFILE_MANAGE" ]; then
    print_warning "File $DOTFILE_MANAGE not found, skipping dotfile linking"
    echo "skipped (script not found)"
    exit 0
fi

# Ensure manage script is executable
chmod +x "$DOTFILE_MANAGE"

# Read items and add each one
mapfile -t DOTFILE_ITEMS < <(grep -v '^#' "$DOTFILE_LIST" | grep -v '^$')

if [ ${#DOTFILE_ITEMS[@]} -eq 0 ]; then
    print_warning "No items found in $DOTFILE_LIST"
    echo "skipped (empty list)"
    exit 0
fi

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
    echo "linked ($DOTFILE_SUCCESS items)"
else
    print_warning "To retry failed items, run:"
    for failed_item in "${FAILED_ITEMS[@]}"; do
        echo "  ~/Scripts/manage-dotfiles.sh add \"$failed_item\""
    done
    echo "partial ($DOTFILE_SUCCESS linked, $DOTFILE_FAILED failed)"
fi
