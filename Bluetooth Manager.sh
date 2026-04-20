#!/bin/bash

# Headless mode check
if [[ "$1" == "--nogui" ]]; then
    export HEADLESS=true
    shift
fi
if [[ "$HEADLESS" == "true" ]]; then
    dialog() { if [[ "$*" == *"--msgbox"* ]] || [[ "$*" == *"--infobox"* ]]; then echo "DIALOG: $@"; fi; }
    export -f dialog
fi

# Load external utilities
export T_BACKTITLE CURR_TTY; source "$(dirname "$0")/lib/bt_utils.sh"
source "$(dirname "$0")/lib/locale.sh"
source "$(dirname "$0")/lib/bt_ui.sh"
source "$(dirname "$0")/lib/bt_audio.sh"
source "$(dirname "$0")/lib/bt_keyboard.sh"
source "$(dirname "$0")/lib/bt_core.sh"
source "$(dirname "$0")/lib/bt_system.sh"
source "$(dirname "$0")/lib/bt_audit.sh"

#-------------------------------------#
#           BT Manager 3.6            #
#            By djparent              #
#             A fork of               #
#         Bluetooth Manager           #
#           dArkOS Edition            #
#             by Jason                #
#-------------------------------------#

# Root privileges check
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# Variables
SYSTEM_LANG=""
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
ARK_UID=$(id -u ark)
SCRIPT_NAME="$(basename "$0")"
ASOUNDRC="/home/ark/.asoundrc"
ASOUNDRC_BAK="/home/ark/.asoundrcbak"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PULSE_SOCKET="/run/user/${ARK_UID}/pulse/native"
INSTALLED_FLAG="/home/ark/.bt_manager_installed"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"

# Initialization
export TERM=linux
mkdir -p /run/user/${ARK_UID}
chown ark:ark /run/user/${ARK_UID}
chmod 700 /run/user/${ARK_UID}
export XDG_RUNTIME_DIR=/run/user/${ARK_UID}
export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
# Display Management
if [[ "$HEADLESS" != "true" ]]; then
    printf "\e[?25l" > "$CURR_TTY"
    dialog --clear
    # Cleanly kill OSK if it exists
    pkill -f osk.py 2>/dev/null
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "$T_STARTING" > "$CURR_TTY"
    sleep 0.1
fi

# Gamepad Setup
if [[ "$HEADLESS" != "true" ]]; then
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    sudo chmod 666 /dev/uinput
    StartGPTKeyb
fi

# Headless Menu Loop
if [[ "$HEADLESS" == "true" ]]; then
    echo "--- Headless Mode Active ---"
    while true; do
        echo ""
        echo "1) Toggle BT      2) Scan (Deep)     3) Disconnect"
        echo "4) Known Dev      5) Forget Dev      6) Toggle Drv"
        echo "7) Run Audit      8) Play Chime      9) Read Audit"
        echo "10) Power-Shift   11) Restore WiFi   12) System Setup"
        echo "13) Update        14) Repair Stack   15) Exit"
        read -p "Select an option: " choice
        case $choice in
            1) ToggleBT ;;
            2) ScanAndConnect ;;
            3) DisconnectProcess ;;
            4) ListKnownAndConnect ;;
            5) DeleteDevice ;;
            6) ToggleDriver ;;
            7) RunAudit ;;
            8) PlayTestChime ;;
            9) ReadAudit ;;
            10) PowerShiftBT ;;
            11) RestoreWiFi ;;
            12) SystemSetup ;;
            13) UpdateScript ;;
            14) RepairStack ;;
            15) exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
fi

printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap ExitMenu EXIT

MainMenu

