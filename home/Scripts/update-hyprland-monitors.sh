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

declare -A MONS_MODES MONS_SELECTED MONS_TRANSFORM

# Parse available modes for each monitor
for MON in "${MONITORS[@]}"; do
    MODES=$(echo "$MONITOR_JSON" | jq -r ".[] | select(.name==\"$MON\") | .availableModes[]?" 2>/dev/null)

    if [[ -z "$MODES" ]]; then
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

    mapfile -t MODES_ARR <<< "$MODES_RAW"

    IFS=$'\n' SORTED_MODES=($(for m in "${MODES_ARR[@]}"; do
        echo "$m"
    done | sort -t'x' -k1 -rn | sort -t'@' -k1,1 -rn -s))
    unset IFS

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
    SELECTED_CLEAN=$(echo "$SELECTED" | sed 's/Hz$//')
    WIDTH=$(echo "$SELECTED_CLEAN" | cut -d'x' -f1)
    HEIGHT=$(echo "$SELECTED_CLEAN" | cut -d'x' -f2 | cut -d'@' -f1)
    REFRESH=$(echo "$SELECTED_CLEAN" | cut -d'@' -f2)
    REFRESH=$(printf "%.0f" "$REFRESH")

    MONS_SELECTED["$MON"]="$WIDTH $HEIGHT $REFRESH"
    echo "   ✓ Selected: ${WIDTH}x${HEIGHT}@${REFRESH}Hz"
}

# 4.5️⃣ Select orientation for each monitor
select_orientation() {
    local MON=$1

    echo -e "\n🔄 Orientation for $MON:"
    echo "   ─────────────────────────────────"
    echo "   1) Normal (landscape)"
    echo "   2) 90° clockwise (portrait, right)"
    echo "   3) 180° (upside down)"
    echo "   4) 270° clockwise (portrait, left)"
    echo "   ─────────────────────────────────"

    read -rp "   Select orientation [1-4] (default: 1): " ORIENT_NUM
    [[ -z "$ORIENT_NUM" ]] && ORIENT_NUM=1

    while [[ ! "$ORIENT_NUM" =~ ^[1-4]$ ]]; do
        echo "   Invalid selection. Enter 1-4"
        read -rp "   Select orientation: " ORIENT_NUM
    done

    local TRANSFORM=0
    local ORIENT_NAME="normal"
    case "$ORIENT_NUM" in
        1) TRANSFORM=0; ORIENT_NAME="normal" ;;
        2) TRANSFORM=1; ORIENT_NAME="90°" ;;
        3) TRANSFORM=2; ORIENT_NAME="180°" ;;
        4) TRANSFORM=3; ORIENT_NAME="270°" ;;
    esac

    MONS_TRANSFORM["$MON"]=$TRANSFORM
    echo "   ✓ Orientation: $ORIENT_NAME"
}

# Helper: Get effective dimensions (swapped if rotated 90/270)
get_effective_dims() {
    local MON=$1
    local INFO=(${MONS_SELECTED[$MON]})
    local W=${INFO[0]}
    local H=${INFO[1]}
    local T=${MONS_TRANSFORM[$MON]:-0}

    if [[ $T -eq 1 || $T -eq 3 ]]; then
        echo "$H $W"
    else
        echo "$W $H"
    fi
}

echo -e "\n════════════════════════════════════════"
echo "       MONITOR CONFIGURATION WIZARD"
echo "════════════════════════════════════════"

for MON in "${MONITORS[@]}"; do
    select_mode "$MON"
    select_orientation "$MON"
done

# 5️⃣ Primary monitor selection
echo -e "\n════════════════════════════════════════"
echo "         SELECT PRIMARY MONITOR"
echo "════════════════════════════════════════"

for i in "${!MONITORS[@]}"; do
    MON="${MONITORS[$i]}"
    INFO=(${MONS_SELECTED[$MON]})
    DIMS=($(get_effective_dims "$MON"))
    T=${MONS_TRANSFORM[$MON]:-0}
    ORIENT_STR=""
    [[ $T -ne 0 ]] && ORIENT_STR=" [rotated]"
    printf "   %d) %s (%sx%s@%s%s)\n" "$((i+1))" "$MON" "${DIMS[0]}" "${DIMS[1]}" "${INFO[2]}" "$ORIENT_STR"
