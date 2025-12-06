#!/bin/bash

# Arch Linux Setup - Git/GitHub Setup Orchestrator
# Runs all git-related setup modules in order
#
# Usage:
#   ./setup-git.sh              # Run all git setup steps
#   ./setup-git.sh --list       # List available modules
#   ./setup-git.sh config auth  # Run specific modules

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

# Define modules in order
declare -A MODULES=(
    [config]="Configure Git user settings and credential helper"
    [auth]="Authenticate with GitHub CLI"
    [secrets]="Clone/update secrets repo and install credentials"
    [dotfiles]="Create dotfile symlinks"
    [plugins]="Install Hyprland plugins"
    [monitors]="Configure Hyprland monitors"
)

# Order of execution
MODULE_ORDER=(
    config
    auth
    secrets
    dotfiles
    plugins
    monitors
)

# Status tracking
declare -A STATUS

# Print usage
print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS] [MODULES...]"
    echo ""
    echo "Options:"
    echo "  --list, -l       List available modules"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                    # Run all modules"
    echo "  $(basename "$0") config auth       # Run specific modules"
}

# List modules
list_modules() {
    echo "Available modules:"
    echo ""
    for module in "${MODULE_ORDER[@]}"; do
        printf "  %-12s %s\n" "$module" "${MODULES[$module]}"
    done
}

# Run a single module
run_module() {
    local module="$1"
    local script

    case "$module" in
        config)
            script="$SCRIPT_DIR/setup-git-config.sh"
            ;;
        auth)
            script="$SCRIPT_DIR/setup-gh-auth.sh"
            ;;
        secrets)
            script="$SCRIPT_DIR/setup-secrets.sh"
            ;;
        dotfiles)
            script="$SCRIPT_DIR/setup-dotfiles.sh"
            ;;
        plugins)
            script="$SCRIPT_DIR/setup-hyprland-plugins.sh"
            ;;
        monitors)
            script="$SCRIPT_DIR/setup-monitors.sh"
            ;;
        *)
            print_error "Unknown module: $module"
            return 1
            ;;
    esac

    if [ ! -f "$script" ]; then
        print_warning "Script not found: $script"
        STATUS[$module]="skipped (script not found)"
        return 1
    fi

    chmod +x "$script"

    print_status "Running module: $module"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local result
    if result=$("$script" 2>&1 | tee /dev/stderr | tail -1); then
        STATUS[$module]="$result"
    else
        STATUS[$module]="failed"
    fi

    echo ""
}

# Print summary
print_summary() {
    echo ""
    print_success "Git setup complete!"
    echo ""
    print_status "Summary:"
    for module in "${MODULE_ORDER[@]}"; do
        if [ -n "${STATUS[$module]}" ]; then
            echo "  • $module: ${STATUS[$module]}"
        fi
    done
}

# Parse arguments
MODULES_TO_RUN=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --list|-l)
            list_modules
            exit 0
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # Validate module name
            if [ -z "${MODULES[$1]}" ]; then
                print_error "Unknown module: $1"
                echo "Use --list to see available modules"
                exit 1
            fi
            MODULES_TO_RUN+=("$1")
            shift
            ;;
    esac
done

# If no modules specified, run all
if [ ${#MODULES_TO_RUN[@]} -eq 0 ]; then
    MODULES_TO_RUN=("${MODULE_ORDER[@]}")
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║      Git/GitHub Setup Script           ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Run requested modules
for module in "${MODULES_TO_RUN[@]}"; do
    run_module "$module"
done

print_summary
