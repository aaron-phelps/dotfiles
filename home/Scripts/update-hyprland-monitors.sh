#!/usr/bin/env bash
set -e

HYPRCONF="$HOME/.config/monitor.conf"
BACKUP="$HOME/.config/monitor.conf.bkp"

# 0️⃣ Ensure config directory and file exist
mkdir -p "$(dirname "$HYPRCONF")"
if [[ ! -f "$HYPRCONF" ]]; then
    echo "Creating default monitor.conf..."
    cat > "$HYPRCONF" << 'EOF'
################
### MONITORS ###
################

# See https://wiki.hypr.land/Configuring/Monitors/
monitor=eDP-1,1920x1200@60,0x0,1

EOF
    echo "✅ Created default $HYPRCONF"
fi

# 1️⃣ Restore backup
read -rp "Do you want to restore monitor.conf from backup? (y/n): " RESTORE
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

# 3️⃣ Detect monitors and available modes
MONITOR_JSON=$(hyprctl monitors -j)
MONITORS=($(echo "$MONITOR_JSON" | jq -r '.[].name'))
if [[ ${#MONITORS[@]} -eq 0 ]]; then
    echo "❌ No monitors detected."
    exit 1
fi

declare -A MONS_MODES MONS_SELECTED

# Parse available modes for each monitor
for MON in "${MONITORS[@]}"; do
    # Get available modes as array: "WIDTHxHEIGHT@REFRESH"
    MODES=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .availableModes[]?" 2>/dev/null)

    if [[ -z "$MODES" ]]; then
        # Fallback to current mode if availableModes not present
        WIDTH=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .width")
        HEIGHT=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .height")
        REFRESH=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .refreshRate")
        REFRESH=$(printf "%.2f" "$REFRESH")
        MODES="${WIDTH}x${HEIGHT}@${REFRESH}Hz"
    fi

    MONS_MODES["$MON"]="$MODES"
done

# 4️⃣ Select resolution/refresh for each monitor
select_mode() {
    local MON=$1
    local MODES_RAW="${MONS_MODES[$MON]}"

    # Convert to array and sort by resolution (descending) then refresh (descending)
    mapfile -t MODES_ARR <<< "$MODES_RAW"

    # Sort: extract WxH and refresh, sort numerically
    IFS=$'\n' SORTED_MODES=($(for m in "${MODES_ARR[@]}"; do
        # Parse "1920x1080@60.00Hz" format
        echo "$m"
    done | sort -t'x' -k1 -rn | sort -t'@' -k1,1 -rn -s))
    unset IFS

    # Remove duplicates while preserving order
    declare -A seen
    UNIQUE_MODES=()
    for m in "${SORTED_MODES[@]}"; do
        [[ -z "$m" ]] && continue
        if [[ -z "${seen[$m]}" ]]; then
            seen[$m]=1
            UNIQUE_MODES+=("$m")
        fi
    done

    echo -e "\n📺 Available modes for $MON:"
    echo "   ─────────────────────────────────"

    for i in "${!UNIQUE_MODES[@]}"; do
        MODE="${UNIQUE_MODES[$i]}"
        # Clean up display
        DISPLAY_MODE=$(echo "$MODE" | sed 's/Hz$//')
        printf "   %2d) %s\n" "$((i+1))" "$DISPLAY_MODE"
    done

    echo "   ─────────────────────────────────"

    local MAX=${#UNIQUE_MODES[@]}
    read -rp "   Select mode [1-$MAX] (1 = highest): " MODE_NUM

    while [[ ! "$MODE_NUM" =~ ^[0-9]+$ ]] || ((MODE_NUM < 1 || MODE_NUM > MAX)); do
        echo "   Invalid selection. Enter a number between 1 and $MAX"
        read -rp "   Select mode: " MODE_NUM
    done

    SELECTED="${UNIQUE_MODES[$((MODE_NUM-1))]}"
    # Parse selected mode: "1920x1080@60.00Hz" -> "1920 1080 60"
    SELECTED_CLEAN=$(echo "$SELECTED" | sed 's/Hz$//')
    WIDTH=$(echo "$SELECTED_CLEAN" | cut -d'x' -f1)
    HEIGHT=$(echo "$SELECTED_CLEAN" | cut -d'x' -f2 | cut -d'@' -f1)
    REFRESH=$(echo "$SELECTED_CLEAN" | cut -d'@' -f2)
    REFRESH=$(printf "%.0f" "$REFRESH")

    MONS_SELECTED["$MON"]="$WIDTH $HEIGHT $REFRESH"
    echo "   ✓ Selected: ${WIDTH}x${HEIGHT}@${REFRESH}Hz"
}

echo -e "\n════════════════════════════════════════"
echo "       MONITOR CONFIGURATION WIZARD"
echo "════════════════════════════════════════"

for MON in "${MONITORS[@]}"; do
    select_mode "$MON"
done

# 5️⃣ Primary monitor selection
echo -e "\n════════════════════════════════════════"
echo "         SELECT PRIMARY MONITOR"
echo "════════════════════════════════════════"

for i in "${!MONITORS[@]}"; do
    MON="${MONITORS[$i]}"
    INFO=(${MONS_SELECTED[$MON]})
    printf "   %d) %s (%sx%s@%s)\n" "$((i+1))" "$MON" "${INFO[0]}" "${INFO[1]}" "${INFO[2]}"
done

read -rp $'\n   Select primary monitor [1-'${#MONITORS[@]}']: ' PRIMARY_NUM
while [[ ! "$PRIMARY_NUM" =~ ^[0-9]+$ ]] || ((PRIMARY_NUM < 1 || PRIMARY_NUM > ${#MONITORS[@]})); do
    echo "   Invalid selection. Enter a number between 1 and ${#MONITORS[@]}"
    read -rp "   Select primary monitor: " PRIMARY_NUM
done
PRIMARY_MON="${MONITORS[$((PRIMARY_NUM-1))]}"
echo "   ✓ Primary: $PRIMARY_MON"

# 6️⃣ Relative positions (skip if single monitor)
declare -A MON_X MON_Y REL_POSITIONS
REL_POSITIONS["$PRIMARY_MON"]="primary"
MON_X["$PRIMARY_MON"]=0
MON_Y["$PRIMARY_MON"]=0

if [[ ${#MONITORS[@]} -gt 1 ]]; then
    echo -e "\n════════════════════════════════════════"
    echo "        MONITOR POSITION LAYOUT"
    echo "════════════════════════════════════════"

    POSITIONS=("top-left" "top-center" "top-right" "left-center" "right-center" "bottom-left" "bottom-center" "bottom-right")

    for MON in "${MONITORS[@]}"; do
        [[ "$MON" == "$PRIMARY_MON" ]] && continue

        echo -e "\n   Where is $MON relative to $PRIMARY_MON?"
        echo "   ┌───────────────────────────────┐"
        echo "   │  1) top-left    2) top-center    3) top-right   │"
        echo "   │  4) left-center [PRIMARY] 5) right-center │"
        echo "   │  6) bottom-left 7) bottom-center 8) bottom-right│"
        echo "   └───────────────────────────────┘"

        read -rp "   Select position [1-8]: " POS_NUM
        while [[ ! "$POS_NUM" =~ ^[0-9]+$ ]] || ((POS_NUM < 1 || POS_NUM > 8)); do
            echo "   Invalid selection. Enter a number between 1 and 8"
            read -rp "   Select position: " POS_NUM
        done
        POS="${POSITIONS[$((POS_NUM-1))]}"
        REL_POSITIONS["$MON"]="$POS"
        echo "   ✓ Position: $POS"

        P_INFO=(${MONS_SELECTED[$PRIMARY_MON]})
        M_INFO=(${MONS_SELECTED[$MON]})
        PW=${P_INFO[0]}; PH=${P_INFO[1]}
        MW=${M_INFO[0]}; MH=${M_INFO[1]}

        case "$POS" in
            top-left)       MON_X["$MON"]=0;                  MON_Y["$MON"]=$(( -MH )) ;;
            top-center)     MON_X["$MON"]=$(( (PW - MW)/2 )); MON_Y["$MON"]=$(( -MH )) ;;
            top-right)      MON_X["$MON"]=$(( PW - MW ));     MON_Y["$MON"]=$(( -MH )) ;;
            bottom-left)    MON_X["$MON"]=0;                  MON_Y["$MON"]=$PH ;;
            bottom-center)  MON_X["$MON"]=$(( (PW - MW)/2 )); MON_Y["$MON"]=$PH ;;
            bottom-right)   MON_X["$MON"]=$(( PW - MW ));     MON_Y["$MON"]=$PH ;;
            left-center)    MON_X["$MON"]=$(( -MW ));         MON_Y["$MON"]=$(( (PH - MH)/2 )) ;;
            right-center)   MON_X["$MON"]=$PW;                MON_Y["$MON"]=$(( (PH - MH)/2 )) ;;
        esac
    done
fi

# 7️⃣ Show summary
echo -e "\n════════════════════════════════════════"
echo "            CONFIGURATION SUMMARY"
echo "════════════════════════════════════════"

for MON in "${MONITORS[@]}"; do
    INFO=(${MONS_SELECTED[$MON]})
    X=${MON_X[$MON]}; Y=${MON_Y[$MON]}
    PRIMARY_TAG=""
    [[ "$MON" == "$PRIMARY_MON" ]] && PRIMARY_TAG=" [PRIMARY]"
    echo "   $MON: ${INFO[0]}x${INFO[1]}@${INFO[2]}Hz at ${X}x${Y}$PRIMARY_TAG"
done

# 8️⃣ ASCII preview (only for multi-monitor)
if [[ ${#MONITORS[@]} -gt 1 ]]; then
    echo -e "\n   Layout preview:"

    GRID_WIDTH=9
    GRID_HEIGHT=5
    declare -A GRID

    for ((y=0;y<GRID_HEIGHT;y++)); do
        for ((x=0;x<GRID_WIDTH;x++)); do
            GRID[$x,$y]="   "
        done
    done

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

    for MON in "${MONITORS[@]}"; do
        POS=${REL_POSITIONS[$MON]}
        [[ "$MON" == "$PRIMARY_MON" ]] && POS="primary"
        read X Y <<< $(get_coords "$POS")
        CHAR="[█]"; [[ "$MON" != "$PRIMARY_MON" ]] && CHAR="[▒]"
        GRID[$X,$Y]="$CHAR"
    done

    for ((y=0;y<GRID_HEIGHT;y++)); do
        LINE="   "
        for ((x=0;x<GRID_WIDTH;x++)); do
            LINE+="${GRID[$x,$y]}"
        done
        echo "$LINE"
    done
    echo "   █ = Primary, ▒ = Secondary"
fi

# 9️⃣ Update config
echo ""
read -rp "Apply this configuration? (y/n): " UPDATE
if ! [[ "$UPDATE" =~ ^[Yy]$ ]]; then
    echo "No changes made. Exiting."
    exit 0
fi

cp "$HYPRCONF" "$BACKUP"
echo "🔄 Backed up to $BACKUP"

MONITOR_SECTION=""
for MON in "${MONITORS[@]}"; do
    INFO=(${MONS_SELECTED[$MON]})
    WIDTH=${INFO[0]}; HEIGHT=${INFO[1]}; REFRESH=${INFO[2]}
    X=${MON_X[$MON]}; Y=${MON_Y[$MON]}
    MONITOR_SECTION+="monitor=$MON,${WIDTH}x${HEIGHT}@${REFRESH},${X}x${Y},1"$'\n'
done

sed -i '/^monitor=/d' "$HYPRCONF"
echo -e "\n$MONITOR_SECTION" >> "$HYPRCONF"
echo "✅ Monitor section updated."

# 🔟 Reload Hyprland
hyprctl reload
echo "🔁 Hyprland reloaded. Done!"
