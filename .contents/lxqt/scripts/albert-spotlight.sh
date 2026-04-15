#!/bin/bash
# ULTIMÁTNÍ SPOTLIGHT DÉMON PRO ALBERTA (S POJISTKOU)
MEDIA_DIR="/media/$USER"
MNT_DIR="/mnt"
mkdir -p "$MEDIA_DIR" "$MNT_DIR"

while true; do
    # Inotify dál hlídá celý disk
    inotifywait -r -e create -e moved_to --exclude '/\.' "$HOME" "$MEDIA_DIR" "$MNT_DIR" 2>/dev/null
    
    sleep 1
    
    # KONTROLA: Běží Albert?
    # Příkaz pgrep -x hledá běžící proces s přesným názvem "albert". 
    # Pokud běží, provede se kill a restart. Pokud neběží, nestane se absolutně nic.
    if pgrep -x "albert" > /dev/null; then
        killall -9 albert 2>/dev/null
        albert &
    fi
done