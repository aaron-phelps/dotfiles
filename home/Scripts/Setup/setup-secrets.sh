#!/bin/bash

# Arch Linux Setup - Clone/update secrets repo and install credentials
# Can be run standalone or called from setup-git.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

SECRETS_DIR="$HOME/.secrets"
SECRETS_REPO_FILE="$HOME/.secrets_repo"

print_status "Setting up credentials from secrets repo..."

# Check for saved secrets repo URL or prompt user
if [ -f "$SECRETS_REPO_FILE" ]; then
    SECRETS_REPO=$(cat "$SECRETS_REPO_FILE")
    print_status "Using saved secrets repo: $SECRETS_REPO"
else
    echo ""
    print_status "Do you have a private Git repo containing credentials (e.g., .git-credentials)?"
    read -p "Enter secrets repo URL (or leave blank to skip): " SECRETS_REPO

    if [ -n "$SECRETS_REPO" ]; then
        # Save for future runs
        echo "$SECRETS_REPO" > "$SECRETS_REPO_FILE"
        chmod 600 "$SECRETS_REPO_FILE"
        print_success "Secrets repo URL saved to $SECRETS_REPO_FILE"
    fi
fi

if [ -z "$SECRETS_REPO" ]; then
    print_warning "No secrets repo configured, skipping credential sync"
    echo "skipped (no repo configured)"
    exit 0
fi

# Clone or update secrets repo
if [ -d "$SECRETS_DIR" ]; then
    print_status "Updating existing secrets repo..."
    if git -C "$SECRETS_DIR" pull; then
        print_success "Secrets repo updated"
    else
        print_warning "Failed to update secrets repo"
    fi
else
    print_status "Cloning secrets repo..."
    if git clone "$SECRETS_REPO" "$SECRETS_DIR"; then
        print_success "Secrets repo cloned"
    else
        print_error "Failed to clone secrets repo"
        echo "failed (clone error)"
        exit 1
    fi
fi

# Install git credentials
if [ -f "$SECRETS_DIR/.git-credentials" ]; then
    cp "$SECRETS_DIR/.git-credentials" ~/.git-credentials
    chmod 600 ~/.git-credentials
    print_success "Git credentials installed"
    echo "credentials installed"
else
    print_warning "No .git-credentials found in secrets repo"
    echo "synced (no credentials file)"
fi
