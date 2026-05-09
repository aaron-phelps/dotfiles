#!/bin/bash
# Auto-restart cava if it exits (handles audio source not being ready at waybar startup).
trap 'kill "$cava_pid" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    cava -p ~/.config/cava/config 2>/dev/null \
        | sed -u 's/;//g;s/0/▁/g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g;' &
    cava_pid=$!
    wait "$cava_pid"
    sleep 1
done
