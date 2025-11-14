#!/bin/bash

STATE_FILE="/tmp/waybar-network-state"

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
fi

# Read current state
STATE=$(cat "$STATE_FILE")

# Get network info using iw and ip commands
DEVICE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$DEVICE" ]; then
    echo '{"text": "󰖪  Disconnected", "class": "disconnected"}'
    exit 0
fi

# Check if it's wifi or ethernet
if [ -d "/sys/class/net/$DEVICE/wireless" ]; then
    # WiFi
    ESSID=$(iw dev "$DEVICE" info | grep ssid | awk '{print $2}')
    # Get signal strength from /proc/net/wireless
    SIGNAL=$(awk -v dev="$DEVICE" '$1 == dev":" {print int($3)}' /proc/net/wireless 2>/dev/null || echo "0")
    # Convert dBm to percentage (rough approximation: -100 dBm = 0%, -50 dBm = 100%)
    if [ "$SIGNAL" -lt 0 ]; then
        SIGNAL=$(awk "BEGIN {val=2*($SIGNAL+100); if(val<0) val=0; if(val>100) val=100; print int(val)}")
    fi
    IP=$(ip -4 addr show "$DEVICE" | grep inet | awk '{print $2}' | cut -d/ -f1)

    # Get bandwidth (this is a simple version, you might want to enhance it)
    RX_BYTES=$(cat /sys/class/net/"$DEVICE"/statistics/rx_bytes)
    TX_BYTES=$(cat /sys/class/net/"$DEVICE"/statistics/tx_bytes)
    sleep 1
    RX_BYTES_NEW=$(cat /sys/class/net/"$DEVICE"/statistics/rx_bytes)
    TX_BYTES_NEW=$(cat /sys/class/net/"$DEVICE"/statistics/tx_bytes)

    RX_RATE=$(( (RX_BYTES_NEW - RX_BYTES) / 1024 ))
    TX_RATE=$(( (TX_BYTES_NEW - TX_BYTES) / 1024 ))

    # Convert to human readable
    if [ $RX_RATE -gt 1024 ]; then
        RX_DISPLAY="$(awk "BEGIN {printf \"%.1f\", $RX_RATE/1024}")MB/s"
    else
        RX_DISPLAY="${RX_RATE}KB/s"
    fi

    if [ $TX_RATE -gt 1024 ]; then
        TX_DISPLAY="$(awk "BEGIN {printf \"%.1f\", $TX_RATE/1024}")MB/s"
    else
        TX_DISPLAY="${TX_RATE}KB/s"
    fi

    # Build tooltip with all info
    TOOLTIP="󰖩   $ESSID ($SIGNAL%)\\n󰩠 $IP\\n  $RX_DISPLAY    $TX_DISPLAY"

    case $STATE in
        0)
            # Show ESSID and signal
            echo "{\"text\": \"󰖩   $ESSID ($SIGNAL%)\", \"tooltip\": \"$TOOLTIP\", \"class\": \"wifi\"}"
            ;;
        1)
            # Show IP address
            echo "{\"text\": \"󰖩   $IP\", \"tooltip\": \"$TOOLTIP\", \"class\": \"wifi\"}"
            ;;
        2)
            # Show bandwidth
            echo "{\"text\": \"  $RX_DISPLAY   $TX_DISPLAY\", \"tooltip\": \"$TOOLTIP\", \"class\": \"wifi\"}"
            ;;
    esac
else
    # Ethernet
    IP=$(ip -4 addr show "$DEVICE" | grep inet | awk '{print $2}')

    # Get bandwidth
    RX_BYTES=$(cat /sys/class/net/"$DEVICE"/statistics/rx_bytes)
    TX_BYTES=$(cat /sys/class/net/"$DEVICE"/statistics/tx_bytes)
    sleep 1
    RX_BYTES_NEW=$(cat /sys/class/net/"$DEVICE"/statistics/rx_bytes)
    TX_BYTES_NEW=$(cat /sys/class/net/"$DEVICE"/statistics/tx_bytes)

    RX_RATE=$(( (RX_BYTES_NEW - RX_BYTES) / 1024 ))
    TX_RATE=$(( (TX_BYTES_NEW - TX_BYTES) / 1024 ))

    # Convert to human readable
    if [ $RX_RATE -gt 1024 ]; then
        RX_DISPLAY="$(awk "BEGIN {printf \"%.1f\", $RX_RATE/1024}")MB/s"
    else
        RX_DISPLAY="${RX_RATE}KB/s"
    fi

    if [ $TX_RATE -gt 1024 ]; then
        TX_DISPLAY="$(awk "BEGIN {printf \"%.1f\", $TX_RATE/1024}")MB/s"
    else
        TX_DISPLAY="${TX_RATE}KB/s"
    fi

    # Build tooltip with all info
    TOOLTIP="󰈀 Ethernet\\n󰩠 $IP\\n  $RX_DISPLAY  $TX_DISPLAY"

    case $STATE in
        0)
            # Show connection type
            echo "{\"text\": \"󰈀 Connected\", \"tooltip\": \"$TOOLTIP\", \"class\": \"ethernet\"}"
            ;;
        1)
            # Show IP address
            echo "{\"text\": \"󰈀 $IP\", \"tooltip\": \"$TOOLTIP\", \"class\": \"ethernet\"}"
            ;;
        2)
            # Show bandwidth
            echo "{\"text\": \" $RX_DISPLAY  $TX_DISPLAY\", \"tooltip\": \"$TOOLTIP\", \"class\": \"ethernet\"}"
            ;;
    esac
fi
