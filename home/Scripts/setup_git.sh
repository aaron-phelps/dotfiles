#!/bin/bash

# Git/GitHub credential setup script
# Run after reboot if no display was available during initial setup

set -e

RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
BLUE=$(printf '\033[0;34m')
NC=$(printf '\033[0m')

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

SECRETS_REPO="https://github.com/aaron-phelps/secret.git"
SECRETS_DIR="$HOME/.secrets"

# Check gh
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not installed"
    exit 1
fi

# Authenticate if needed
if ! gh auth status &> /dev/null; then
    print_status "Authenticating with GitHub..."
    gh auth login --web --git-protocol https
fi

# Configure credential helper
git config --global credential.helper "!gh auth git-credential"

# Set user info if missing
if ! git config --global user.name &> /dev/null; then
    read -p "Enter your Git name: " GIT_USERNAME
    git config --global user.name "$GIT_USERNAME"
fi

if ! git config --global user.email &> /dev/null; then
    read -p "Enter your Git email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

# Clone/update secrets and copy credentials
print_status "Setting up credentials..."
[ -d "$SECRETS_DIR" ] && git -C "$SECRETS_DIR" pull || git clone "$SECRETS_REPO" "$SECRETS_DIR"

if [ -f "$SECRETS_DIR/.git-credentials" ]; then
    cp "$SECRETS_DIR/.git-credentials" ~/.git-credentials
    chmod 600 ~/.git-credentials
    print_success "Git credentials installed"
fi

print_success "Git setup complete"