done

read -rp $'\n   Select primary monitor [1-'${#MONITORS[@]}']: ' PRIMARY_NUM
while [[ ! "$PRIMARY_NUM" =~ ^[0-9]+$ ]] || ((PRIMARY_NUM < 1 || PRIMARY_NUM > ${#MONITORS[@]})); do
    echo "   Invalid selection. Enter a number between 1 and ${#MONITORS[@]}"
    read -rp "   Select primary monitor: " PRIMARY_NUM
done
PRIMARY_MON="${MONITORS[$((PRIMARY_NUM-1))]}"
echo "   ✓ Primary: $PRIMARY_MON"

# 6️⃣ Position each secondary monitor
declare -A MON_X MON_Y
declare -a POSITIONED_MONITORS
MON_X["$PRIMARY_MON"]=0
MON_Y["$PRIMARY_MON"]=0
POSITIONED_MONITORS+=("$PRIMARY_MON")

if [[ ${#MONITORS[@]} -gt 1 ]]; then
    echo -e "\n════════════════════════════════════════"
    echo "        MONITOR POSITION LAYOUT"
    echo "════════════════════════════════════════"
    echo "   Position each monitor relative to an already-placed monitor."

    for MON in "${MONITORS[@]}"; do
        [[ "$MON" == "$PRIMARY_MON" ]] && continue

        echo -e "\n   ┌─────────────────────────────────────┐"
        echo "   │  Positioning: $MON"
        echo "   └─────────────────────────────────────┘"

        # Select reference monitor
        echo -e "\n   Position relative to which monitor?"
        for i in "${!POSITIONED_MONITORS[@]}"; do
            REF="${POSITIONED_MONITORS[$i]}"
            DIMS=($(get_effective_dims "$REF"))
            TAG=""
            [[ "$REF" == "$PRIMARY_MON" ]] && TAG=" [PRIMARY]"
            printf "   %d) %s (%sx%s)%s\n" "$((i+1))" "$REF" "${DIMS[0]}" "${DIMS[1]}" "$TAG"
        done

        read -rp "   Select reference [1-${#POSITIONED_MONITORS[@]}]: " REF_NUM
        while [[ ! "$REF_NUM" =~ ^[0-9]+$ ]] || ((REF_NUM < 1 || REF_NUM > ${#POSITIONED_MONITORS[@]})); do
            echo "   Invalid selection."
            read -rp "   Select reference: " REF_NUM
        done
        REF_MON="${POSITIONED_MONITORS[$((REF_NUM-1))]}"

        # Select position
        echo -e "\n   Where is $MON relative to $REF_MON?"
        echo "   ┌─────────────────────────────────────────────┐"
        echo "   │     1) above-left   2) above    3) above-right    │"
        echo "   │                                                   │"
        echo "   │     4) left        [REFERENCE]       5) right     │"
        echo "   │                                                   │"
        echo "   │     6) below-left   7) below    8) below-right    │"
        echo "   └─────────────────────────────────────────────┘"

        read -rp "   Select position [1-8]: " POS_NUM
        while [[ ! "$POS_NUM" =~ ^[0-9]+$ ]] || ((POS_NUM < 1 || POS_NUM > 8)); do
            echo "   Invalid selection."
            read -rp "   Select position: " POS_NUM
        done

        # Alignment option for edge positions
        ALIGN="center"
        case "$POS_NUM" in
            2|7) # above/below - horizontal alignment
                echo -e "\n   Horizontal alignment:"
                echo "   1) left-aligned   2) centered   3) right-aligned"
                read -rp "   Select alignment [1-3] (default: 2): " ALIGN_NUM
                [[ -z "$ALIGN_NUM" ]] && ALIGN_NUM=2
                case "$ALIGN_NUM" in
                    1) ALIGN="start" ;;
                    2) ALIGN="center" ;;
                    3) ALIGN="end" ;;
                esac
                ;;
            4|5) # left/right - vertical alignment
                echo -e "\n   Vertical alignment:"
                echo "   1) top-aligned   2) centered   3) bottom-aligned"
                read -rp "   Select alignment [1-3] (default: 2): " ALIGN_NUM
                [[ -z "$ALIGN_NUM" ]] && ALIGN_NUM=2
                case "$ALIGN_NUM" in
                    1) ALIGN="start" ;;
                    2) ALIGN="center" ;;
                    3) ALIGN="end" ;;
                esac
                ;;
        esac

        # Calculate position
        REF_DIMS=($(get_effective_dims "$REF_MON"))
        MON_DIMS=($(get_effective_dims "$MON"))
        RW=${REF_DIMS[0]}; RH=${REF_DIMS[1]}
        MW=${MON_DIMS[0]}; MH=${MON_DIMS[1]}
        RX=${MON_X[$REF_MON]}; RY=${MON_Y[$REF_MON]}

        case "$POS_NUM" in
            1) # above-left
                MON_X["$MON"]=$((RX))
                MON_Y["$MON"]=$((RY - MH))
                ;;
            2) # above
                case "$ALIGN" in
                    start)  MON_X["$MON"]=$((RX)) ;;
                    center) MON_X["$MON"]=$((RX + (RW - MW) / 2)) ;;
                    end)    MON_X["$MON"]=$((RX + RW - MW)) ;;
                esac
                MON_Y["$MON"]=$((RY - MH))
                ;;
            3) # above-right
                MON_X["$MON"]=$((RX + RW - MW))
                MON_Y["$MON"]=$((RY - MH))
                ;;
            4) # left
                MON_X["$MON"]=$((RX - MW))
                case "$ALIGN" in
                    start)  MON_Y["$MON"]=$((RY)) ;;
                    center) MON_Y["$MON"]=$((RY + (RH - MH) / 2)) ;;
                    end)    MON_Y["$MON"]=$((RY + RH - MH)) ;;
                esac
                ;;
            5) # right
                MON_X["$MON"]=$((RX + RW))
                case "$ALIGN" in
                    start)  MON_Y["$MON"]=$((RY)) ;;
                    center) MON_Y["$MON"]=$((RY + (RH - MH) / 2)) ;;
                    end)    MON_Y["$MON"]=$((RY + RH - MH)) ;;
                esac
                ;;
            6) # below-left
                MON_X["$MON"]=$((RX))
                MON_Y["$MON"]=$((RY + RH))
                ;;
            7) # below
                case "$ALIGN" in
                    start)  MON_X["$MON"]=$((RX)) ;;
                    center) MON_X["$MON"]=$((RX + (RW - MW) / 2)) ;;
                    end)    MON_X["$MON"]=$((RX + RW - MW)) ;;
                esac
                MON_Y["$MON"]=$((RY + RH))
                ;;
            8) # below-right
                MON_X["$MON"]=$((RX + RW - MW))
                MON_Y["$MON"]=$((RY + RH))
                ;;
        esac

        POSITIONED_MONITORS+=("$MON")
        echo "   ✓ Positioned at ${MON_X[$MON]}x${MON_Y[$MON]}"
    done
