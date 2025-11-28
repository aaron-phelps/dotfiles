#!/bin/bash
DOTFILES_DIR="$HOME/dotfiles"
HOME_DIR="$HOME"
EXCLUDE_FILE="$DOTFILES_DIR/dotfile_exclude.txt"

# Colors for output
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

usage() {
    echo "Usage: $0 {add|remove|list|sync} [path]"
    echo ""
    echo "Commands:"
    echo "  add <path>       Add a file/folder to tracking (creates symlink)"
    echo "  remove <path>    Remove from tracking (restores backup)"
    echo "  list             List currently tracked items"
    echo "  sync             Sync all changes and optionally push to GitHub"
    echo ""
    echo "Path can be:"
    echo "  - Relative to home: Scripts, .bashrc, Documents/notes"
    echo "  - .config items: .config/waybar (or just waybar)"
    echo "  - System files: /etc/sddm.conf (requires sudo)"
    echo ""
    echo "Examples:"
    echo "  $0 add Scripts"
    echo "  $0 add .bashrc"
    echo "  $0 add waybar              # Assumes .config/waybar"
    echo "  $0 add .config/fish"
    echo "  $0 add Documents/notes"
    echo "  $0 add /etc/sddm.conf      # System file (requires sudo)"
    echo "  $0 remove Scripts"
    echo "  $0 list"
    echo "  $0 sync"
    echo ""
    echo "Exclusions defined in: ~/dotfiles/dotfile_exclude.txt"
    exit 1
}

# Check if path is a system path (starts with /)
is_system_path() {
    local path="$1"
    [[ "$path" =~ ^/ ]]
}

