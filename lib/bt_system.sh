#!/bin/bash
# -------------------------------------------------------
# System/Installer Functions
# -------------------------------------------------------
FixBluetoothConfig() {
    # ... logic for FixBluetoothConfig ...
}

FixVolumeScript() {
    # ... logic for FixVolumeScript ...
}

EnableBT() {
    # ... logic for EnableBT ...
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

AutoEnableBT() {
    if ! GetPowerStatus; then
        EnableBT
    fi
}

GetInternalSink() {
    local sink
    sink=$(pactl --server=unix:${PULSE_SOCKET} list short sinks 2>/dev/null | grep -v bluez | grep -v auto_null | awk '{print $2}' | head -n1)
    echo "${sink:-internal_speaker}"
}

CheckPulse() {
    export XDG_RUNTIME_DIR=/run/user/${ARK_UID}
    export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

    if ! sudo -u ark XDG_RUNTIME_DIR=/run/user/${ARK_UID} pactl info >/dev/null 2>&1; then
        sudo -u ark XDG_RUNTIME_DIR=/run/user/${ARK_UID} pulseaudio --start
    fi
    
    sleep 0.1
    
    local PA_CMD="pactl --server=unix:$PULSE_SOCKET"
    $PA_CMD list short modules 2>/dev/null | grep -q module-bluetooth-policy || \
        $PA_CMD load-module module-bluetooth-policy > /dev/null 2>&1
    $PA_CMD list short modules 2>/dev/null | grep -q module-bluetooth-discover || \
        $PA_CMD load-module module-bluetooth-discover > /dev/null 2>&1
}

ForgetAllDevices() {
    ask_s_gui "$T_FORGET_TITLE" "$T_FORGET_MSG"
    if [ $? -eq 0 ]; then
        infobox_gui "$T_FORGETTING_TITLE" "$T_FORGETTING_MSG"
        bluetoothctl devices | awk '{print $2}' | while read -r mac; do
            bluetoothctl remove "$mac" > /dev/null 2>&1
        done
        rm -rf "/var/lib/bluetooth/"*/
        sleep 0.5
        info_gui "$T_FORGOTTEN_TITLE" "$T_FORGOTTEN_MSG"
    fi
}

UninstallerMenu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog --output-fd 1 \
            --backtitle "$T_BACKTITLE2" \
            --title "$T_MAIN_TITLE2" \
            --cancel-label "$T_BACK" \
            --menu "$T_MENU_MSG" 10 50 2 \
            1 "$T_RUN" \
            2 "$T_FORGET_MENU" \
            2>"$CURR_TTY")
            [ $? -ne 0 ] && return

        case $CHOICE in
            1) RunUninstall ;;
            2) ForgetAllDevices ;;
            *) return ;;
        esac
    done
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
