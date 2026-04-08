#!/bin/bash

# ==============================================================================
# DEBICONF - ČISTÝ DEBIAN S DESKTOPOVÝM PROSTŘEDÍM
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    echo "Nutno spustit jako root (sudo)"
    exit 1
fi

REAL_USER=$(ls /home | head -n 1)
USER_HOME="/home/$REAL_USER"
BASE_DIR="$(dirname "$(realpath "$0")")"
CONTENTS_DIR="$BASE_DIR/.contents"
GLOBAL_CONFIG="$CONTENTS_DIR/setup-config.txt"

[ -f "$CONTENTS_DIR/lxqt/config/Shortcuts.conf" ] && mv "$CONTENTS_DIR/lxqt/config/Shortcuts.conf" "$CONTENTS_DIR/lxqt/config/shortcuts.conf" 2>/dev/null
[ -f "$CONTENTS_DIR/lxqt/config/shortcuts.conf" ] && sed -i 's/\r$//' "$CONTENTS_DIR/lxqt/config/shortcuts.conf"
[ -f "$CONTENTS_DIR/lxqt/config/xfwm.conf" ] && sed -i 's/\r$//' "$CONTENTS_DIR/lxqt/config/xfwm.conf"
[ -f "$CONTENTS_DIR/lxqt/config/contextmenu.conf" ] && sed -i 's/\r$//' "$CONTENTS_DIR/lxqt/config/contextmenu.conf"

SHORTCUTS_SRC="$CONTENTS_DIR/lxqt/config/shortcuts.conf"
XFWM_SRC="$CONTENTS_DIR/lxqt/config/xfwm.conf"

# --- ZJIŠTĚNÍ JAZYKA PŘÍMO Z INSTALACE DEBIANU ---
SYS_LOCALE=$(grep "^LANG=" /etc/default/locale | cut -d'=' -f2 | tr -d '"')
[ -z "$SYS_LOCALE" ] && SYS_LOCALE="en_US.UTF-8"
SYS_LANG_CODE="${SYS_LOCALE%%.*}" # Odřízne .UTF-8, zbyde např. cs_CZ
echo ">> Detekován systémový jazyk instalace: $SYS_LANG_CODE"

# --- 1. INTERAKTIVNÍ DOTAZY ---
echo "--------------------------------------------------"
read -p "1) KDE Plasma | 2) LXQT (Ready out of the box): " DISTRO_ANS
[[ "$DISTRO_ANS" == "1" ]] && DESKTOP_ENV="PLASMA" || DESKTOP_ENV="LXQT"

read -p "Vyber prohlížeč (1-Chrome, 2-Chromium, 3-Brave, 4-Firefox, 5-Nic): " BROWSER_CHOICE
read -p "Chceš nastavit automatické přihlašování? (1=ANO, 2=NE): " AUTO_ANS
[[ "$AUTO_ANS" == "1" ]] && { AUTOLOGIN_REQ="TRUE"; RELOGIN_REQ="TRUE"; } || { AUTOLOGIN_REQ="FALSE"; RELOGIN_REQ="FALSE"; }

# --- 2. NAČTENÍ KONFIGURÁKŮ ---
apt update && apt install -y sudo curl wget dpkg-dev git dbus-x11 numlockx
usermod -aG sudo $REAL_USER

TIMEOUT=$(grep -i "^GRUB_TIMEOUT=" "$GLOBAL_CONFIG" | cut -d'=' -f2 | tr -d '[:space:]')
CONFIRM_LOGOUT=$(grep -i "^CONFIRM_LOGOUT=" "$GLOBAL_CONFIG" | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
[[ "$CONFIRM_LOGOUT" == "TRUE" ]] && CONF_OUT="true" || CONF_OUT="false"

GLOBAL_PACKAGES=$(sed -n '/^\[INSTALL\]/,/^\[/p' "$GLOBAL_CONFIG" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | grep -v '=' | xargs)
LOCAL_CONFIG="$CONTENTS_DIR/$(echo $DESKTOP_ENV | tr '[:upper:]' '[:lower:]')/config.txt"

CORE_PACKAGES=$(sed -n '/^\[CORE_PACKAGES\]/,/^\[/p' "$LOCAL_CONFIG" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | xargs)
EXTRA_PACKAGES=$(sed -n '/^\[EXTRA_PACKAGES\]/,/^\[/p' "$LOCAL_CONFIG" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | xargs)
ALL_PACKAGES="$CORE_PACKAGES $EXTRA_PACKAGES $GLOBAL_PACKAGES"
APPS_TO_HIDE_STR=$(sed -n '/^\[APPS_TO_HIDE\]/,/^\[/p' "$LOCAL_CONFIG" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | xargs)
read -r -a APPS_TO_HIDE <<< "$APPS_TO_HIDE_STR"

# --- 3. INSTALACE BALÍKŮ ---
for pkg in $ALL_PACKAGES; do
    apt install -y --no-install-recommends "$pkg" || echo "⚠️ SELHALO: $pkg"
done

case $BROWSER_CHOICE in
    1) wget -qO /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && apt install -y /tmp/chrome.deb ;;
    2) apt install -y chromium chromium-l10n ;;
    3) curl -fsS https://dl.brave.com/install.sh | sh ;;
    4) apt install -y firefox-esr firefox-esr-l10n-cs ;;
