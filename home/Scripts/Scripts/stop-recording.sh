#!/bin/bash

if pgrep -x wf-recorder > /dev/null || pgrep -x ffmpeg > /dev/null; then
    pkill -SIGINT wf-recorder
    pkill -SIGINT ffmpeg
    
    # Cleanup combined audio sink if it exists
    if [ -f /tmp/wf-recorder-combined ]; then
        combined_id=$(cat /tmp/wf-recorder-combined)
        pactl unload-module "$combined_id"
        rm /tmp/wf-recorder-combined
    fi
    
    sleep 0.5
    latest_video=$(ls -t ~/Videos/Recordings/*.{mp4,mp3} 2>/dev/null | head -1)
    
    if [ -n "$latest_video" ]; then
        # Show notification with click to open folder
        dunstify -a "Recording" "Recording saved" "Click to open in Thunar" \
            -A "open,Open Folder" | while read action; do
                [ "$action" = "open" ] && thunar ~/Videos/Recordings &
            done &
        
        # Show rofi menu for copy/delete options
        action=$(echo -e "Copy File\nDelete" | rofi -dmenu -i -p "Recording saved" -theme ~/.config/rofi/capture-theme.rasi)
        
        case $action in
            "Copy File")
                # Kill any existing wl-copy to clear clipboard
                pkill wl-copy
                # Copy as file URI and keep wl-copy running in background
                printf "file://%s\n" "$latest_video" | wl-copy --type text/uri-list &
                dunstify -a "Recording-Action" "Copied" "Recording copied to clipboard"
                ;;
            "Delete")
                rm "$latest_video"
                dunstify "Deleted" "Recording removed"
                ;;
        esac
    fi
else
    dunstify "No Recording" "No active recording found"
fi
