#!/bin/bash

if pgrep -x wf-recorder > /dev/null || pgrep -x ffmpeg > /dev/null; then
    echo '{"text": " REC", "class": "recording", "tooltip": "Click to stop recording"}'
else
    echo ''
fi
