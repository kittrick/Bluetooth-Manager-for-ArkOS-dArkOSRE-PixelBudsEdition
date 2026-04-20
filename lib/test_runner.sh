#!/bin/bash

# Headless mode setup
export HEADLESS=true
export CURR_TTY=/dev/stdout
dialog() {
    # Simple dummy dialog that outputs the message to stdout
    local title=""
    while [[ "$1" == --* ]]; do
        if [[ "$1" == "--title" ]]; then title="$2"; fi
        shift; shift
    done
    echo "DIALOG [$title]: $1"
}
export -f dialog

# Initialize variables required by libraries
export ARK_UID=$(id -u ark 2>/dev/null || echo 1000)
export PULSE_SOCKET="/run/user/${ARK_UID}/pulse/native"
export SYSTEM_LANG="en" # Default for tests

# Source all libraries
LIB_DIR="/opt/system/Tools/lib"
[ ! -d "$LIB_DIR" ] && LIB_DIR="$(dirname "$0")"

source "$LIB_DIR/bt_utils.sh"
source "$LIB_DIR/locale.sh"
source "$LIB_DIR/bt_ui.sh"
source "$LIB_DIR/bt_audio.sh"
source "$LIB_DIR/bt_keyboard.sh"
source "$LIB_DIR/bt_core.sh"
source "$LIB_DIR/bt_system.sh"
source "$LIB_DIR/bt_audit.sh"

case "$1" in
    powershift) PowerShiftBT ;;
    restore)    RestoreWiFi ;;
    repair)     RepairStack ;;
    audit)      RunAudit ;;
    *)          echo "Usage: $0 {powershift|restore|repair|audit}" ;;
esac
