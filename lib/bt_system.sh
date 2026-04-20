#!/bin/bash
# -------------------------------------------------------
# System/Installer Functions
# -------------------------------------------------------

FixBluetoothConfig() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --infobox "\n$T_SYSTEM_FIX" 5 50 > "$CURR_TTY"
    REAL_BT_PATH=$(find /usr -name bluetoothd -type f -executable | head -n 1)
    if [ -n "$REAL_BT_PATH" ]; then
        sudo sed -i "s|^ExecStart=.*|ExecStart=$REAL_BT_PATH --noplugin=sap|" /lib/systemd/system/bluetooth.service
    fi
    for u in ark root pulse; do
        sudo usermod -aG pulse-access,audio,bluetooth,input $u 2>/dev/null
    done
}

ToggleBT() {
    if GetPowerStatus; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ACTION" --infobox "\n  $T_STOPPING" 5 35 > "$CURR_TTY"
        bluetoothctl power off > /dev/null 2>&1
        systemctl stop bluetooth > /dev/null 2>&1
        ForceInternalAudio
    else
        dialog --backtitle "$T_BACKTITLE" --title "$T_ACTION" --infobox "\n  $T_POWERING" 5 35 > "$CURR_TTY"
        EnableBT
    fi         
}

PowerShiftBT() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_PWR_TITLE" --infobox "Performing surgical hardware shift (20s).\nES will restart if successful." 6 50 > "$CURR_TTY"
    
    local LOG="/tmp/bt_audit.log"
    echo "--- POWER SHIFT START $(date) ---" >> "$LOG"

    # 1. Stop all Bluetooth services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    
    # 2. Create a temporary hard blacklist to prevent driver fighting
    echo "blacklist 8821cu" | sudo tee /etc/modprobe.d/bt_temp_block.conf > /dev/null
    echo "blacklist btusb" | sudo tee -a /etc/modprobe.d/bt_temp_block.conf > /dev/null
    
    # 3. Kill the kernel modules
    sudo /sbin/modprobe -r 8821cu 2>/dev/null
    sudo /sbin/modprobe -r btusb 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb 2>/dev/null
    sleep 2
    
    # 4. Explicitly unbind all drivers from the dongle interfaces (1-1:1.0, 1.1, 1.2)
    # We use a more robust search for the unbind files
    for i in 0 1 2; do
        local target="1-1:1.$i"
        find /sys/bus/usb/drivers/ -name "$target" | while read -r drv_iface; do
            local drv_dir=$(dirname "$drv_iface")
            echo "Unbinding $target from $(basename $drv_dir)" >> "$LOG"
            echo "$target" | sudo tee "$drv_dir/unbind" >/dev/null 2>&1
        done
    done
    sleep 2

    # 5. Load ONLY the Realtek Bluetooth Driver
    sudo /sbin/modprobe rtk_btusb 2>>"$LOG"
    sleep 3
    
    # 6. Bring up the interface
    if command -v hciconfig >/dev/null; then
        sudo hciconfig hci0 up 2>>"$LOG"
    fi
    sleep 2
    
    # 7. Start services
    sudo systemctl start bluetooth
    sleep 5
    
    # 8. Check for success and trigger ES restart if Bluetooth is now ON
    if GetPowerStatus; then
        echo "SUCCESS: Bluetooth is ON. Restarting EmulationStation..." >> "$LOG"
        sudo bluetoothctl power on >> "$LOG" 2>&1
        
        # Trigger EmulationStation restart to refresh UI
        sudo systemctl restart emulationstation
        
        dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "Bluetooth Enabled! EmulationStation is restarting." 8 50 > "$CURR_TTY"
    else
        echo "FAILURE: Bluetooth still OFF." >> "$LOG"
        # Cleanup blacklist on failure so user isn't stuck
        sudo rm -f /etc/modprobe.d/bt_temp_block.conf
        dialog --backtitle "$T_BACKTITLE" --title "$T_FAILED" --msgbox "Shift failed. Hardware did not initialize. Check bt_audit.log." 8 50 > "$CURR_TTY"
    fi
    
    echo "--- POWER SHIFT END ---" >> "$LOG"
}

RestoreWiFi() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_RES_TITLE" --infobox "$T_RES_MSG1" 5 40 > "$CURR_TTY"
    sudo bluetoothctl power off > /dev/null 2>&1
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb btusb 2>/dev/null
    sleep 1
    if [ -e "/sys/bus/usb/drivers/usb/1-1" ]; then
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/unbind > /dev/null
        sleep 1
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/bind > /dev/null
    fi
    sudo /sbin/modprobe 8821cu
    sleep 2
    dialog --backtitle "$T_BACKTITLE" --title "$T_RES_TITLE" --msgbox "$T_RES_MSG2" 8 40 > "$CURR_TTY"
}

RepairStack() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_REPAIR_TITLE" --infobox "$T_REPAIR_MSG" 6 50 > "$CURR_TTY"
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    sudo /sbin/modprobe -r btusb rtk_btusb 8821cu 2>/dev/null
    sleep 2
    sudo /sbin/modprobe btusb 2>/dev/null
    sudo /sbin/modprobe rtk_btusb 2>/dev/null
    sudo /sbin/modprobe 8821cu 2>/dev/null
    sudo systemctl start bluetooth
    sleep 5
    sudo bluetoothctl power on
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "$T_REPAIR_DONE" 8 45 > "$CURR_TTY"
}

RunUninstall() {
    # -- Force audio back to internal speaker ---
    ForceInternalAudio
    sleep 0.1
    # --- Stop and Disable Services ---
    for svc in bt-volume-monitor.service bt-sink-switch.service reset-alsa.service pulseaudio.service bluetooth.service; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then systemctl stop "$svc" 2>/dev/null; fi
    done
}

UninstallerMenu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog --output-fd 1 \
            --backtitle "$T_BACKTITLE2" --title "$T_MAIN_TITLE2" --cancel-label "$T_BACK" \
            --menu "$T_MENU_MSG" 10 50 2 \
            1 "$T_RUN" 2 "$T_FORGET_MENU" 2>"$CURR_TTY")
            [ $? -ne 0 ] && return
        case $CHOICE in
            1) RunUninstall ;;
            2) ForgetAllDevices ;;
            *) return ;;
        esac
    done
}