# Check if path matches an excluded pattern
is_excluded() {
    local check_path="$1"

    # Return false if exclude file doesn't exist
    if [ ! -f "$EXCLUDE_FILE" ]; then
        return 1
    fi

    # Read patterns from file (skip comments and blank lines)
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        # Skip comments and blank lines
        [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue

        # Use bash pattern matching
        if [[ "$check_path" == $pattern ]]; then
            return 0
        fi
    done < "$EXCLUDE_FILE"

    return 1
}

# Normalize path: handle various input formats
# System paths (starting with /) are returned as-is
# Paths starting with ~/ are converted to relative home paths
# Paths starting with .config/ or bare names like "waybar" become .config items
normalize_path() {
    local input_path="$1"

    # System paths stay as-is
    if is_system_path "$input_path"; then
        echo "$input_path"
        return
    fi

    # Strip ~/ prefix if present (home-relative path)
    if [[ "$input_path" =~ ^~/ ]]; then
        input_path="${input_path#~/}"
        echo "$input_path"
        return
    fi

    # Strip ./ prefix if present
    if [[ "$input_path" =~ ^\.\/ ]]; then
        input_path="${input_path#./}"
        echo "$input_path"
        return
    fi

    # If it starts with . (like .bashrc, .config, .local), it's home-relative
    if [[ "$input_path" =~ ^\. ]]; then
        echo "$input_path"
        return
    fi

    # If it contains a / (like Documents/notes), it's home-relative
    if [[ "$input_path" =~ / ]]; then
        echo "$input_path"
        return
    fi

    # Bare name without / - check if it exists in home first, otherwise assume .config
    if [ -e "$HOME/$input_path" ]; then
        echo "$input_path"
    else
        echo ".config/$input_path"
    fi
}

# Convert path to repo structure
path_to_repo() {
    local normalized_path="$1"

    # Remove leading ./ if present
    normalized_path="${normalized_path#./}"

    # System paths go in system/ directory (preserve full path structure)
    if is_system_path "$normalized_path"; then
        echo "system${normalized_path}"
    # .config items go in config/ directory (without the leading dot)
    elif [[ "$normalized_path" =~ ^\.config/ ]]; then
        echo "config/${normalized_path#.config/}"
    else
        # Everything else goes in home/ directory
        echo "home/$normalized_path"
    fi
}

# Get the actual source path (handles both home and system paths)
get_source_path() {
    local normalized_path="$1"

    if is_system_path "$normalized_path"; then
        echo "$normalized_path"
    else
        echo "$HOME_DIR/$normalized_path"
    fi
}

# Auto-push changes to GitHub
auto_push() {
    cd "$DOTFILES_DIR"

    # Stage any unstaged changes
    git add -A

    # Check if there are changes to commit
    if ! git diff --cached --quiet; then
        git commit -m "Update dotfiles" || true
    fi

    # Push if there are commits ahead of remote
    if git status | grep -q "Your branch is ahead"; then
        echo -e "${GREEN}Pushing to GitHub...${NC}"
        git push
        echo -e "${GREEN}✓ Pushed to GitHub${NC}"
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
        echo -e "${YELLOW}Other home items:${NC}"
        find "$DOTFILES_DIR/home" -maxdepth 2 -mindepth 1 -printf "  %P\n" | sort
    fi

    # List system items
    if [ -d "$DOTFILES_DIR/system" ]; then
        echo ""
        echo -e "${YELLOW}System items:${NC}"
        find "$DOTFILES_DIR/system" -type f -printf "  /%P\n" | sort
    fi

    if [ ! -d "$DOTFILES_DIR/config" ] && [ ! -d "$DOTFILES_DIR/home" ] && [ ! -d "$DOTFILES_DIR/system" ]; then
        echo "No items tracked yet"
    fi

    echo ""
    echo -e "${YELLOW}Excluded patterns (from dotfile_exclude.txt):${NC}"
    if [ -f "$EXCLUDE_FILE" ]; then
        grep -v '^#' "$EXCLUDE_FILE" | grep -v '^$' | while read -r pattern; do
            echo "  - $pattern"
        done
    else
        echo "  (no exclude file found)"
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
    local is_system=$(is_system_path "$normalized_path" && echo "yes" || echo "no")

    # Check if excluded
    if is_excluded "$normalized_path"; then
        echo -e "${YELLOW}⚠ Skipping $normalized_path (excluded pattern)${NC}"
        return 0
    fi

    local source_path=$(get_source_path "$normalized_path")
    local repo_path="$DOTFILES_DIR/$(path_to_repo "$normalized_path")"

    # For system files, we need sudo
    local SUDO=""
    if [ "$is_system" = "yes" ]; then
        SUDO="sudo"
        echo -e "${YELLOW}System file detected - sudo may be required${NC}"
    fi

    # Check if already a symlink pointing to the right place
    if [ -L "$source_path" ]; then
        local link_target=$(readlink -f "$source_path")
        if [ "$link_target" = "$repo_path" ]; then
            echo -e "${GREEN}✓ $normalized_path is already correctly linked${NC}"
            return 0
        else
            echo -e "${YELLOW}Warning: $normalized_path is a symlink to a different location${NC}"
            echo "  Current: $link_target"
            echo "  Expected: $repo_path"
            return 1
        fi
    fi

    # Check if already exists in repo (reconnect scenario)
    if [ -e "$repo_path" ]; then
        echo -e "${YELLOW}$normalized_path already exists in repo, reconnecting...${NC}"

        # If source exists and is not a symlink, back it up
        if [ -e "$source_path" ]; then
            echo "Creating backup of existing file/folder..."
            $SUDO mv "$source_path" "$source_path.backup"
        fi

        # Create symlink
        echo "Creating symlink..."
        $SUDO ln -sf "$repo_path" "$source_path"

        echo -e "${GREEN}✓ Successfully reconnected $normalized_path${NC}"
        echo "  Source: $source_path"
        echo "  Repo:   $repo_path"
        return 0
    fi

    # New item - check if source exists
    if [ ! -e "$source_path" ]; then
        echo -e "${RED}Error: $source_path does not exist${NC}"
        return 1
    fi

    echo -e "${GREEN}Adding $normalized_path to dotfiles...${NC}"

    # Create parent directory in repo
    mkdir -p "$(dirname "$repo_path")"

    # Copy to repo
    echo "Copying to repo..."
    if [ -d "$source_path" ]; then
        # Directory copy with exclusion support
        if [ -f "$EXCLUDE_FILE" ]; then
            # Build rsync exclude patterns relative to the source being copied
            local rsync_excludes=()
            while IFS= read -r pattern || [ -n "$pattern" ]; do
                [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
                # Check if pattern starts with the normalized path we're copying
                if [[ "$pattern" == "$normalized_path"/* ]]; then
                    # Strip the prefix to make it relative to source_path
                    local relative_pattern="${pattern#$normalized_path/}"
                    rsync_excludes+=("--exclude=$relative_pattern")
                fi
            done < "$EXCLUDE_FILE"
            rsync -a "${rsync_excludes[@]}" "$source_path/" "$repo_path/"
        else
            cp -rT "$source_path" "$repo_path"
        fi
    else
        # File copy (use sudo for system files to read)
        $SUDO cp "$source_path" "$repo_path"
        # Fix ownership in repo (should be user-owned)
        if [ "$is_system" = "yes" ]; then
            sudo chown "$USER:$USER" "$repo_path"
        fi
    fi

    # Backup original
    echo "Creating backup..."
    $SUDO mv "$source_path" "$source_path.backup"

    # Create symlink
    echo "Creating symlink..."
    $SUDO ln -sf "$repo_path" "$source_path"

    # Git operations
    git -C "$DOTFILES_DIR" add "$(path_to_repo "$normalized_path")"
    git -C "$DOTFILES_DIR" commit -m "Add $normalized_path" || true

    echo -e "${GREEN}✓ Successfully added $normalized_path${NC}"
    echo "  Source: $source_path"
    echo "  Repo:   $repo_path"

    return 0
}

remove_item() {
    local input_path="$1"

    if [ -z "$input_path" ]; then
        echo -e "${RED}Error: Path required${NC}"
        usage
    fi

    # Normalize the path
    local normalized_path=$(normalize_path "$input_path")
    local is_system=$(is_system_path "$normalized_path" && echo "yes" || echo "no")
    local source_path=$(get_source_path "$normalized_path")
    local repo_path="$DOTFILES_DIR/$(path_to_repo "$normalized_path")"

    # For system files, we need sudo
    local SUDO=""
    if [ "$is_system" = "yes" ]; then
        SUDO="sudo"
        echo -e "${YELLOW}System file detected - sudo may be required${NC}"
    fi

    # Check if it's a symlink
    if [ ! -L "$source_path" ]; then
        echo -e "${RED}Error: $normalized_path is not a symlink (not tracked)${NC}"
        return 1
    fi

    echo -e "${YELLOW}Removing $normalized_path from dotfiles...${NC}"

    # Remove symlink
    echo "Removing symlink..."
    $SUDO rm "$source_path"

    # Restore from backup if it exists
    if [ -e "$source_path.backup" ]; then
        echo "Restoring from backup..."
        $SUDO mv "$source_path.backup" "$source_path"
    else
        # Copy from repo
        echo "Copying from repo..."
        $SUDO cp -r "$repo_path" "$source_path"
    fi

    # Git operations
    git -C "$DOTFILES_DIR" rm -r "$(path_to_repo "$normalized_path")"
    git -C "$DOTFILES_DIR" commit -m "Remove $normalized_path from tracking" || true

    echo -e "${GREEN}✓ Successfully removed $normalized_path${NC}"

    return 0
}

# Sync all changes in tracked directories to git
sync_changes() {
    echo -e "${GREEN}Syncing all changes to git...${NC}"

    cd "$DOTFILES_DIR"

    # Stage all changes
    git add -A

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        echo -e "${YELLOW}No changes to commit${NC}"
    else
        echo -e "${YELLOW}Uncommitted changes:${NC}"
        git status --short
        echo ""
        read -p "Commit these changes? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Commit message (or enter for default): " msg
            msg="${msg:-Update dotfiles}"
            git commit -m "$msg"

            read -p "Push to GitHub? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git push
                echo -e "${GREEN}✓ Pushed to GitHub${NC}"
            fi
        fi
    fi
}

# Main script logic
case "$1" in
    add)
        add_item "$2"
        auto_push
        ;;
    remove)
        remove_item "$2"
        auto_push
        ;;
    list)
        list_tracked
        ;;
    sync)
        sync_changes
        ;;
    *)
        usage
        ;;
esac
