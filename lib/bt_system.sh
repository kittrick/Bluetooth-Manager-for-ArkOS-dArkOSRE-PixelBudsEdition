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
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    sudo /sbin/modprobe -r btusb rtk_btusb 8821cu 2>/dev/null
    sleep 2
    sudo /sbin/modprobe rtk_btusb 2>>"/tmp/bt_audit.log"
    sleep 5
    if command -v hciconfig >/dev/null; then sudo hciconfig hci0 up 2>>"/tmp/bt_audit.log"; fi
    sudo systemctl start bluetooth
    sleep 5
    sudo bluetoothctl power on
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
