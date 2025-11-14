#!/bin/bash

STATE_FILE="/tmp/waybar-network-state"

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
fi

# Read current state
STATE=$(cat "$STATE_FILE")

# Cycle to next state (0 -> 1 -> 2 -> 0)
NEXT_STATE=$(( (STATE + 1) % 3 ))

# Write next state
echo "$NEXT_STATE" > "$STATE_FILE"
