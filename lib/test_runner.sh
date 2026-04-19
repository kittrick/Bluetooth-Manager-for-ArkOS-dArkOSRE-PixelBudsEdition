#!/bin/bash
# Load utilities, overriding dialog with a dummy function for CLI testing
dialog() {
    # Simple dummy dialog that outputs the message to stdout
    shift
    while [[ "$1" == --* ]]; do shift; shift; done
    echo "DIALOG: $1"
}
export -f dialog
export CURR_TTY=/dev/stdout

# Load the library
source /opt/system/Tools/lib/bt_utils.sh

case "$1" in
    powershift) PowerShiftBT ;;
    restore) RestoreWiFi ;;
    repair) RepairStack ;;
    audit) RunAudit ;;
    *) echo "Usage: $0 {powershift|restore|repair|audit}" ;;
esac
