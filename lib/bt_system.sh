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
    dialog --backtitle "$T_BACKTITLE" --title "$T_PWR_TITLE" --infobox "Performing autonomous diagnostic shift (20s)." 6 50 > "$CURR_TTY"
    
    local LOG="/tmp/bt_audit.log"
    echo "--- POWER SHIFT START $(date) ---" >> "$LOG"

    # 1. Stop all services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    
    # 2. Kill the kernel modules entirely
    sudo /sbin/modprobe -r btusb rtk_btusb 8821cu 2>/dev/null
    sleep 2
    
    # 3. Handle specific unbind for RTL8821CU (Bus 001, Port 1 is standard for R36S)
    # We unbind both potentially active drivers from the known interfaces
    for i in 0 1 2; do
        if [ -e "/sys/bus/usb/drivers/btusb/1-1:1.$i" ]; then
            echo "Unbinding 1-1:1.$i from btusb" >> "$LOG"
            echo "1-1:1.$i" | sudo tee /sys/bus/usb/drivers/btusb/unbind >/dev/null 2>&1
        fi
        if [ -e "/sys/bus/usb/drivers/rtl8821cu/1-1:1.$i" ]; then
            echo "Unbinding 1-1:1.$i from rtl8821cu" >> "$LOG"
            echo "1-1:1.$i" | sudo tee /sys/bus/usb/drivers/rtl8821cu/unbind >/dev/null 2>&1
        fi
    done
    sleep 1

    # 4. Load the Realtek Bluetooth Driver
    sudo /sbin/modprobe rtk_btusb 2>>"$LOG"
    sleep 2
    
    # 5. Manually bind the interfaces to rtk_btusb if they didn't auto-bind
    for i in 0 1; do
        if [ ! -e "/sys/bus/usb/drivers/rtk_btusb/1-1:1.$i" ]; then
            echo "Force binding 1-1:1.$i to rtk_btusb" >> "$LOG"
            echo "1-1:1.$i" | sudo tee /sys/bus/usb/drivers/rtk_btusb/bind >/dev/null 2>&1
        fi
    done
    
    # 6. Bring up the interface
    if command -v hciconfig >/dev/null; then
        sudo hciconfig hci0 up 2>>"$LOG"
        sudo hciconfig hci0 sscan 2>>"$LOG"
    fi
    sleep 2
    
    # 7. Restart services
    sudo systemctl start bluetooth
    sleep 5
    sudo bluetoothctl power on >> "$LOG" 2>&1
    
    echo "HCI Status after shift: $(hciconfig hci0 2>/dev/null)" >> "$LOG"
    echo "--- POWER SHIFT END ---" >> "$LOG"
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "Shift complete. Check bt_audit.log." 8 50 > "$CURR_TTY"
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
