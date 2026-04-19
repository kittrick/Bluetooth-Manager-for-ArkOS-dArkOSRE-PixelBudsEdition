RunAudit() {
    local LOG_FILE="/home/ark/bt_audit.log"
    local PA_CMD="sudo -u ark XDG_RUNTIME_DIR=/run/user/${ARK_UID} PULSE_SERVER=unix:/run/user/${ARK_UID}/pulse/native pactl"
    
    # Function to log with timeout
    safe_log() {
        local msg="$1"
        local cmd="$2"
        local tout="${3:-5}"
        echo "LOGGING: $msg"
        echo "--- $msg ---" >> "$LOG_FILE"
        timeout $tout bash -c "$cmd" >> "$LOG_FILE" 2>&1
        echo "------------------------------------------" >> "$LOG_FILE"
    }
ReadAudit() {
    local LOG_FILE="/home/ark/bt_audit.log"
    local total_lines
    local chunk_size=10
    local start_line=1

    if [ ! -f "$LOG_FILE" ]; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "$T_READ_ERR" 8 45 > "$CURR_TTY"
        return
    fi

    total_lines=$(wc -l < "$LOG_FILE")

    # The Teleprompter Loop
    while [ "$start_line" -le "$total_lines" ]; do
        printf "\033[H\033[2J" > "$CURR_TTY"
        echo "=== READING AUDIT (Lines $start_line to $((start_line + chunk_size - 1))) ===" > "$CURR_TTY"
        echo "----------------------------------------------------" > "$CURR_TTY"
        
        # Display the chunk
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
ToggleDriver() {
    local CURRENT_DRV=$(lsmod | grep -oE "rtk_btusb|btusb" | head -n1)
    local NEXT_DRV="rtk_btusb"
    [ "$CURRENT_DRV" == "rtk_btusb" ] && NEXT_DRV="btusb"
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_DRV_SW_TITLE" --infobox "$T_DRV_SW_MSG $NEXT_DRV $T_DRV_SW_MSG2" 5 50 > "$CURR_TTY"
    
    sudo /sbin/modprobe -r rtk_btusb btusb 2>/dev/null
    if ! sudo /sbin/modprobe "$NEXT_DRV" 2>/dev/null; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "$T_DRV_ERR" 7 50 > "$CURR_TTY"
        sudo /sbin/modprobe btusb 2>/dev/null
        return
    fi
    
    sudo systemctl restart bluetooth
    sleep 2
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "$T_DRV_SW_SUCC $NEXT_DRV" 7 50 > "$CURR_TTY"
}
SystemSetup() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_SETUP_TITLE" --infobox "$T_SETUP_MSG" 6 50 > "$CURR_TTY"
    FixBluetoothConfig
    dialog --backtitle "$T_BACKTITLE" --title "$T_SETUP_DONE_TITLE" --msgbox "$T_SETUP_DONE_MSG" 12 55 > "$CURR_TTY"
}
RepairStack() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_REPAIR_TITLE" --infobox "$T_REPAIR_MSG" 6 50 > "$CURR_TTY"

    # 1. Kill all Bluetooth processes and stop services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    sudo pkill -9 bluetoothctl 2>/dev/null

    # 2. Reset the hardware (Force unbind/bind if paths are known, or just driver cycle)
    sudo /sbin/modprobe -r 
 rtk_btusb btusb 8821cu 2>/dev/null
    sleep 2

    # 3. Clear BlueZ cache (Careful: removes paired devices, but often needed for visibility bugs)
    # sudo rm -rf /var/lib/bluetooth/* # We'll skip this to avoid data loss unless asked

    # 4. Reload drivers
    sudo modprobe btusb 2>/dev/null
    sudo modprobe rtk_btusb 2>/dev/null
    sudo modprobe 8821cu 2>/dev/null

    # 5. Bring adapter up manually
    sudo hciconfig hci0 up 2>/dev/null
    sudo hciconfig hci0 sscan 2>/dev/null
    sudo hciconfig hci0 pscan 2>/dev/null

    # 6. Restart services
    sudo systemctl start bluetooth
    sleep 2
    sudo systemctl start bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null

    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "$T_REPAIR_DONE" 8 45 > "$CURR_TTY"
}
