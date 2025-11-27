#!/bin/bash
# Git/GitHub credential setup script
# Run after reboot if no display was available during initial setup
# Also handles dotfile linking if called standalone
set -e
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
NC=$(printf '\033[0m')
print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
SECRETS_REPO="https://github.com/aaron-phelps/secret.git"
SECRETS_DIR="$HOME/.secrets"
DOTFILE_MANAGE="$HOME/Scripts/manage-dotfiles.sh"
DOTFILE_LIST="$HOME/dotfiles/dotfile_manage_add.txt"
# Check gh
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not installed"
    exit 1
fi
# Authenticate if needed
if ! gh auth status &> /dev/null; then
    print_status "Authenticating with GitHub..."
    gh auth login --hostname github.com --git-protocol https --web
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
# --- Dotfile linking (runs if list exists and wasn't completed during system setup) ---
print_status "Checking for pending dotfile linking..."
if [ ! -f "$DOTFILE_LIST" ]; then
    print_warning "Dotfile list not found: $DOTFILE_LIST"
elif [ ! -f "$DOTFILE_MANAGE" ]; then
    print_warning "Dotfile manager not found: $DOTFILE_MANAGE"
else
    chmod +x "$DOTFILE_MANAGE"
    mapfile -t DOTFILE_ITEMS < <(grep -v '^#' "$DOTFILE_LIST" | grep -v '^$')
    if [ ${#DOTFILE_ITEMS[@]} -gt 0 ]; then
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
        if [ $DOTFILE_FAILED -eq 0 ]; then
            print_success "Dotfile linking complete ($DOTFILE_SUCCESS items)"
        else
            print_warning "Dotfile linking partial ($DOTFILE_SUCCESS linked, $DOTFILE_FAILED failed)"
            print_warning "To retry failed items, run:"
            for failed_item in "${FAILED_ITEMS[@]}"; do
                echo "  ~/Scripts/manage-dotfiles.sh add \"$failed_item\""
            done
        fi
    else
        print_warning "No items found in $DOTFILE_LIST"
    fi
fi
print_success "Setup complete!"
