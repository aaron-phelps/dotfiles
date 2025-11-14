#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 {add|remove|list} [config_name]"
    echo ""
    echo "Commands:"
    echo "  add <config>     Add a config to tracking (creates symlink)"
    echo "  remove <config>  Remove a config from tracking (restores backup)"
    echo "  list            List currently tracked configs"
    echo ""
    echo "Examples:"
    echo "  $0 add cava"
    echo "  $0 remove fish"
    echo "  $0 list"
    exit 1
}

list_tracked() {
    echo -e "${GREEN}Currently tracked configs:${NC}"
    echo ""
    
    if [ -d "$DOTFILES_DIR/config" ]; then
        ls -1 "$DOTFILES_DIR/config"
    else
        echo "No configs tracked yet"
    fi
    
    echo ""
    echo -e "${GREEN}Tracked scripts:${NC}"
    if [ -d "$DOTFILES_DIR/Scripts" ]; then
        echo "Scripts directory"
    else
        echo "No Scripts directory"
    fi
}

add_config() {
    local config_name=$1
    
    if [ -z "$config_name" ]; then
        echo -e "${RED}Error: Config name required${NC}"
        usage
    fi
    
    if [ ! -d "$CONFIG_DIR/$config_name" ]; then
        echo -e "${RED}Error: $CONFIG_DIR/$config_name does not exist${NC}"
        exit 1
    fi
    
    if [ -L "$CONFIG_DIR/$config_name" ]; then
        echo -e "${YELLOW}Warning: $config_name is already a symlink${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Adding $config_name to dotfiles...${NC}"
    
    # Create config directory if needed
    mkdir -p "$DOTFILES_DIR/config"
    
    # Copy to repo
    echo "Copying $config_name to repo..."
    cp -r "$CONFIG_DIR/$config_name" "$DOTFILES_DIR/config/$config_name"
    
    # Backup original
    echo "Creating backup..."
    mv "$CONFIG_DIR/$config_name" "$CONFIG_DIR/$config_name.backup"
    
    # Create symlink
    echo "Creating symlink..."
    ln -sf "$DOTFILES_DIR/config/$config_name" "$CONFIG_DIR/$config_name"
    
    # Git operations
    cd "$DOTFILES_DIR"
    git add "config/$config_name"
    git commit -m "Add $config_name config"
    
    echo -e "${GREEN}✓ Successfully added $config_name${NC}"
    echo ""
    echo "To push to GitHub, run:"
    echo "  cd $DOTFILES_DIR && git push"
}

remove_config() {
    local config_name=$1
    
    if [ -z "$config_name" ]; then
        echo -e "${RED}Error: Config name required${NC}"
        usage
    fi
    
    if [ ! -L "$CONFIG_DIR/$config_name" ]; then
        echo -e "${RED}Error: $config_name is not a symlink (not tracked)${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Removing $config_name from dotfiles...${NC}"
    
    # Remove symlink
    echo "Removing symlink..."
    rm "$CONFIG_DIR/$config_name"
    
    # Restore from backup if it exists
    if [ -d "$CONFIG_DIR/$config_name.backup" ]; then
        echo "Restoring from backup..."
        mv "$CONFIG_DIR/$config_name.backup" "$CONFIG_DIR/$config_name"
    else
        # Copy from repo
        echo "Copying from repo..."
        cp -r "$DOTFILES_DIR/config/$config_name" "$CONFIG_DIR/$config_name"
    fi
    
    # Git operations
    cd "$DOTFILES_DIR"
    git rm -r "config/$config_name"
    git commit -m "Remove $config_name from tracking"
    
    echo -e "${GREEN}✓ Successfully removed $config_name${NC}"
    echo ""
    echo "To push to GitHub, run:"
    echo "  cd $DOTFILES_DIR && git push"
}

# Main script logic
case "$1" in
    add)
        add_config "$2"
        ;;
    remove)
        remove_config "$2"
        ;;
    list)
        list_tracked
        ;;
    *)
        usage
        ;;
esac
