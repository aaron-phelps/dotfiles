#!/bin/bash

# Arch Linux Setup - Fix Scripts directory permissions
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Fixing Scripts directory permissions..."

# Remove immutable attribute if set
sudo chattr -R -i "$SCRIPTS_ROOT" 2>/dev/null || true

# Set ownership to current user
sudo chown -R "$USER:$USER" "$SCRIPTS_ROOT"

# Make all scripts executable
chmod -R +x "$SCRIPTS_ROOT"

print_success "Scripts directory permissions fixed"
echo "fixed"
