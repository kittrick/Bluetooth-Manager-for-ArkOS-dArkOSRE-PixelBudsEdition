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
UpdateScript() {
    # Check for internet connection
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "\n$T_INTERNET\n\n$T_ACTIVE" 8 50 > "$CURR_TTY"
        return
    fi

    local branch_choice
    branch_choice=$(dialog --backtitle "$T_BACKTITLE" --title "$T_M_UPDATE" \
        --cancel-label "$T_BACK" \
        --menu "\n$T_UP_BRANCH_MSG" 12 50 2 \
        1 "$T_UP_BRANCH_MAIN" \
        2 "$T_UP_BRANCH_DEV" 2>&1 > "$CURR_TTY")
    
    [ $? -ne 0 ] && return

    local branch="main"
    [ "$branch_choice" -eq 2 ] && branch="dev"

    dialog --backtitle "$T_BACKTITLE" --title "$T_M_UPDATE" --infobox "\n$T_UP_CHK" 5 40 > "$CURR_TTY"

    # Define the RAW GitHub URL (Note the %20 for the space in the filename)
    local REPO_RAW_URL="https://raw.githubusercontent.com/kittrick/Bluetooth-Manager-for-ArkOS-dArkOSRE-PixelBudsEdition/${branch}/Bluetooth%20Manager.sh"
ToggleDriver() {
    local CURRENT_DRV=$(lsmod | grep -oE "rtk_btusb|btusb" | head -n1)
    local NEXT_DRV="rtk_btusb"
    [ "$CURRENT_DRV" == "rtk_btusb" ] && NEXT_DRV="btusb"
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_DRV_SW_TITLE" --infobox "$T_DRV_SW_MSG $NEXT_DRV $T_DRV_SW_MSG2" 5 50 > "$CURR_TTY"
    
    sudo modprobe -r rtk_btusb btusb 2>/dev/null
    if ! sudo modprobe "$NEXT_DRV" 2>/dev/null; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "$T_DRV_ERR" 7 50 > "$CURR_TTY"
        sudo modprobe btusb 2>/dev/null
        return
    fi
    
    sudo systemctl restart bluetooth
    sleep 2
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "$T_DRV_SW_SUCC $NEXT_DRV" 7 50 > "$CURR_TTY"
}
