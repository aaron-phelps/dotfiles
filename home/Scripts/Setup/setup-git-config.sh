#!/bin/bash

# Arch Linux Setup - Configure Git user settings and credential helper
# Can be run standalone or called from setup-git.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

print_status "Configuring Git..."

# Configure credential helper for GitHub CLI
if command_exists gh; then
    git config --global credential.helper "!gh auth git-credential"
    print_success "Git credential helper configured for GitHub CLI"
else
    print_warning "GitHub CLI not installed, skipping credential helper setup"
fi

# Set user info if missing or empty
if [ -z "$(git config --global user.name)" ]; then
    read -p "Enter your Git name: " GIT_USERNAME
    git config --global user.name "$GIT_USERNAME"
    print_success "Git user.name set to: $GIT_USERNAME"
else
    print_success "Git user.name already set: $(git config --global user.name)"
fi

if [ -z "$(git config --global user.email)" ]; then
    read -p "Enter your Git email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
    print_success "Git user.email set to: $GIT_EMAIL"
else
    print_success "Git user.email already set: $(git config --global user.email)"
fi

echo "configured"
