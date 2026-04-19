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

# -------------------------------------------------------
# Dependency Check
# -------------------------------------------------------
CheckDeps() {
    [ -f "$INSTALLED_FLAG" ] && return
    
    local REQUIRED_PACKAGES=("bluez" "pulseaudio-module-bluetooth" "pulseaudio" "alsa-utils" "evtest" "libasound2-plugins" "dbus-user-session" "dbus-x11" "bluez-tools")
    local MISSING_PACKAGES=()
    
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then MISSING_PACKAGES+=("$pkg"); fi
    done

    if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
        if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
            dialog --backtitle "$T_BACKTITLE" --title "$T_INTERNET" --msgbox "\n$T_ACTIVE:\n\n${MISSING_PACKAGES[*]}" 8 50 > "$CURR_TTY"
            ExitMenu
        fi

        (
            current_p=0

            progress_while_running() {
                local pid=$1
                local target=$2
                local msg=$3

                while kill -0 $pid 2>/dev/null; do
                    if [ $current_p -lt $target ]; then
                        current_p=$((current_p + 1))
                        echo "$current_p"
                        echo "XXX"; echo "$msg"; echo "XXX"
                    fi
                    sleep 0.15 
                done

                current_p=$target
                echo "$current_p"
                echo "XXX"; echo "$msg"; echo "XXX"
            }

            apt-get update -y >/dev/null 2>&1 &
            progress_while_running $! 25 "$T_UPDATE"

            TOTAL=${#MISSING_PACKAGES[@]}
            COUNT=0
            for pkg in "${MISSING_PACKAGES[@]}"; do
                COUNT=$((COUNT + 1))
               
                start_section=$(( 25 + ( (COUNT - 1) * 70 / TOTAL ) ))
                end_section=$(( 25 + ( COUNT * 70 / TOTAL ) ))
                
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1 &
                progress_while_running $! $end_section "$T_PACKAGE $pkg ($COUNT/$TOTAL)..."
            done

            while [ $current_p -lt 100 ]; do
                current_p=$((current_p + 1))
                echo "$current_p"
                echo "XXX"; echo "$T_COMPLETE"; echo "XXX"
                sleep 0.05
            done
            
        ) | dialog --backtitle "$T_BACKTITLE" --title "$T_DEPS" --gauge "\n$T_INIT" 8 50 0 > "$CURR_TTY"
    fi
}
