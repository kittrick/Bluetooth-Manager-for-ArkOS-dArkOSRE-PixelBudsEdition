#!/bin/bash

# Headless mode check
if [[ "$1" == "--nogui" ]]; then
    export HEADLESS=true
    shift
fi
if [[ "$HEADLESS" == "true" ]]; then
    dialog() { echo "DIALOG: $@"; }
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
fi

# Display Management
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
StopGPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_STARTING" > "$CURR_TTY"
sleep 0.1

# Gamepad Setup
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
sudo chmod 666 /dev/uinput
StartGPTKeyb

printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap ExitMenu EXIT

MainMenu
