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
    dialog --backtitle "$T_BACKTITLE" --title "$T_PWR_TITLE" --infobox "Performing HARD hardware reset (20s).\nES will restart if successful." 6 50 > "$CURR_TTY"
    
    local LOG="/tmp/bt_audit.log"
    echo "--- POWER SHIFT START $(date) ---" >> "$LOG"

    # 0. Stop services and blacklist
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    echo "blacklist 8821cu" | sudo tee /etc/modprobe.d/bt_temp_block.conf > /dev/null
    echo "blacklist btusb" | sudo tee -a /etc/modprobe.d/bt_temp_block.conf > /dev/null
    
    # 1. Kill kernel modules
    sudo /sbin/modprobe -r 8821cu 2>/dev/null
    sudo /sbin/modprobe -r btusb 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb 2>/dev/null
    sleep 2

    # 2. SOFTWARE UNPLUG: Disable the USB device entirely
    if [ -e "/sys/bus/usb/devices/1-1/authorized" ]; then
        echo "De-authorizing USB device 1-1 (Hardware Reset)" >> "$LOG"
        echo 0 | sudo tee /sys/bus/usb/devices/1-1/authorized >/dev/null
        sleep 3
        # SOFTWARE RE-PLUG
        echo 1 | sudo tee /sys/bus/usb/devices/1-1/authorized >/dev/null
        sleep 3
    fi

    # 3. Force rtk_btusb to recognize the ID
    sudo /sbin/modprobe rtk_btusb
    echo "0bda c820" | sudo tee /sys/bus/usb/drivers/rtk_btusb/new_id >/dev/null 2>&1
    sleep 2
    
    # 4. Bring up the interface
    sudo hciconfig hci0 up 2>>"$LOG"
    sleep 2
    
    # 5. Start services
    sudo systemctl start bluetooth
    sleep 5
    
    # 6. Check for success and trigger ES restart
    if GetPowerStatus; then
        echo "SUCCESS: Bluetooth is ON." >> "$LOG"
        sudo bluetoothctl power on >> "$LOG" 2>&1
        sudo systemctl restart emulationstation
        dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "Bluetooth Enabled! EmulationStation is restarting." 8 50 > "$CURR_TTY"
    else
        echo "FAILURE: Bluetooth still OFF. Dmesg below:" >> "$LOG"
        dmesg | tail -n 20 >> "$LOG"
        dialog --backtitle "$T_BACKTITLE" --title "$T_FAILED" --msgbox "Shift failed. Check bt_audit.log for firmware errors." 8 50 > "$CURR_TTY"
    fi
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
