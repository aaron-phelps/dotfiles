#!/bin/bash

# Arch Linux Setup - Common Functions and Variables
# Source this file in other setup scripts: source "$(dirname "$0")/setup-common.sh"

# Colors for output
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
NC=$(printf '\033[0m')

# Function to print colored output
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running as root (most scripts should NOT be run as root)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. It will prompt for sudo when needed."
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Common paths
DOTFILES_DIR="$HOME/dotfiles"
SCRIPTS_DIR="$HOME/Scripts/Setup"
SCRIPTS_ROOT="$HOME/Scripts"
CONFIG_DIR="$HOME/.config"
