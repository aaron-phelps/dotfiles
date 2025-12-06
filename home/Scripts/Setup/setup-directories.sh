#!/bin/bash

# Arch Linux Setup - Create standard directories
# Can be run standalone or called from setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Creating directories..."

mkdir -p ~/Pictures/Wallpapers
mkdir -p ~/Videos/Recordings
mkdir -p ~/Downloads
mkdir -p ~/Documents
mkdir -p ~/Projects

print_success "Directories created:"
echo "  • ~/Pictures/Wallpapers"
echo "  • ~/Videos/Recordings"
echo "  • ~/Downloads"
echo "  • ~/Documents"
echo "  • ~/Projects"

echo "created"
