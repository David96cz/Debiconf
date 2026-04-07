#!/bin/bash

# Získání aktuálního jasu (očištěno o znak %) ještě před změnou
CURRENT_JAS=$(brightnessctl -m | awk -F, '{print $4}' | tr -d '%')

# Nastavení jasu
if [ "$1" == "-i" ]; then
    brightnessctl set +5%
elif [ "$1" == "-d" ]; then
    # Kontrola: Pokud je jas > 5, dovolíme snížení
    if [ "$CURRENT_JAS" -gt 5 ]; then
        brightnessctl set 5%-
    fi
fi

# Získání nového jasu pro notifikaci
JAS=$(brightnessctl -m | awk -F, '{print $4}')

ID_FILE="/tmp/jas_notif_id"

# Načtení ID a kontrola, zda je to číslo
if [ -f "$ID_FILE" ]; then
    NOTIF_ID=$(cat "$ID_FILE")
fi

# Pokud NOTIF_ID není číslo nebo je prázdné, pošli novou notifikaci
if [[ ! "$NOTIF_ID" =~ ^[0-9]+$ ]]; then
    NEW_ID=$(notify-send -a "Jas monitoru" -p "Aktuální úroveň: $JAS" -t 1500 -i video-display)
else
    NEW_ID=$(notify-send -a "Jas monitoru" -p -r "$NOTIF_ID" "Aktuální úroveň: $JAS" -t 1500 -i video-display)
fi

echo "$NEW_ID" > "$ID_FILE"
