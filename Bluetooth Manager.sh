#!/bin/bash

# Load external utilities
export T_BACKTITLE CURR_TTY; source "$(dirname "$0")/lib/bt_utils.sh"
source "$(dirname "$0")/lib/locale.sh"
source "$(dirname "$0")/lib/bt_ui.sh"
source "$(dirname "$0")/lib/bt_audio.sh"
source "$(dirname "$0")/lib/bt_keyboard.sh"
source "$(dirname "$0")/lib/bt_core.sh"
source "$(dirname "$0")/lib/bt_system.sh"
source "$(dirname "$0")/lib/bt_audit.sh"

#-------------------------------------#
#           BT Manager 3.6            #
#            By djparent              #
#             A fork of               #
#         Bluetooth Manager           #
#           dArkOS Edition            #
#             by Jason                #
#-------------------------------------#

# Copyright (c) 2026 Jason3x
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# -------------------------------------------------------
# Root privileges check
# -------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# -------------------------------------------------------
# Variables
# -------------------------------------------------------
SYSTEM_LANG=""
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
ARK_UID=$(id -u ark)
SCRIPT_NAME="$(basename "$0")"
ASOUNDRC="/home/ark/.asoundrc"
ASOUNDRC_BAK="/home/ark/.asoundrcbak"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PULSE_SOCKET="/run/user/${ARK_UID}/pulse/native"
INSTALLED_FLAG="/home/ark/.bt_manager_installed"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"

