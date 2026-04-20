#!/bin/bash
# -------------------------------------------------------
# Silent Audit: Writes hardware state to a log file
# -------------------------------------------------------
RunAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    
    safe_log() {
        echo "--- $1 ---" >> "$LOG_FILE"
        timeout $3 bash -c "$2" >> "$LOG_FILE" 2>&1
        echo "------------------------------------------" >> "$LOG_FILE"
    }

    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nRunning deep hardware audit..." 6 45 > "$CURR_TTY"

    echo "=== BT SYSTEM AUDIT: $(date) ===" > "$LOG_FILE"
    safe_log "USB DEVICES" "lsusb" 5
    safe_log "USB TOPOLOGY" "lsusb -t" 5
    safe_log "DRIVERS" "lsmod | grep -E 'btusb|rtk_btusb|8821cu|bluetooth'" 2
    safe_log "HCICONFIG" "hciconfig -a" 5
    safe_log "BTMGMT INFO" "btmgmt info" 5
    safe_log "DMESG" "dmesg | grep -iE 'bluetooth|hci0|firmware|bluez' | tail -n 20" 2
    safe_log "PULSEAUDIO" "pactl info | grep 'Default Sink' && pactl list short sinks" 5
    
    echo "--- RAW LE SCAN ---" >> "$LOG_FILE"
    timeout 10 btmgmt find -l >> "$LOG_FILE" 2>&1
    echo "--- END AUDIT ---" >> "$LOG_FILE"
    
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
        dialog --backtitle "$T_BACKTITLE" --title "$T_INTERNET" --msgbox "\n$T_ACTIVE\n\n$T_INTERNET" 8 50 > "$CURR_TTY"
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

    local REPO_RAW_URL="https://raw.githubusercontent.com/kittrick/Bluetooth-Manager-for-ArkOS-dArkOSRE-PixelBudsEdition/${branch}/Bluetooth%20Manager.sh"
    local TEMP_FILE="/tmp/bt_manager_update.sh"

    if wget -q --no-check-certificate -O "$TEMP_FILE" "$REPO_RAW_URL"; then
        if grep -q "#!/bin/bash" "$TEMP_FILE"; then
            cp -f "$TEMP_FILE" "$0"
            chmod +x "$0"
            rm -f "$TEMP_FILE"
            dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "\n$T_UP_SUCC" 7 50 > "$CURR_TTY"
            exec "$0" "$@"
        else
            dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "\n$T_UP_ERR_INV" 7 50 > "$CURR_TTY"
        fi
    else
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "\n$T_UP_ERR_NET" 7 50 > "$CURR_TTY"
    fi
}
