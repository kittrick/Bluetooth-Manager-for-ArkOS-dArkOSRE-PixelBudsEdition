GetPowerStatus() {
    # Check if Bluetooth daemon is active
    if ! systemctl is-active --quiet bluetooth; then return 1; fi
    
    # Check if a controller is available
    if ! echo "list" | bluetoothctl | grep -q "Controller"; then return 1; fi
    
    # Check if Powered: yes
    if ! echo "show" | bluetoothctl | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Powered: yes"; then return 1; fi
    return 0
}
GetConnectedName() {
    local found_name=""
    found_name=$(timeout 3 bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
        if timeout 2 bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            echo "$name"
            break
        fi
    done)
    echo "${found_name:-$T_NONE}"
}
EnsurePermissions() {
    if [ ! -f "$INSTALLED_FLAG" ]; then
        FixBluetoothConfig
        touch "$INSTALLED_FLAG"
        if dialog --backtitle "$T_BACKTITLE" --title "$T_REBOOT_TITLE" --yesno "$T_REBOOT_MSG" 6 50 > "$CURR_TTY"; then
            reboot
        fi
    fi
}