# -------------------------------------------------------
# Initialization
# -------------------------------------------------------
export TERM=linux
mkdir -p /run/user/${ARK_UID}
chown ark:ark /run/user/${ARK_UID}
chmod 700 /run/user/${ARK_UID}
export XDG_RUNTIME_DIR=/run/user/${ARK_UID}
export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
fi
# -------------------------------------------------------
# Default configuration : EN
# -------------------------------------------------------
T_BACKTITLE="Bluetooth Manager by Jason & djparent"
T_STARTING="Starting Bluetooth Manager ...\nPlease wait."
T_ERR_TITLE="Error"
T_STOPPING="Stopping Bluetooth..."
T_STARTING_BT="Starting Bluetooth..."
T_ACTION="Action"
T_BT_DISABLED="Bluetooth disabled.\nEnable it first."
T_SCAN_TITLE="Scanning"
T_NO_DEVICE="No named device detected."
T_INFO="Info"
T_NEARBY="Bluetooth nearby"
T_BACK="Back"
T_CHOOSE_DEV="Choose a device:"
T_SUCCESS="Success"
T_CONNECTED="is connected"
T_FAILED="Failed"
T_FAIL_CONNECT="Unable to connect to"
T_FAIL_DISCONNECT="Unable to disconnect"
T_FAIL_MSG="Ensure device is in pairing mode."
T_NO_KNOWN="No known devices."
T_KNOWN_DEV="Known Devices"
T_CONNECT_TO="Connect to:"
T_CONNECTING_TO="Connecting to"
T_NOTHING_DEL="Nothing to delete."
T_DELETE_TITLE="Delete"
T_CHOOSE_DEL="Choose device to forget:"
T_FORGOTTEN="Device forgotten."
T_MAIN_TITLE="Main Menu"
T_QUIT="Quit"
T_STATUS="Bluetooth Status"
T_CONN_TO="Connected to"
T_NONE="None"
T_ENABLE="Enable"
T_DISABLE="Disable"
T_M_SCAN="Scan and Connect"
T_M_KNOWN="Known Devices"
T_M_FORGET="Forget a Device"
T_M_QUIT="Quit"
T_FIXING_AUDIO="Fixing audio protocols..."
T_PAIRING="Pairing in progress..."
T_INTERNET="Internet Required"
T_ACTIVE="An active internet connection is required to install components" 
T_UPDATE="Updating package lists..."
T_PACKAGE="Installing" 
T_COMPLETE="Installation complete !"
T_DEPS="Dependencies" 
T_INIT="Initializing..."
T_ON="ON"
T_OFF="OFF"
T_SCAN_INIT="Initializing Bluetooth..."
T_SCAN_PROCESS="Scanning airwaves..."
T_SCAN_RESOLV="Resolving device names..."
T_SCAN_START="Starting scan..."
T_CONN_TITLE="Connection"
T_PROCESS="Processing..."
T_POWERING="Powering on adapter..."
T_SYSTEM_FIX="Applying system fixes..."
T_DEV_DEFAULT="Device"
T_M_DISCONNECT="Disconnect a device"
T_DISCONNECTED="Disconnected"
T_UNKNOWN="Unknown Device"
T_REBOOT_TITLE="Reboot Required"
T_BACKTITLE2="Bluetooth Manager Uninstaller"
T_STARTING2="Starting Uninstaller...\nPlease wait."
T_MAIN_TITLE2="Uninstaller Menu"
T_MENU_MSG="\nYour next choice defines your destiny."
T_RUN="Run Uninstaller"
T_EXIT="Exit"
T_STEP1_TITLE="Step 1/7"
T_STEP1_MSG="\nStopping and disabling services..."
T_STEP2_TITLE="Step 2/7"
T_STEP2_MSG="\nRemoving installed files..."
T_STEP3_TITLE="Step 3/7"
T_STEP3_MSG="\nRestoring /etc/bluetooth/main.conf..."
T_STEP4_TITLE="Step 4/7"
T_STEP4_MSG="\nRestoring /etc/pulse/system.pa..."
T_STEP5_TITLE="Step 5/7"
T_STEP5_MSG="\nRestoring bluetooth.service..."
T_STEP6_TITLE="Step 6/7"
T_STEP6_MSG="\nRestoring RetroArch audio driver..."
T_STEP7_TITLE="Step 7/7"
T_STEP7_MSG="\nReloading systemd daemon..."
T_PKG_TITLE="Remove Packages?"
T_PKG_MSG="The installer may have installed:\n  - bluez\n  - bluez-tools\n  - pulseaudio\n  - pulseaudio-module-bluetooth\n  - dbus-x11\n  - libasound2-plugins\n\nWARNING: May be used by other software.\n\nRemove them now?"
T_REMOVING_TITLE="Removing Packages"
T_REMOVING_MSG="\nRemoving packages..."
T_DONE_TITLE="Uninstall Complete"
T_OPT_MSG="\n - installed packages removed"
T_DONE_MSG="What was undone:\n\n - installed services removed%PKG%\n - device audio drivers restored\n - install flag removed\n\nA reboot is required to restore volume function."
T_REBOOT_TITLE="Reboot?"
T_REBOOT_MSG="\nReboot now to apply all changes?"
T_REBOOTING_TITLE="Rebooting"
T_REBOOTING_MSG="\nRebooting..."
T_FORGET_MENU="Forget All Devices"
T_FORGET_TITLE="Forget All Devices?"
T_FORGET_MSG="\nWould you like to forget all previously\nconnected Bluetooth devices?"
T_FORGETTING_TITLE="Forgetting Devices"
T_FORGETTING_MSG="\nRemoving all paired devices..."
T_FORGOTTEN_TITLE="Done"
T_FORGOTTEN_MSG="\nAll paired devices have been removed."
T_RESCAN="Rescan"
T_M_TOGGLE_DRIVER="Toggle Driver (Generic vs Realtek)"
T_M_AUDIT="Perform System Audit"
T_M_TEST_CHIME="Play Test Chime"
T_M_READ_AUDIT="Read Last Audit (30s Freeze)"
T_M_POWERSHIFT="Power-Shift (Kill Wi-Fi / Force BT)"
T_M_RESTORE_WIFI="Restore Wi-Fi (Kill BT / Wi-Fi ON)"
T_M_SYSTEM_SETUP="System Setup"
T_SETUP_TITLE="System Setup"
T_SETUP_MSG="\nConfiguring system for ultimate Bluetooth performance...\nThis will take a moment."
T_SETUP_DONE_TITLE="Setup Complete"
T_SETUP_DONE_MSG="\nSystem Setup is complete!\n\nAll PulseAudio rules, background daemons, and UI icons have been installed and activated."
T_DRV_ERR="rtk_btusb driver not found! Staying on Generic."
T_DRV_SW_TITLE="Driver Switch"
T_DRV_SW_MSG="\nSwitching preference to "
T_DRV_SW_MSG2="...\nResetting hardware (takes ~10s)..."
T_DRV_SW_SUCC="System is now configured for:\n"
T_AUD_TITLE="Audit Complete"
T_AUD_MSG="\nAudit saved to log.\nUse 'Read Last Audit' to view."
T_READ_ERR="\nNo audit file found."
T_PWR_TITLE="Power-Shift"
T_PWR_MSG1="\nDisabling Wi-Fi & Forcing BT..."
T_PWR_MSG2="\nWi-Fi is now OFF.\nCheck Status and try Scanning."
T_RES_TITLE="Restore Wi-Fi"
T_RES_MSG1="\nDisabling BT & Restoring Wi-Fi..."
T_RES_MSG2="\nWi-Fi is being restored.\nGive it a few seconds to reconnect."
T_TST_TITLE="Audio Test"
T_TST_MSG1="\nPushing a native 440Hz test tone through PulseAudio...\nListen closely to your headphones/speakers."
T_TST_MSG2="\nTest complete.\n\nDid you hear a continuous beep for a few seconds?"
T_M_UPDATE="Check for Updates"
T_UP_CHK="Checking for updates..."
T_UP_DL="Downloading latest version from GitHub..."
T_UP_SUCC="Update complete! The script will now restart."
T_UP_ERR_INV="Update failed. Downloaded file is invalid. Check repo filename."
T_UP_ERR_NET="Update failed. Could not reach GitHub."
T_UP_BRANCH_MSG="Choose an update source:"
T_UP_BRANCH_MAIN="Main (Stable)"
T_UP_BRANCH_DEV="Development (Beta)"
T_M_REPAIR="Repair Bluetooth Stack"
T_REPAIR_TITLE="Repair Bluetooth"
T_REPAIR_MSG="\nPerforming a deep reset of the Bluetooth stack...\nReloading drivers and clearing caches."
T_REPAIR_DONE="Bluetooth stack has been repaired and restarted."


