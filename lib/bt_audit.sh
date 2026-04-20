#!/bin/bash
# -------------------------------------------------------
# BT Audit Utilities
# -------------------------------------------------------

RunAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    echo "=== BT SYSTEM AUDIT: $(date) ===" > "$LOG_FILE"
    lsusb >> "$LOG_FILE" 2>&1
    lsusb -t >> "$LOG_FILE" 2>&1
    lsmod | grep -E 'btusb|rtk_btusb|8821cu|bluetooth' >> "$LOG_FILE" 2>&1
    hciconfig -a >> "$LOG_FILE" 2>&1
    dialog --backtitle "$T_BACKTITLE" --title "$T_AUD_TITLE" --msgbox "Audit complete. Check $LOG_FILE." 8 45 > "$CURR_TTY"
}

ReadAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    if [ ! -f "$LOG_FILE" ]; then dialog --msgbox "No audit found." 5 30 > "$CURR_TTY"; return; fi
    dialog --backtitle "$T_BACKTITLE" --title "Audit Log" --textbox "$LOG_FILE" 20 60 > "$CURR_TTY"
}

SystemSetup() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_SETUP_TITLE" --infobox "$T_SETUP_MSG" 6 50 > "$CURR_TTY"
    FixBluetoothConfig
    dialog --backtitle "$T_BACKTITLE" --title "$T_SETUP_DONE_TITLE" --msgbox "$T_SETUP_DONE_MSG" 12 55 > "$CURR_TTY"
}
