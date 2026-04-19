# Initialize environment defaults if not provided
: "${CURR_TTY:=/dev/tty1}"
: "${T_BACKTITLE:=Bluetooth Manager}"
: "${T_PWR_TITLE:=Power-Shift}"
: "${T_SUCCESS:=Success}"
: "${T_ERR_TITLE:=Error}"
: "${T_READ_ERR:=Read Error}"
: "${T_AUD_TITLE:=Audit Complete}"
: "${T_AUD_MSG:=Audit saved.}"
: "${T_RES_TITLE:=Restore WiFi}"
: "${T_RES_MSG1:=Restoring...}"
: "${T_RES_MSG2:=Done.}"
: "${T_REPAIR_TITLE:=Repair Bluetooth}"
: "${T_REPAIR_MSG:=Resetting...}"
: "${T_REPAIR_DONE:=Repaired.}"

# -------------------------------------------------------
ReadAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    local chunk_size=10
    local start_line=1

    if [ ! -f "$LOG_FILE" ]; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "$T_READ_ERR" 8 45 > "$CURR_TTY"
        return
    fi

    total_lines=$(wc -l < "$LOG_FILE")

    while [ "$start_line" -le "$total_lines" ]; do
        printf "\033[H\033[2J" > "$CURR_TTY"
        echo "=== READING AUDIT (Lines $start_line to $((start_line + chunk_size - 1))) ===" > "$CURR_TTY"
        echo "----------------------------------------------------" > "$CURR_TTY"
        
        sed -n "${start_line},$((start_line + chunk_size - 1))p" "$LOG_FILE" > "$CURR_TTY"
        
        echo -e "\n----------------------------------------------------" > "$CURR_TTY"
        echo "WAITING 10 SECONDS... (DO NOT PRESS BUTTONS)" > "$CURR_TTY"
        
        sleep 10
        start_line=$((start_line + chunk_size))
    done

    printf "\033[H\033[2J" > "$CURR_TTY"
    echo "END OF AUDIT. RETURNING TO MENU..." > "$CURR_TTY"
    sleep 2
}

# -------------------------------------------------------
# Power-Shift: Kill Wi-Fi, Force Bluetooth
# -------------------------------------------------------
PowerShiftBT() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_PWR_TITLE" --infobox "Performing autonomous diagnostic shift (20s)." 6 50 > "$CURR_TTY"
    
    # 1. Stop all services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    
    # 2. Kill the kernel modules entirely
    sudo /sbin/modprobe -r btusb 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb 2>/dev/null
    sudo /sbin/modprobe -r 8821cu 2>/dev/null
    sleep 2
    
    # 3. Force binding rtk_btusb
    sudo /sbin/modprobe rtk_btusb 2>>"/home/ark/bt_audit.log"

    # Wait for the driver to actually bind
    echo "Waiting for rtk_btusb bind..." >> "/home/ark/bt_audit.log"
    for i in {1..10}; do
        if lsmod | grep -q "rtk_btusb"; then
            echo "rtk_btusb loaded successfully." >> "/home/ark/bt_audit.log"
            break
        fi
        sleep 1
    done
    sleep 3
    
    # 4. Bring up the interface
    if command -v hciconfig >/dev/null; then
        sudo hciconfig hci0 up 2>>"/home/ark/bt_audit.log"
    fi
    sleep 2
    
    # 5. Restart services
    sudo systemctl start bluetooth
    sleep 5
    sudo bluetoothctl power on
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "Shift complete. Check bt_audit.log." 8 50 > "$CURR_TTY"
}

# -------------------------------------------------------
# Restore: Kill Bluetooth, Re-enable Wi-Fi
# -------------------------------------------------------
RestoreWiFi() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_RES_TITLE" --infobox "$T_RES_MSG1" 5 40 > "$CURR_TTY"
    
    # 1. Kill Bluetooth processes and drivers
    sudo bluetoothctl power off > /dev/null 2>&1
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb btusb 2>/dev/null
    sleep 1
    
    # 2. Forceful USB Reset to clear any BT firmware hangs
    if [ -e "/sys/bus/usb/drivers/usb/1-1" ]; then
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/unbind > /dev/null
        sleep 1
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/bind > /dev/null
        sleep 1
    fi
    
    # 3. Reload Wi-Fi Driver
    sudo /sbin/modprobe 8821cu
    
    # 4. Give the system a moment to find the network
    sleep 2
    dialog --backtitle "$T_BACKTITLE" --title "$T_RES_TITLE" --msgbox "$T_RES_MSG2" 8 40 > "$CURR_TTY"
}

# -------------------------------------------------------
# Repair Bluetooth Stack
# -------------------------------------------------------
RepairStack() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_REPAIR_TITLE" --infobox "$T_REPAIR_MSG" 6 50 > "$CURR_TTY"
    
    # Stop services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    
    # Force unload
    sudo /sbin/modprobe -r btusb rtk_btusb 8821cu 2>/dev/null
    sleep 2
    
    # Reload modules
    sudo /sbin/modprobe btusb 2>/dev/null
    sudo /sbin/modprobe rtk_btusb 2>/dev/null
    sudo /sbin/modprobe 8821cu 2>/dev/null
    
    # Restart
    sudo systemctl start bluetooth
    sleep 5
    sudo bluetoothctl power on
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "$T_REPAIR_DONE" 8 45 > "$CURR_TTY"
}

# -------------------------------------------------------
# Silent Audit: Writes hardware state to a log file
# -------------------------------------------------------
RunAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    local PA_CMD="sudo -u ark XDG_RUNTIME_DIR=/run/user/${ARK_UID} PULSE_SERVER=unix:/run/user/${ARK_UID}/pulse/native pactl"
    
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
    safe_log "PULSEAUDIO" "$PA_CMD info | grep 'Default Sink' && $PA_CMD list short sinks" 5
    
    echo "--- RAW LE SCAN ---" >> "$LOG_FILE"
    timeout 10 btmgmt find -l >> "$LOG_FILE" 2>&1
    echo "--- END AUDIT ---" >> "$LOG_FILE"
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_AUD_TITLE" --msgbox "Audit complete. Check bt_audit.log." 8 45 > "$CURR_TTY"
}
