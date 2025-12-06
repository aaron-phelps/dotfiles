#!/bin/bash

# Arch Linux System Setup - Main Orchestrator
# Runs all setup modules in order, or specific modules as requested
#
# Usage:
#   ./setup-all.sh              # Run all modules
#   ./setup-all.sh --list       # List available modules
#   ./setup-all.sh yay packages # Run specific modules

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-common.sh"

check_not_root

# Define modules in order
declare -A MODULES=(
    [scripts-permissions]="Fix Scripts directory permissions"
    [bluetooth]="Enable Bluetooth service"
    [yay]="Install yay AUR helper"
    [multilib]="Enable multilib repository"
    [packages]="Sync official packages"
    [aur]="Sync AUR packages"
    [sddm]="Configure SDDM display manager"
    [directories]="Create standard directories"
    [wallpapers]="Deploy wallpapers"
    [dotfiles]="Create dotfile symlinks (configs, home items, system files)"
    [git]="Configure Git, GitHub auth, and plugins"
    [monitors]="Configure Hyprland monitors"
)

# Order of execution
MODULE_ORDER=(
    scripts-permissions
    bluetooth
    yay
    multilib
    packages
    aur
    sddm
    directories
    wallpapers
    dotfiles
    git
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
    echo "  --skip-removal   Pass to packages/aur modules to skip removal"
    echo "  --auto-remove    Pass to packages/aur modules to auto-remove"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                    # Run all modules"
    echo "  $(basename "$0") yay packages aur  # Run specific modules"
    echo "  $(basename "$0") packages --skip-removal"
}

# List modules
list_modules() {
    echo "Available modules:"
    echo ""
    for module in "${MODULE_ORDER[@]}"; do
        printf "  %-20s %s\n" "$module" "${MODULES[$module]}"
    done
}

# Run a single module
run_module() {
    local module="$1"
    shift
    local extra_args=("$@")
    local script="$SCRIPT_DIR/setup-${module}.sh"

    # Special cases for external scripts (in parent Scripts directory)
    case "$module" in
        monitors)
            script="$SCRIPTS_ROOT/update-hyprland-monitors.sh"
            ;;
    esac

    if [ ! -f "$script" ]; then
        print_warning "Script not found: $script"
        STATUS[$module]="skipped (script not found)"
        return 1
    fi

    sudo chattr -i "$script" 2>/dev/null || true
    sudo chmod +x "$script"

    # Check display requirements
    if [[ "$module" == "git" || "$module" == "monitors" ]]; then
        if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
            print_warning "No display available for $module"
            STATUS[$module]="pending (no display)"
            return 0
        fi
    fi

    print_status "Running module: $module"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if "$script" "${extra_args[@]}"; then
        STATUS[$module]="completed"
    else
        STATUS[$module]="failed"
    fi

    echo ""
}

# Print summary
print_summary() {
    echo ""
    print_success "Setup complete!"
    echo ""
    print_status "Summary:"
    for module in "${MODULE_ORDER[@]}"; do
        if [ -n "${STATUS[$module]}" ]; then
            echo "  • $module: ${STATUS[$module]}"
        fi
    done
    echo ""
    print_warning "Please reboot your system for all changes to take effect."
}

# Parse arguments
MODULES_TO_RUN=()
EXTRA_ARGS=()

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
        --skip-removal|--auto-remove)
            EXTRA_ARGS+=("$1")
            shift
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
echo "║     Arch Linux System Setup Script     ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Remove immutable attributes first (needed before we can chmod scripts)
sudo chattr -R -i "$SCRIPTS_DIR" 2>/dev/null || true
sudo chattr -R -i "$SCRIPTS_ROOT" 2>/dev/null || true

# Run requested modules
for module in "${MODULES_TO_RUN[@]}"; do
    run_module "$module" "${EXTRA_ARGS[@]}"
done

# Final cleanup if running full setup
if [ ${#MODULES_TO_RUN[@]} -eq ${#MODULE_ORDER[@]} ]; then
    print_status "Performing final cleanup..."
    sudo pacman -Sc --noconfirm 2>/dev/null || true
    if command_exists yay; then
        yay -Sc --noconfirm 2>/dev/null || true
    fi
fi

print_summary