# Start gamepad input
# -------------------------------------------------------
# -------------------------------------------------------
# Display Management
# -------------------------------------------------------
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
StopGPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_STARTING" > "$CURR_TTY"
sleep 0.1

# -------------------------------------------------------
# Bluetooth Status
# -------------------------------------------------------

# -------------------------------------------------------
# Get Name of Connected Device
# -------------------------------------------------------

# -------------------------------------------------------

# -------------------------------------------------------
# Configure Bluetooth
# -------------------------------------------------------
pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:0,0"
        period_time 0
        period_size 1024
        buffer_size 4096
        rate 44100
    }
    bindings {
        0 0
        1 1
    }
}
ctl.!default { type hw card 0 }
ASOUND
fi
chown ark:ark "$ASOUNDRC"
EOF

sudo chmod +x /usr/local/bin/reset-alsa.sh

# --- Enable the service ---
sudo systemctl daemon-reload
sudo systemctl enable reset-alsa.service
}

# -------------------------------------------------------
# First run check for installed_flag
# -------------------------------------------------------

# -------------------------------------------------------
# Find internal audio sink
# -------------------------------------------------------

# -------------------------------------------------------
# Set Runtime,Start PulseAudio with Server Check
# -------------------------------------------------------

# -------------------------------------------------------
# Audio patch
# -------------------------------------------------------

# -------------------------------------------------------
# Route Audio Through Speakers
# -------------------------------------------------------

# -------------------------------------------------------
# Enable Bluetooth
# -------------------------------------------------------

# -------------------------------------------------------
# Toggle Bluetooth
# -------------------------------------------------------

# -------------------------------------------------------
# Auto-enable Bluetooth if not already on
# -------------------------------------------------------
 
