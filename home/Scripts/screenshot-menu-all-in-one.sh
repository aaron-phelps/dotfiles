#!/bin/bash

# Directories
screenshot_dir="$HOME/Pictures/Screenshots"
recording_dir="$HOME/Videos/Recordings"
mkdir -p "$screenshot_dir" "$recording_dir"

# Timestamps
timestamp=$(date +%Y%m%d_%H%M%S)

# Rofi theme matching your aesthetic
rofi_theme="
* {
    font: \"Google Sans Code 13\";
    background-color: rgba(20, 20, 20, 0.7);
    text-color: #ffffff;
    border-color: #666666;
    border-radius: 12px;
}

window {
    width: 400px;
    border: 2px solid;
    border-radius: 12px;
    padding: 10px;
}

listview {
    lines: 8;
    scrollbar: false;
}

element {
    padding: 8px;
    border-radius: 10px;
}

element selected {
    background-color: rgba(80, 80, 80, 0.5);
}

element-text {
    background-color: inherit;
    text-color: inherit;
}
"

# All options
options="󰹑 Screenshot - Fullscreen
󰩭 Screenshot - Area
󰖯 Screenshot - Window
󰃠 Record - Fullscreen
󰕧 Record - Fullscreen + Audio
󰃬 Record - Area
󰃨 Stop Recording"

# Show rofi menu
choice=$(echo -e "$options" | rofi -dmenu -p "Screen Capture" -theme-str "$rofi_theme" -i)

case "$choice" in
    "󰹑 Screenshot - Fullscreen")
        file="$screenshot_dir/screenshot_$timestamp.png"
        grim "$file"
        notify-send "Screenshot Saved" "$file" -i "$file"
        ;;
    "󰩭 Screenshot - Area")
        file="$screenshot_dir/screenshot_$timestamp.png"
        grim -g "$(slurp)" "$file"
        notify-send "Screenshot Saved" "$file" -i "$file"
        ;;
    "󰖯 Screenshot - Window")
        file="$screenshot_dir/screenshot_$timestamp.png"
        active_window=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$active_window" "$file"
        notify-send "Screenshot Saved" "$file" -i "$file"
        ;;
    "󰃠 Record - Fullscreen")
        if pgrep -x "wf-recorder" > /dev/null; then
            notify-send "Recording Error" "Already recording!"
        else
            file="$recording_dir/recording_$timestamp.mp4"
            wf-recorder -f "$file" &
            notify-send "Recording Started" "Fullscreen - $file"
        fi
        ;;
    "󰕧 Record - Fullscreen + Audio")
        if pgrep -x "wf-recorder" > /dev/null; then
            notify-send "Recording Error" "Already recording!"
        else
            file="$recording_dir/recording_$timestamp.mp4"
            wf-recorder -a -f "$file" &
            notify-send "Recording Started" "Fullscreen with Audio - $file"
        fi
        ;;
    "󰃬 Record - Area")
        if pgrep -x "wf-recorder" > /dev/null; then
            notify-send "Recording Error" "Already recording!"
        else
            geometry=$(slurp)
            if [ -n "$geometry" ]; then
                file="$recording_dir/recording_$timestamp.mp4"
                wf-recorder -g "$geometry" -f "$file" &
                notify-send "Recording Started" "Area - $file"
            fi
        fi
        ;;
    "󰃨 Stop Recording")
        pkill -SIGINT wf-recorder
        notify-send "Recording Stopped" "Saved to $recording_dir"
        ;;
esac
