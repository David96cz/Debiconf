#!/bin/bash

# --- 1. DETEKCE UŽIVATELE A SUDO PRÁVA ---
# Vytáhne první složku v /home, což je stoprocentně ten tvůj uživatel
REAL_USER=$(ls /home | head -n 1)
echo "Našel jsem složku uživatele: $REAL_USER. Dávám mu sudo práva..."
apt install -y sudo
usermod -aG sudo $REAL_USER

# --- 2. NAČTENÍ KONFIGURACE Z TEXTÁKU ---
PACKAGES=$(sed -n '/^\[INSTALL\]/,/^\[/p' setup-config.txt | grep -v '\[.*\]' | xargs)
LOW_PC=$(grep "LOW_PC" setup-config.txt | cut -d'=' -f2)
TIMEOUT=$(grep "GRUB_TIMEOUT" setup-config.txt | cut -d'=' -f2)

# --- 3. INSTALACE VŠEHO BALASTU ---
echo "Instaluji systém: $PACKAGES"
apt install -y $PACKAGES

# --- 4. VYMRDÁNÍ SÍTĚ ---
echo "Mažu starou síť z interfaces, ať to sežere NetworkManager v Plasmě..."
echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces

# --- 5. LOW PC OPTIMALIZACE (Zapsáno přímo do configů uživatele) ---
if [ "$LOW_PC" == "TRUE" ]; then
    echo "Aplikuji hardcore ořezání Plasmy pro $REAL_USER..."
    # Vypnutí indexování Baloo
    su - $REAL_USER -c "kwriteconfig6 --file baloofilerc --group 'Basic Settings' --key 'Indexing-Enabled' false"
    # Totální vypnutí efektů kompozitoru
    su - $REAL_USER -c "kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false"
    su - $REAL_USER -c "kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_shadowEnabled false"
    su - $REAL_USER -c "kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_translucencyEnabled false"
    su - $REAL_USER -c "kwriteconfig6 --file kwinrc --group Compositing --key Enabled false"
fi

# --- 6. GRUB A REBOOT ---
echo "Zkracuju GRUB na $TIMEOUT sekund..."
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$TIMEOUT/" /etc/default/grub
update-grub

echo "Všechno hotovo. Restartuju do čistý Plasmy!"
reboot