# -------------------------------------------------------
# Scan and Connect
# -------------------------------------------------------
ScanAndConnect() {
    (
    AutoEnableBT
    ) &
    if ! GetPowerStatus; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_ERR_TITLE" --msgbox "\n $T_BT_DISABLED" 8 30 > "$CURR_TTY"
        return
    fi
  
    rm -f /tmp/bt_scan_results.txt
 
    (
    echo "0"; echo "XXX"; echo "$T_POWERING"; echo "XXX"
    
    # Force Controller Identity
    hciconfig hci0 class 0x000104 > /dev/null 2>&1
    bluetoothctl power on > /dev/null 2>&1
    bluetoothctl agent on > /dev/null 2>&1
    bluetoothctl default-agent > /dev/null 2>&1
    bluetoothctl pairable on > /dev/null 2>&1
    bluetoothctl discoverable on > /dev/null 2>&1
    
    # Use 'transport auto' to ensure both Classic and LE devices are found
    bluetoothctl set-scan-filter transport auto > /dev/null 2>&1
    
    SCAN_TIME=15
    bluetoothctl --timeout $SCAN_TIME scan on > /tmp/bt_scan_results.txt 2>&1 &
    SCAN_PID=$!
    
    for ((i=0; i<=SCAN_TIME*10; i++)); do
        PERCENT=$(( i * 100 / (SCAN_TIME * 10) ))
        if [ $i -lt 30 ]; then MSG="$T_SCAN_INIT"; 
        elif [ $i -lt $((SCAN_TIME*5)) ]; then MSG="$T_SCAN_PROCESS (Classic + LE)"; 
        else MSG="$T_SCAN_RESOLV"; fi
        
        echo "$PERCENT"
        echo "XXX"; echo "$MSG"; echo "XXX"
        sleep 0.1
    done
    wait $SCAN_PID
    bluetoothctl scan off > /dev/null 2>&1
    echo "100"
    ) | dialog --backtitle "$T_BACKTITLE" --title "$T_SCAN_TITLE" --gauge "$T_SCAN_START" 6 45 0 > "$CURR_TTY"

    # Combine 'devices' list with newly discovered ones from the scan log
    bluetoothctl devices > /tmp/bt_devices_list.txt
    grep "Device" /tmp/bt_scan_results.txt >> /tmp/bt_devices_list.txt
    
    unset coptions
    unset mac_list
    local index=1
    declare -A seen_macs
    
    while read -r line; do
        if [[ "$line" == *"Device"* ]]; then
            local mac=$(echo "$line" | awk '{print $2}')
            
            # Skip duplicates, invalid MACs, and already paired devices
            if [[ ! "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then continue; fi
            if [[ -n "${seen_macs[$mac]}" ]]; then continue; fi
            if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then continue; fi
            
            seen_macs["$mac"]=1
            
            # Extract name, fallback to T_UNKNOWN
            local name=$(echo "$line" | cut -d ' ' -f 3- | xargs)
            local dashed_mac="${mac//:/-}"
            
            if [[ "$name" == "$dashed_mac" ]] || [[ -z "$name" ]] || [[ "$name" == "Device" ]]; then
                # Try to find name in scan results
                local log_name=$(grep "$mac" /tmp/bt_scan_results.txt | grep "Name:" | tail -n 1 | sed -n 's/.*Name: //p' | xargs)
                [ -n "$log_name" ] && name="$log_name" || name="$T_UNKNOWN"
            fi
            
            # Final fallback/cleanup
            [[ "$name" == "$mac" ]] && name="$T_UNKNOWN"
            
            mac_list[$index]="$mac"
            coptions+=("$index" "$name ($mac)")
            index=$((index + 1))
        fi
    done < /tmp/bt_devices_list.txt

    if [ ${#coptions[@]} -eq 0 ]; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --msgbox "\n $T_NO_DEVICE\n\nCheck /home/ark/bt_audit.log for details." 10 45 > "$CURR_TTY"
        return
    fi

    while true; do
        cselection=$(dialog --colors --backtitle "$T_BACKTITLE" --title "$T_NEARBY" \
            --cancel-label "$T_BACK" --extra-button --extra-label "$T_RESCAN" \
            --menu "$T_CHOOSE_DEV" 15 50 8 "${coptions[@]}" 2>&1 > "$CURR_TTY")
        
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            ConnectProcess "${mac_list[$cselection]}"
            return
        elif [ $exit_code -eq 3 ]; then
            ScanAndConnect
            return
        else
            return
        fi
    done

}

# -------------------------------------------------------
# Wait for Stable Connection
# -------------------------------------------------------

# -------------------------------------------------------
# Connection (With PTY Ghost Terminal for BLE Keyboards)
# -------------------------------------------------------
    if [ $? -eq 0 ]; then
        # Use the mapped MAC address for the removal command
        bluetoothctl remove "${d_mac_list[$dselection]}" > /dev/null 2>&1
        dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "\n $T_FORGOTTEN" 7 30 > "$CURR_TTY"
    fi
}

# -------------------------------------------------------
# Uninstaller GUI Helpers
# -------------------------------------------------------
ask_gui() {
    local TITLE="$1"
    local MSG="$2"
    dialog --backtitle "$T_BACKTITLE2" \
           --title "$TITLE" \
           --yesno "$MSG" 15 45 > "$CURR_TTY"
}

ask_s_gui() {
    local TITLE="$1"
    local MSG="$2"
    dialog --backtitle "$T_BACKTITLE2" \
           --title "$TITLE" \
           --yesno "$MSG" 8 45 > "$CURR_TTY"
}

info_gui() {
    local TITLE="$1"
    local MSG="$2"
    dialog --backtitle "$T_BACKTITLE2" \
           --title "$TITLE" \
           --msgbox "$MSG" 13 45 > "$CURR_TTY"
}

infobox_gui() {
    local TITLE="$1"
    local MSG="$2"
    dialog --backtitle "$T_BACKTITLE2" \
           --title "$TITLE" \
           --infobox "$MSG" 5 45 > "$CURR_TTY"
}

# -------------------------------------------------------
# Forget All Devices
# -------------------------------------------------------

# -------------------------------------------------------
# Run Uninstaller
# -------------------------------------------------------

        apt-get remove -y bluez pulseaudio pulseaudio-module-bluetooth bluez-tools libasound2-plugins dbus-x11 >/dev/null 2>&1 &
        progress_while_running $! 85 "$T_REMOVING_MSG"

        apt-get autoremove -y >/dev/null 2>&1 &
        progress_while_running $! 95 "$T_REMOVING_MSG"

        while [ $current_p -lt 100 ]; do
            current_p=$((current_p + 1))
            echo "$current_p"
            echo "XXX"; echo " $T_DONE_TITLE"; echo "XXX"
            sleep 0.05
        done

    ) | dialog --backtitle "$T_BACKTITLE2" --title "$T_REMOVING_TITLE" --gauge "\n$T_REMOVING_MSG" 7 55 0 > "$CURR_TTY"
    installed_packages_removed="$T_OPT_MSG"
    fi

    # --- Forget All Devices? ---
    ask_s_gui "$T_FORGET_TITLE" "$T_FORGET_MSG"
    if [ $? -eq 0 ]; then
        infobox_gui "$T_FORGETTING_TITLE" "$T_FORGETTING_MSG"
        rm -rf "/var/lib/bluetooth/"*/
        sleep 0.5
    fi

    # --- Summary ---
    info_gui "$T_DONE_TITLE" "${T_DONE_MSG//%PKG%/$installed_packages_removed}"
    
    # --- REBOOT ---
    ask_s_gui "$T_REBOOT_TITLE" "$T_REBOOT_MSG"
    if [ $? -eq 0 ]; then
        infobox_gui "$T_REBOOTING_TITLE" "$T_REBOOTING_MSG"
        sleep 0.5
        reboot
    else
        ExitMenu
    fi
}

# -------------------------------------------------------
# Uninstaller Menu
# -------------------------------------------------------

# -------------------------------------------------------
# Silent Audit: Writes hardware state to a log file
# -------------------------------------------------------
# -------------------------------------------------------
# Silent Audit: Writes hardware state & raw LE scan to a log file
# -------------------------------------------------------

    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nStarting Resilient Audit...\nGathering USB data..." 6 45 > "$CURR_TTY"

    echo "=== BT SYSTEM AUDIT: $(date) ===" > "$LOG_FILE"
    
    safe_log "USB DEVICES" "lsusb" 5
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nGathering USB Topology..." 6 45 > "$CURR_TTY"
    safe_log "USB TOPOLOGY" "lsusb -t" 5
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nChecking Drivers..." 6 45 > "$CURR_TTY"
    safe_log "DRIVERS" "lsmod | grep -E 'btusb|rtk_btusb|8821cu|bluetooth'" 2
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nQuerying Adapter (hciconfig)..." 6 45 > "$CURR_TTY"
    safe_log "HCICONFIG" "hciconfig -a" 5
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nQuerying Adapter (btmgmt)..." 6 45 > "$CURR_TTY"
    safe_log "BTMGMT INFO" "btmgmt info" 5
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nReading System Logs..." 6 45 > "$CURR_TTY"
    safe_log "DMESG" "dmesg | grep -iE 'bluetooth|hci0|firmware|bluez' | tail -n 20" 2
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nChecking Audio Stack..." 6 45 > "$CURR_TTY"
    safe_log "PULSEAUDIO" "$PA_CMD info | grep 'Default Sink' && $PA_CMD list short sinks" 5
    
    dialog --backtitle "$T_BACKTITLE" --title "Hardware Audit" --infobox "\nPerforming RAW LE SCAN (10s)...\nDo not cancel." 6 45 > "$CURR_TTY"
    echo "--- RAW LE SCAN ---" >> "$LOG_FILE"
    # Try the newer btmgmt first, as it's more stable than hcitool
    timeout 10 btmgmt find -l >> "$LOG_FILE" 2>&1
    echo "--- END AUDIT ---" >> "$LOG_FILE"
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_AUD_TITLE" --msgbox "${T_AUD_MSG//%LOG%/$LOG_FILE}" 8 45 > "$CURR_TTY"
}

# -------------------------------------------------------
# Read Last Audit: Auto-Scrolling Teleprompter
# -------------------------------------------------------


# -------------------------------------------------------
# Power-Shift: Kill Wi-Fi, Force Bluetooth
# -------------------------------------------------------
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

# -------------------------------------------------------
# Restore: Kill Bluetooth, Re-enable Wi-Fi
# -------------------------------------------------------
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

# -------------------------------------------------------
# Repair Bluetooth Stack
# -------------------------------------------------------
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

# -------------------------------------------------------
# Silent Audit: Writes hardware state to a log file
# -------------------------------------------------------
RunAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    echo "=== BT SYSTEM AUDIT: $(date) ===" > "$LOG_FILE"
    lsusb >> "$LOG_FILE" 2>&1
    lsusb -t >> "$LOG_FILE" 2>&1
    lsmod | grep -E 'btusb|rtk_btusb|8821cu|bluetooth' >> "$LOG_FILE" 2>&1
    hciconfig -a >> "$LOG_FILE" 2>&1
    dialog --backtitle "$T_BACKTITLE" --title "$T_AUD_TITLE" --msgbox "Audit complete. Check $LOG_FILE." 8 45 > "$CURR_TTY"
}

