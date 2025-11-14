#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Initialize swww if not running
if ! pgrep -x swww-daemon > /dev/null; then
    swww-daemon &
    sleep 0.5
fi

# Get random wallpaper (including GIFs and videos)
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( \
    -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \
    -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" \
    \) | shuf -n 1)

if [ -n "$WALLPAPER" ]; then
    # Check if it's a video file
    if [[ "$WALLPAPER" =~ \.(mp4|webm|mkv|avi)$ ]]; then
        # Kill existing mpvpaper instances
        pkill mpvpaper
        # Use mpvpaper for videos
        mpvpaper -o "no-audio loop" '*' "$WALLPAPER" &
    else
        # Kill mpvpaper if running (switching from video to static)
        pkill mpvpaper
        # Use swww for images/GIFs
        swww img "$WALLPAPER" --transition-type fade --transition-duration 1
    fi
fi
