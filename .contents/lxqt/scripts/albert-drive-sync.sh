#!/bin/bash
MEDIA_DIR="/media/$USER"
MNT_DIR="/mnt"
mkdir -p "$MEDIA_DIR" "$MNT_DIR"

while true; do
    inotifywait -e create -e delete "$MEDIA_DIR" "$MNT_DIR" 2>/dev/null
    
    # Dáme systému 5 sekund jistoty, ať se flashka stihne fyzicky připojit a načíst
    sleep 5
    
    # Natvrdo zabijeme Alberta a hned ho nahodíme
    killall -9 albert 2>/dev/null
    albert &
done