# -------------------------------------------------------
# Read Last Audit: Auto-Scrolling Teleprompter
# -------------------------------------------------------
ReadAudit() {
    local LOG_FILE="/tmp/bt_audit.log"
    if [ ! -f "$LOG_FILE" ]; then dialog --msgbox "No audit found." 5 30 > "$CURR_TTY"; return; fi
    dialog --backtitle "$T_BACKTITLE" --title "Audit Log" --textbox "$LOG_FILE" 20 60 > "$CURR_TTY"
}
MainMenu() {
  CheckDeps
  EnsurePermissions

  while true; do
	# Keep gptokeyb alive
    if [[ -z $(pgrep -f gptokeyb) ]]; then
        StartGPTKeyb
    fi

    if GetPowerStatus; then
        BT_STAT="\Z2$T_ON\Zn"; DEV_NAME="\Z4$(GetConnectedName)\Zn"
		TOGGLE_LABEL="$T_DISABLE Bluetooth"
    else
        BT_STAT="\Z1$T_OFF\Zn"; DEV_NAME="$T_NONE"
		TOGGLE_LABEL="$T_ENABLE Bluetooth"
    fi

    mainselection=$(dialog --colors --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --cancel-label "$T_EXIT" \
    --menu "$T_STATUS: $BT_STAT\n$T_CONN_TO: $DEV_NAME" 22 55 15 \
    1 "$TOGGLE_LABEL" \
    2 "$T_M_SCAN" \
    3 "$T_M_DISCONNECT" \
    4 "$T_M_KNOWN" \
    5 "$T_M_FORGET" \
    6 "$T_M_TOGGLE_DRIVER" \
    7 "$T_M_AUDIT" \
    8 "$T_M_TEST_CHIME" \
    9 "$T_M_READ_AUDIT" \
    10 "$T_M_POWERSHIFT" \
    11 "$T_M_RESTORE_WIFI" \
    12 "$T_M_SYSTEM_SETUP" \
    13 "$T_M_UPDATE" \
    14 "$T_M_REPAIR" \
    15 "$T_MAIN_TITLE2" 2>&1 > "$CURR_TTY")

    [ $? -ne 0 ] && ExitMenu

    case $mainselection in
        1) ToggleBT ;;
        2) ScanAndConnect ;;
        3) DisconnectProcess ;;
        4) ListKnownAndConnect ;;
        5) DeleteDevice ;;
        6) ToggleDriver ;;
        7) RunAudit ;;
        8) PlayTestChime;;
        9) ReadAudit ;;
        10) PowerShiftBT ;;
        11) RestoreWiFi ;;
        12) SystemSetup;;
        13) UpdateScript ;;
        14) RepairStack ;;
        15) UninstallerMenu ;;
    esac
  done
}
# -------------------------------------------------------
# Gamepad Setup
# -------------------------------------------------------
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
sudo chmod 666 /dev/uinput
StartGPTKeyb

printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap ExitMenu EXIT

MainMenu