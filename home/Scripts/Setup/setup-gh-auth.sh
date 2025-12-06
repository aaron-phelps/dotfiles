#!/bin/bash

# Arch Linux Setup - Authenticate with GitHub CLI
# Can be run standalone or called from setup-git.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Checking GitHub CLI authentication..."

# Check for gh
if ! command_exists gh; then
    print_error "GitHub CLI (gh) not installed. Add 'github-cli' to your package list."
    echo "skipped (gh not installed)"
    exit 1
fi

# Check if already authenticated
if gh auth status &> /dev/null; then
    print_success "Already authenticated with GitHub"
    gh auth status
    echo "already authenticated"
    exit 0
fi

# Check for display (needed for web auth)
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    print_warning "No display available for GitHub authentication"
    print_status "Run this script again after logging into a graphical session"
    echo "pending (no display)"
    exit 0
fi

# Authenticate
print_status "Authenticating with GitHub..."
if gh auth login --hostname github.com --git-protocol https --web; then
    print_success "GitHub authentication complete"
    echo "authenticated"
else
    print_error "GitHub authentication failed"
    echo "failed"
    exit 1
fi