esac

# --- 4. LXQT TÉMA A KONFIGY ---
if [ "$DESKTOP_ENV" == "LXQT" ]; then
    cd /tmp && rm -rf lubuntu-rip && mkdir -p lubuntu-rip && cd lubuntu-rip
    FILE_NAME=$(wget -qO- http://archive.ubuntu.com/ubuntu/pool/universe/l/lubuntu-artwork/ | grep -o 'lubuntu-artwork_[^"]*_all\.deb' | tail -n 1)
    if [ -n "$FILE_NAME" ]; then
        wget "http://archive.ubuntu.com/ubuntu/pool/universe/l/lubuntu-artwork/$FILE_NAME" -O lubuntu-artwork.deb
        dpkg-deb -x lubuntu-artwork.deb root_dir
        mkdir -p "$USER_HOME/.local/share/lxqt/themes"
        cp -r root_dir/usr/share/lxqt/themes/* "$USER_HOME/.local/share/lxqt/themes/"
    fi
    cd ~ && rm -rf /tmp/lubuntu-rip
    
    CONF_SRC="$CONTENTS_DIR/lxqt/config"
    mkdir -p "$USER_HOME/.config/lxqt" "$USER_HOME/.config/pcmanfm-qt/lxqt"
    cp "$CONF_SRC/"*.conf "$USER_HOME/.config/lxqt/" 2>/dev/null
    cp "$CONF_SRC/pcmanfm-qt.conf" "$USER_HOME/.config/pcmanfm-qt/lxqt/settings.conf" 2>/dev/null

    if [ -f "$CONF_SRC/lxqt-panel_amd64_no_about" ]; then
        mv /usr/bin/lxqt-panel /usr/bin/lxqt-panel.bak 2>/dev/null
        cp "$CONF_SRC/lxqt-panel_amd64_no_about" /usr/bin/lxqt-panel
        chmod +x /usr/bin/lxqt-panel
    fi

    SCRIPTS_SRC="$CONTENTS_DIR/lxqt/scripts"
    mkdir -p "$USER_HOME/.local/bin"
    if [ -d "$SCRIPTS_SRC" ]; then
        cp -u "$SCRIPTS_SRC/"* "$USER_HOME/.local/bin/" 2>/dev/null
        chmod +x "$USER_HOME/.local/bin/"* 2>/dev/null
    fi
fi

# --- 5. SYSTÉMOVÉ NASTAVENÍ A JAZYK ---
usermod -aG audio,pulse,pulse-access,video,plugdev $REAL_USER
chmod +s $(which brightnessctl) 2>/dev/null
rm -f "/tmp/jas_notif_id"

if ! grep -q ".local/bin" "$USER_HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
fi

# Pojištění jazyka pro LXQt (zjištěno z Debianu na začátku)
echo "export LANG=$SYS_LOCALE" > /etc/profile.d/00-locale.sh
echo "export LC_ALL=$SYS_LOCALE" >> /etc/profile.d/00-locale.sh

mkdir -p /etc/polkit-1/rules.d
echo 'polkit.addRule(function(action, subject) { if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" || action.id == "org.freedesktop.udisks2.filesystem-mount") && subject.isInGroup("sudo")) { return polkit.Result.YES; } });' > /etc/polkit-1/rules.d/50-udisks2-automount.rules

TOUCHPAD_SRC="$CONTENTS_DIR/lxqt/config/touchpad.conf"
mkdir -p /etc/X11/xorg.conf.d
if [ -f "$TOUCHPAD_SRC" ]; then
    cp "$TOUCHPAD_SRC" /etc/X11/xorg.conf.d/40-libinput-touchpad.conf
fi

# --- OPRAVA SÍTĚ (VYHLAZENÍ STARÉHO DEBIANÍHO BALASTU) ---
    echo ">> Odstraňuji ifupdown, aby NetworkManager mohl převzít síť..."
    apt-get purge -y ifupdown

    # Vyčištění zbytků starých konfigurací, aby do toho už nic nekecalo
    rm -rf /etc/network/interfaces.d/*
    cat > /etc/network/interfaces << 'EOF'
    auto lo
    iface lo inet loopback 
EOF

# --- 6. LXQT & XFWM TWEAKY ---
if [ "$DESKTOP_ENV" == "LXQT" ]; then
    
    # --- A. XFWM4 ---
    SESSION_CONF="$USER_HOME/.config/lxqt/session.conf"
    if [ ! -f "$SESSION_CONF" ]; then
        echo -e "[General]\nwindow_manager=xfwm4" > "$SESSION_CONF"
    else
        sed -i 's/^window_manager=.*/window_manager=xfwm4/' "$SESSION_CONF"
        grep -q "^window_manager=" "$SESSION_CONF" || sed -i '/^\[General\]/a window_manager=xfwm4' "$SESSION_CONF"
    fi

    if [ -f "$XFWM_SRC" ]; then
        echo ">> Aplikuji nastavení XFWM4 (bez uvozovkového pekla)..."
        # Vytvoření dočasného skriptu přesně s tvými příkazy
        TMP_XFWM="/tmp/xfwm_setup.sh"
        echo "#!/bin/bash" > "$TMP_XFWM"
        cat "$XFWM_SRC" >> "$TMP_XFWM"
        chmod +x "$TMP_XFWM"

        # Spuštění celého souboru naráz v jedné D-Bus relaci
        su - $REAL_USER -c "dbus-launch $TMP_XFWM" 2>/dev/null
        
        # Úklid
        rm -f "$TMP_XFWM"
    fi

    # --- B. LXQT.CONF (Motiv a Dynamický Jazyk) ---
    LXQT_CONF="$USER_HOME/.config/lxqt/lxqt.conf"
    if [ -f "$LXQT_CONF" ]; then
        sed -i "s/^ask_before_logout=.*/ask_before_logout=$CONF_OUT/" "$LXQT_CONF"
        sed -i "s/^theme=.*/theme=Lubuntu Arc/" "$LXQT_CONF"
        
        # Zapíše systémový jazyk detekovaný Debianem
        if grep -q "^language=" "$LXQT_CONF"; then
            sed -i "s/^language=.*/language=$SYS_LANG_CODE/" "$LXQT_CONF"
        else
            sed -i "/^\[General\]/a language=$SYS_LANG_CODE" "$LXQT_CONF"
        fi
    fi

    # --- C. ZKRATKY ---
    SHORTCUTS_CONF="$USER_HOME/.config/lxqt/globalkeyshortcuts.conf"
    if [ -f "$SHORTCUTS_SRC" ]; then
        sed -i '/\.99\]/,+3d' "$SHORTCUTS_CONF" 2>/dev/null
        
        while IFS='|' read -r label shortcut cmd || [[ -n "$label" ]]; do
            [[ "$label" =~ ^#.*$ || -z "$label" ]] && continue
            safe_shortcut="${shortcut//+/%2B}"
            FINAL_CMD=$(echo "$cmd" | sed "s|brightness.sh|$USER_HOME/.local/bin/brightness.sh|g")
            echo -e "\n[${safe_shortcut}.99]\nComment=$label\nEnabled=true\nExec=$FINAL_CMD" >> "$SHORTCUTS_CONF"
        done < "$SHORTCUTS_SRC"
    fi

    # --- D. BUSY LAUNCH A SKRÝVÁNÍ ---
    WRAPPER_BIN="$USER_HOME/.local/bin/busy-launch.py"
    LOCAL_APPS="$USER_HOME/.local/share/applications"
    mkdir -p "$LOCAL_APPS"
    
    for app in /usr/share/applications/*.desktop; do
        app_name=$(basename "$app")
        cp "$app" "$LOCAL_APPS/"
        sed -i "s|^Exec=|Exec=python3 $WRAPPER_BIN |" "$LOCAL_APPS/$app_name"
    done

    for app in "${APPS_TO_HIDE[@]}"; do
        [ -f "$LOCAL_APPS/$app" ] && sed -i '/^NoDisplay=/d; $ a NoDisplay=true' "$LOCAL_APPS/$app"
    done

    # --- E. PANEL IKONY A VÝCHOZÍ PROHLÍŽEČ ---
    PANEL_CONF="$USER_HOME/.config/lxqt/panel.conf"
    SESSION_CONF="$USER_HOME/.config/lxqt/session.conf"
    
    case $BROWSER_CHOICE in
        1) B_NAME="google-chrome.desktop"; B_EXEC="google-chrome-stable" ;;
        2) B_NAME="chromium.desktop"; B_EXEC="chromium" ;;
        3) B_NAME="brave-browser.desktop"; B_EXEC="brave-browser" ;;
        4) B_NAME="firefox-esr.desktop"; B_EXEC="firefox-esr" ;;
        *) B_NAME=""; B_EXEC="" ;;
    esac

    # Zápis výchozího prohlížeče do session.conf
    if [ -f "$SESSION_CONF" ] && [ -n "$B_EXEC" ]; then
        sed -i "s/^BROWSER=.*/BROWSER=$B_EXEC/" "$SESSION_CONF"
    fi

    # Zápis zástupců do panelu
    if [ -f "$PANEL_CONF" ]; then
        sed -i '/^apps\\/d' "$PANEL_CONF"
        if [ -n "$B_NAME" ]; then
            sed -i "/^\[quicklaunch\]/a apps\\\\1\\\\desktop=$LOCAL_APPS/pcmanfm-qt.desktop\napps\\\\2\\\\desktop=$LOCAL_APPS/$B_NAME\napps\\\\size=2" "$PANEL_CONF"
        else
            sed -i "/^\[quicklaunch\]/a apps\\\\1\\\\desktop=$LOCAL_APPS/pcmanfm-qt.desktop\napps\\\\size=1" "$PANEL_CONF"
        fi
    fi

    # --- F. QTERMINAL A KONTEXTOVÉ MENU ---
    Q_CONF="$USER_HOME/.config/qterminal.org/qterminal.ini"
    mkdir -p "$(dirname "$Q_CONF")"
    [ ! -f "$Q_CONF" ] && echo -e "[General]\nshowTerminalSizeHint=false" > "$Q_CONF" || sed -i '/showTerminalSizeHint/d; /\[General\]/a showTerminalSizeHint=false' "$Q_CONF"

    CONTEXT_CONF="$CONTENTS_DIR/lxqt/config/contextmenu.conf"
    ACTION_DIR="$USER_HOME/.local/share/file-manager/actions"

    if [ -s "$CONTEXT_CONF" ]; then
        mkdir -p "$ACTION_DIR"
        CURRENT_FILE=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^FILE:\ (.*\.desktop)$ ]]; then
                CURRENT_FILE="${BASH_REMATCH[1]}"
                > "$ACTION_DIR/$CURRENT_FILE"
            elif [ -n "$CURRENT_FILE" ]; then
                echo "$line" >> "$ACTION_DIR/$CURRENT_FILE"
            fi
        done < "$CONTEXT_CONF"
    fi

    chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config" "$USER_HOME/.local"
elif [ "$DESKTOP_ENV" == "PLASMA" ]; then
    
    echo ">> Aplikuji specifické nastavení pro Plasmu..."
    
    # --- A. POTVRZENÍ ODHLÁŠENÍ V PLASMĚ ---
    KSM_CONF="$USER_HOME/.config/ksmserverrc"
    mkdir -p "$USER_HOME/.config"
    
    if [ "$CONF_OUT" == "false" ]; then
        echo -e "[General]\nconfirmLogout=false" > "$KSM_CONF"
    else
        echo -e "[General]\nconfirmLogout=true" > "$KSM_CONF"
    fi
    
    chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config"
fi

# --- 7. DISPLAY MANAGER (SDDM / LIGHTDM) A GRUB ---
if [ "$DESKTOP_ENV" == "PLASMA" ]; then
    # --- PLASMA (SDDM) ---
    echo "/usr/bin/sddm" > /etc/X11/default-display-manager 2>/dev/null
    dpkg-reconfigure -f noninteractive sddm 2>/dev/null
    
    if [ "$AUTOLOGIN_REQ" == "TRUE" ]; then
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=$REAL_USER
Session=plasma
EOF
    fi
else
    # --- LXQT (LIGHTDM) ---
    echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager 2>/dev/null
    dpkg-reconfigure -f noninteractive lightdm 2>/dev/null
    
    if [ "$AUTOLOGIN_REQ" == "TRUE" ]; then
        mkdir -p /etc/lightdm/lightdm.conf.d
        echo -e "[Seat:*]\nautologin-user=$REAL_USER\nautologin-user-timeout=0" > /etc/lightdm/lightdm.conf.d/autologin.conf
        sed -i 's/^#greeter-setup-script=.*/greeter-setup-script=\/usr\/bin\/numlockx on/' /etc/lightdm/lightdm.conf 2>/dev/null
    fi
fi

sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$TIMEOUT/" /etc/default/grub
update-grub
systemctl set-default graphical.target

echo "=================================================="
echo " HOTOVO"
echo " RESTART ZA 5 SEKUND."
echo "=================================================="
sleep 5
reboot