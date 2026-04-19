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

# -------------------------------------------------------
# Power-Shift: Kill Wi-Fi, Force Bluetooth
# -------------------------------------------------------
PowerShiftBT() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_PWR_TITLE" --infobox "Performing autonomous diagnostic shift (20s)." 6 50 > "$CURR_TTY"
    
    # 1. Stop all services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    
    # 2. Kill the kernel modules entirely
    sudo modprobe -r btusb 2>/dev/null
    sudo modprobe -r rtk_btusb 2>/dev/null
    sudo modprobe -r 8821cu 2>/dev/null
    sleep 2
    
    # 3. Force binding rtk_btusb
    sudo /sbin/modprobe rtk_btusb 2>>"/home/ark/bt_audit.log"

    # Wait for the driver to actually bind to the interface
    echo "Waiting for rtk_btusb bind..." >> "/home/ark/bt_audit.log"
    for i in {1..10}; do
        if lsmod | grep -q "rtk_btusb"; then
            echo "rtk_btusb loaded successfully." >> "/home/ark/bt_audit.log"
            break
        fi
        sleep 1
    done
    sleep 3

    
    # 4. Bring up the interface using the system path
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
    if [ -e "/sys/bus/usb/devices/1-1" ]; then
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/unbind > /dev/null
        sleep 1
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/bind > /dev/null
        sleep 1
    fi
    
    # 3. Reload Wi-Fi Driver
    sudo modprobe 8821cu
    
    # 4. Give the system a moment to find the network
    sleep 2