fi

# 7️⃣ Show summary
echo -e "\n════════════════════════════════════════"
echo "            CONFIGURATION SUMMARY"
echo "════════════════════════════════════════"

for MON in "${MONITORS[@]}"; do
    INFO=(${MONS_SELECTED[$MON]})
    DIMS=($(get_effective_dims "$MON"))
    X=${MON_X[$MON]}; Y=${MON_Y[$MON]}
    T=${MONS_TRANSFORM[$MON]:-0}
    PRIMARY_TAG=""
    [[ "$MON" == "$PRIMARY_MON" ]] && PRIMARY_TAG=" [PRIMARY]"
    ORIENT_TAG=""
    case $T in
        1) ORIENT_TAG=" (90°)" ;;
        2) ORIENT_TAG=" (180°)" ;;
        3) ORIENT_TAG=" (270°)" ;;
    esac
    echo "   $MON: ${INFO[0]}x${INFO[1]}@${INFO[2]}Hz${ORIENT_TAG} at ${X}x${Y}$PRIMARY_TAG"
    echo "         Effective: ${DIMS[0]}x${DIMS[1]}"
done

# 8️⃣ Visual preview
if [[ ${#MONITORS[@]} -gt 1 ]]; then
    echo -e "\n   Layout preview (approximate):"
    echo "   ─────────────────────────────────────"

    # Find bounds
    MIN_X=0; MAX_X=0; MIN_Y=0; MAX_Y=0
    for MON in "${MONITORS[@]}"; do
        DIMS=($(get_effective_dims "$MON"))
        X=${MON_X[$MON]}; Y=${MON_Y[$MON]}
        W=${DIMS[0]}; H=${DIMS[1]}
        ((X < MIN_X)) && MIN_X=$X
        ((Y < MIN_Y)) && MIN_Y=$Y
        ((X + W > MAX_X)) && MAX_X=$((X + W))
        ((Y + H > MAX_Y)) && MAX_Y=$((Y + H))
    done

    TOTAL_W=$((MAX_X - MIN_X))
    TOTAL_H=$((MAX_Y - MIN_Y))

    # Scale to fit in ~40x12 char grid
    GRID_W=40
    GRID_H=12
    SCALE_X=$((TOTAL_W / GRID_W + 1))
    SCALE_Y=$((TOTAL_H / GRID_H + 1))

    declare -A GRID
    for ((y=0; y<GRID_H; y++)); do
        for ((x=0; x<GRID_W; x++)); do
            GRID[$x,$y]=" "
        done
    done

    # Draw each monitor
    MON_NUM=1
    for MON in "${MONITORS[@]}"; do
        DIMS=($(get_effective_dims "$MON"))
        X=${MON_X[$MON]}; Y=${MON_Y[$MON]}
        W=${DIMS[0]}; H=${DIMS[1]}

        # Normalize and scale
        NX=$(( (X - MIN_X) / SCALE_X ))
        NY=$(( (Y - MIN_Y) / SCALE_Y ))
        NW=$(( W / SCALE_X ))
        NH=$(( H / SCALE_Y ))

        ((NW < 3)) && NW=3
        ((NH < 1)) && NH=1

        CHAR="$MON_NUM"
        [[ "$MON" == "$PRIMARY_MON" ]] && CHAR="P"

        # Draw border
        for ((gx=NX; gx<NX+NW && gx<GRID_W; gx++)); do
            for ((gy=NY; gy<NY+NH && gy<GRID_H; gy++)); do
                if ((gx == NX || gx == NX+NW-1 || gy == NY || gy == NY+NH-1)); then
                    GRID[$gx,$gy]="░"
                fi
            done
        done

        # Place label in center
        CX=$((NX + NW/2))
        CY=$((NY + NH/2))
        ((CX < GRID_W && CY < GRID_H)) && GRID[$CX,$CY]="$CHAR"

        ((MON_NUM++))
    done

    # Print grid
    for ((y=0; y<GRID_H; y++)); do
        LINE="   "
        for ((x=0; x<GRID_W; x++)); do
            LINE+="${GRID[$x,$y]}"
        done
        echo "$LINE"
    done

    echo ""
    echo "   Legend: P = Primary"
    MON_NUM=1
    for MON in "${MONITORS[@]}"; do
        [[ "$MON" != "$PRIMARY_MON" ]] && echo "           $MON_NUM = $MON"
        ((MON_NUM++))
    done
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
    T=${MONS_TRANSFORM[$MON]:-0}

    # Hyprland format: monitor=name,resolution,position,scale,transform,X
    if [[ $T -eq 0 ]]; then
        MONITOR_SECTION+="monitor=$MON,${WIDTH}x${HEIGHT}@${REFRESH},${X}x${Y},1"$'\n'
    else
        MONITOR_SECTION+="monitor=$MON,${WIDTH}x${HEIGHT}@${REFRESH},${X}x${Y},1,transform,$T"$'\n'
    fi
done

sed -i '/^monitor=/d' "$HYPRCONF"
echo -e "\n$MONITOR_SECTION" >> "$HYPRCONF"
echo "✅ Monitor section updated."

# Show the generated config
echo -e "\n   Generated config:"
echo "   ─────────────────────────────────────"
echo "$MONITOR_SECTION" | sed 's/^/   /'

# 🔟 Reload Hyprland
hyprctl reload
echo "🔁 Hyprland reloaded. Done!"
