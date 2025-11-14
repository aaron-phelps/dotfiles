#!/usr/bin/env bash
set -e

HYPRCONF="$HOME/.config/hypr/hyprland.conf"
BACKUP="$HOME/.config/hypr/hyprland.conf.bak"

# 1️⃣ Restore backup
read -rp "Do you want to restore hyprland.conf from backup? (y/n): " RESTORE
if [[ "$RESTORE" =~ ^[Yy]$ ]]; then
    if [[ -f "$BACKUP" ]]; then
        cp "$BACKUP" "$HYPRCONF"
        echo "Backup restored. Exiting."
        exit 0
    else
        echo "No backup found. Exiting."
        exit 1
    fi
fi

# 2️⃣ Require jq
if ! command -v jq &>/dev/null; then
    echo "jq is required. Install it first."
    exit 1
fi

# 3️⃣ Detect monitors
MONITOR_JSON=$(hyprctl monitors -j)
MONITORS=($(echo "$MONITOR_JSON" | jq -r '.[].name'))
if [[ ${#MONITORS[@]} -eq 0 ]]; then
    echo "❌ No monitors detected."
    exit 1
fi

declare -A MONS_INFO
for MON in "${MONITORS[@]}"; do
    WIDTH=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .width")
    HEIGHT=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .height")
    REFRESH=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .refresh")
    [[ -z "$REFRESH" || "$REFRESH" == "null" ]] && REFRESH=60 || REFRESH=$(printf "%.0f" "$REFRESH")
    MONS_INFO["$MON"]="$WIDTH $HEIGHT $REFRESH"
done

# 4️⃣ Primary monitor
echo -e "\nDetected monitors:"
for MON in "${MONITORS[@]}"; do
    INFO=(${MONS_INFO[$MON]})
    echo "  $MON ${INFO[0]}x${INFO[1]}@${INFO[2]}"
done

read -rp $'\nEnter the primary monitor: ' PRIMARY_MON
while [[ ! " ${MONITORS[*]} " =~ " ${PRIMARY_MON} " ]]; do
    echo "Invalid monitor name. Please enter one of: ${MONITORS[*]}"
    read -rp "Primary monitor: " PRIMARY_MON
done

# 5️⃣ Relative positions
declare -A MON_X MON_Y REL_POSITIONS
REL_POSITIONS["$PRIMARY_MON"]="primary"
MON_X["$PRIMARY_MON"]=0
MON_Y["$PRIMARY_MON"]=0

for MON in "${MONITORS[@]}"; do
    [[ "$MON" == "$PRIMARY_MON" ]] && continue

    echo -e "\nWhere is $MON positioned relative to $PRIMARY_MON?"
    echo "Options: top-left, top-center, top-right, bottom-left, bottom-center, bottom-right, left-center, right-center"
    read -rp "Position: " POS
    while [[ ! "$POS" =~ ^(top-left|top-center|top-right|bottom-left|bottom-center|bottom-right|left-center|right-center)$ ]]; do
        echo "Invalid input. Please enter one of the valid options."
        read -rp "Position: " POS
    done
    REL_POSITIONS["$MON"]="$POS"

    P_INFO=(${MONS_INFO[$PRIMARY_MON]})
    M_INFO=(${MONS_INFO[$MON]})
    PW=${P_INFO[0]}; PH=${P_INFO[1]}
    MW=${M_INFO[0]}; MH=${M_INFO[1]}

    case "$POS" in
        top-left)       MON_X["$MON"]=0;               MON_Y["$MON"]=$(( -MH )) ;;
        top-center)     MON_X["$MON"]=$(( (PW - MW)/2 )); MON_Y["$MON"]=$(( -MH )) ;;
        top-right)      MON_X["$MON"]=$(( PW - MW )); MON_Y["$MON"]=$(( -MH )) ;;
        bottom-left)    MON_X["$MON"]=0;               MON_Y["$MON"]=$PH ;;
        bottom-center)  MON_X["$MON"]=$(( (PW - MW)/2 )); MON_Y["$MON"]=$PH ;;
        bottom-right)   MON_X["$MON"]=$(( PW - MW )); MON_Y["$MON"]=$PH ;;
        left-center)    MON_X["$MON"]=$(( -MW ));     MON_Y["$MON"]=$(( (PH - MH)/2 )) ;;
        right-center)   MON_X["$MON"]=$PW;            MON_Y["$MON"]=$(( (PH - MH)/2 )) ;;
    esac
done

# 6️⃣ Show simplified ASCII map
echo -e "\nASCII preview (simplified, relative positions):"

GRID_WIDTH=9
GRID_HEIGHT=5
declare -A GRID

# Fill grid with spaces
for ((y=0;y<GRID_HEIGHT;y++)); do
    for ((x=0;x<GRID_WIDTH;x++)); do
        GRID[$x,$y]="   "
    done
done

# Map positions to coordinates
get_coords() {
    local pos=$1
    case "$pos" in
        primary)       echo "$((GRID_WIDTH/2)) $((GRID_HEIGHT/2))" ;;
        top-left)      echo "1 0" ;;
        top-center)    echo "$((GRID_WIDTH/2)) 0" ;;
        top-right)     echo "$((GRID_WIDTH-2)) 0" ;;
        bottom-left)   echo "1 $((GRID_HEIGHT-1))" ;;
        bottom-center) echo "$((GRID_WIDTH/2)) $((GRID_HEIGHT-1))" ;;
        bottom-right)  echo "$((GRID_WIDTH-2)) $((GRID_HEIGHT-1))" ;;
        left-center)   echo "0 $((GRID_HEIGHT/2))" ;;
        right-center)  echo "$((GRID_WIDTH-1)) $((GRID_HEIGHT/2))" ;;
    esac
}

# Place monitors on grid
for MON in "${MONITORS[@]}"; do
    POS=${REL_POSITIONS[$MON]}
    [[ "$MON" == "$PRIMARY_MON" ]] && POS="primary"
    read X Y <<< $(get_coords "$POS")
    CHAR="[█]"; [[ "$MON" != "$PRIMARY_MON" ]] && CHAR="[▒]"
    GRID[$X,$Y]="$CHAR$MON"
done

# Print grid
for ((y=0;y<GRID_HEIGHT;y++)); do
    LINE=""
    for ((x=0;x<GRID_WIDTH;x++)); do
        LINE+="${GRID[$x,$y]}"
        [[ -z "${GRID[$x,$y]}" ]] && LINE+="   "
    done
    echo "$LINE"
done

# 7️⃣ Update config
read -rp $'\nDo you want to update hyprland.conf monitor section? (y/n): ' UPDATE
if ! [[ "$UPDATE" =~ ^[Yy]$ ]]; then
    echo "No changes made. Exiting."
    exit 0
fi

cp "$HYPRCONF" "$BACKUP"
echo "🔄 Backed up current config to $BACKUP"

MONITOR_SECTION=""
for MON in "${MONITORS[@]}"; do
    INFO=(${MONS_INFO[$MON]})
    WIDTH=${INFO[0]}; HEIGHT=${INFO[1]}; REFRESH=${INFO[2]}
    X=${MON_X[$MON]}; Y=${MON_Y[$MON]}
    MONITOR_SECTION+="monitor=$MON,${WIDTH}x${HEIGHT}@${REFRESH},${X}x${Y},1"$'\n'
done

sed -i '/^monitor=/d' "$HYPRCONF"
echo -e "\n$MONITOR_SECTION" >> "$HYPRCONF"
echo "✅ Monitor section updated."

hyprctl reload
echo "🔁 Hyprland reloaded."
