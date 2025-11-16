#!/bin/bash
DOTFILES_DIR="$HOME/dotfiles"
HOME_DIR="$HOME"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 {add|remove|list} [path]"
    echo ""
    echo "Commands:"
    echo "  add <path>       Add a file/folder to tracking (creates symlink)"
    echo "  remove <path>    Remove from tracking (restores backup)"
    echo "  list            List currently tracked items"
    echo ""
    echo "Path can be:"
    echo "  - Relative to home: Scripts, .bashrc, Documents/notes"
    echo "  - Or .config items: .config/waybar (or just waybar)"
    echo ""
    echo "Examples:"
    echo "  $0 add Scripts"
    echo "  $0 add .bashrc"
    echo "  $0 add waybar              # Assumes .config/waybar"
    echo "  $0 add .config/fish"
    echo "  $0 add Documents/notes"
    echo "  $0 remove Scripts"
    echo "  $0 list"
    exit 1
}

# Normalize path: convert bare config names to .config/name
normalize_path() {
    local input_path="$1"

    # If path doesn't contain / and doesn't start with ., assume it's a .config item
    if [[ ! "$input_path" =~ / ]] && [[ ! "$input_path" =~ ^\. ]]; then
        echo ".config/$input_path"
    else
        echo "$input_path"
    fi
}

# Convert path to repo structure
path_to_repo() {
    local normalized_path="$1"

    # Remove leading ./ if present
    normalized_path="${normalized_path#./}"

    # .config items go in config/ directory (without the leading dot)
    if [[ "$normalized_path" =~ ^\.config/ ]]; then
        echo "config/${normalized_path#.config/}"
    else
        # Everything else goes in home/ directory
        echo "home/$normalized_path"
    fi
}

list_tracked() {
    echo -e "${GREEN}Currently tracked items:${NC}"
    echo ""

    # List .config items
    if [ -d "$DOTFILES_DIR/config" ]; then
        echo -e "${YELLOW}.config items:${NC}"
        find "$DOTFILES_DIR/config" -maxdepth 1 -mindepth 1 -printf "  .config/%f\n" | sort
    fi

    # List other home items
    if [ -d "$DOTFILES_DIR/home" ]; then
        echo ""
        echo -e "${YELLOW}Other items:${NC}"
        find "$DOTFILES_DIR/home" -maxdepth 2 -mindepth 1 -printf "  %P\n" | sort
    fi

    if [ ! -d "$DOTFILES_DIR/config" ] && [ ! -d "$DOTFILES_DIR/home" ]; then
        echo "No items tracked yet"
    fi
}

add_item() {
    local input_path="$1"

    if [ -z "$input_path" ]; then
        echo -e "${RED}Error: Path required${NC}"
        usage
    fi

    # Normalize the path
    local normalized_path=$(normalize_path "$input_path")
    local source_path="$HOME_DIR/$normalized_path"
    local repo_path="$DOTFILES_DIR/$(path_to_repo "$normalized_path")"

    # Check if source exists
    if [ ! -e "$source_path" ]; then
        echo -e "${RED}Error: $source_path does not exist${NC}"
        exit 1
    fi

    # Check if already a symlink
    if [ -L "$source_path" ]; then
        echo -e "${YELLOW}Warning: $normalized_path is already a symlink${NC}"
        exit 1
    fi

    echo -e "${GREEN}Adding $normalized_path to dotfiles...${NC}"

    # Create parent directory in repo
    mkdir -p "$(dirname "$repo_path")"

    # Copy to repo
    echo "Copying to repo..."
    cp -r "$source_path" "$repo_path"

    # Backup original
    echo "Creating backup..."
    mv "$source_path" "$source_path.backup"

    # Create symlink
    echo "Creating symlink..."
    ln -sf "$repo_path" "$source_path"

    # Git operations
    cd "$DOTFILES_DIR"
    git add "$(path_to_repo "$normalized_path")"
    git commit -m "Add $normalized_path"

    echo -e "${GREEN}✓ Successfully added $normalized_path${NC}"
    echo "  Source: $source_path"
    echo "  Repo:   $repo_path"
    echo ""
    echo "To push to GitHub, run:"
    echo "  cd $DOTFILES_DIR && git push"
}

remove_item() {
    local input_path="$1"

    if [ -z "$input_path" ]; then
        echo -e "${RED}Error: Path required${NC}"
        usage
    fi

    # Normalize the path
    local normalized_path=$(normalize_path "$input_path")
    local source_path="$HOME_DIR/$normalized_path"
    local repo_path="$DOTFILES_DIR/$(path_to_repo "$normalized_path")"

    # Check if it's a symlink
    if [ ! -L "$source_path" ]; then
        echo -e "${RED}Error: $normalized_path is not a symlink (not tracked)${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Removing $normalized_path from dotfiles...${NC}"

    # Remove symlink
    echo "Removing symlink..."
    rm "$source_path"

    # Restore from backup if it exists
    if [ -e "$source_path.backup" ]; then
        echo "Restoring from backup..."
        mv "$source_path.backup" "$source_path"
    else
        # Copy from repo
        echo "Copying from repo..."
        cp -r "$repo_path" "$source_path"
    fi

    # Git operations
    cd "$DOTFILES_DIR"
    git rm -r "$(path_to_repo "$normalized_path")"
    git commit -m "Remove $normalized_path from tracking"

    echo -e "${GREEN}✓ Successfully removed $normalized_path${NC}"
    echo ""
    echo "To push to GitHub, run:"
    echo "  cd $DOTFILES_DIR && git push"
}

# Main script logic
case "$1" in
    add)
        add_item "$2"
        ;;
    remove)
        remove_item "$2"
        ;;
    list)
        list_tracked
        ;;
    *)
        usage
        ;;
esac
