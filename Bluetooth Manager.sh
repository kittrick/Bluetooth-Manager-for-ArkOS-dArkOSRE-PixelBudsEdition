#!/bin/bash

# Load external utilities
export T_BACKTITLE CURR_TTY; source "$(dirname "$0")/lib/bt_utils.sh"
source "$(dirname "$0")/lib/locale.sh"
source "$(dirname "$0")/lib/bt_ui.sh"
source "$(dirname "$0")/lib/bt_audio.sh"

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
StartGPTKeyb() {
    # Check if gptokeyb is running
    local pid=$(pgrep -f gptokeyb)
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null
    fi
    
    if [ -n "$GPTOKEYB_PID" ]; then
        kill -9 "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
    
    sleep 0.1
    /opt/inttools/gptokeyb -1 "$0" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

# -------------------------------------------------------
# Stop gamepad input
# -------------------------------------------------------
StopGPTKeyb() {
    if [ -n "$GPTOKEYB_PID" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

# -------------------------------------------------------
# Font Selection
# -------------------------------------------------------
ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

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
GetPowerStatus() {
    # Check if Bluetooth daemon is active
    if ! systemctl is-active --quiet bluetooth; then return 1; fi
    
    # Check if a controller is available
    if ! echo "list" | bluetoothctl | grep -q "Controller"; then return 1; fi
    
    # Check if Powered: yes
    if ! echo "show" | bluetoothctl | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Powered: yes"; then return 1; fi
    return 0
}

# -------------------------------------------------------
# Get Name of Connected Device
# -------------------------------------------------------
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

# -------------------------------------------------------

# -------------------------------------------------------
# Configure Bluetooth
# -------------------------------------------------------
FixBluetoothConfig() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --infobox "\n$T_SYSTEM_FIX" 5 50 > "$CURR_TTY"

    REAL_BT_PATH=$(find /usr -name bluetoothd -type f -executable | head -n 1)
    
    if [ -n "$REAL_BT_PATH" ]; then
        sudo sed -i "s|^ExecStart=.*|ExecStart=$REAL_BT_PATH --noplugin=sap|" /lib/systemd/system/bluetooth.service
    fi

    # Groups and Permissions
    for u in ark root pulse; do
        sudo usermod -aG pulse-access,audio,bluetooth,input $u 2>/dev/null
    done

    # Config PulseAudio
    cat <<EOF | sudo tee /etc/pulse/default.pa > /dev/null
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore
load-module module-augment-properties
load-module module-udev-detect
load-module module-native-protocol-unix auth-anonymous=1 socket=${PULSE_SOCKET}
load-module module-rescue-streams
load-module module-always-sink
load-module module-intended-roles
load-module module-suspend-on-idle
load-module module-switch-on-connect
EOF
    
    # --- DarkOS needs explicit ALSA sink — udev-detect doesn't create one ---
    if [ "${ARK_UID}" = "1000" ]; then
        sudo sed -i '/load-module module-udev-detect/i load-module module-alsa-sink device=default sink_name=internal_speaker' /etc/pulse/default.pa
    fi
    
    # --- Prevent double-loading of modules — system.pa would conflict with default.pa ---
    sudo truncate -s 0 /etc/pulse/system.pa
    
    cat <<EOF | sudo tee /etc/pulse/daemon.conf > /dev/null
flat-volumes = no
deferred-volume-safety-margin-usec = 1
EOF

    # --- Activate Autospawn ---
    grep -q "autospawn = yes" /etc/pulse/client.conf 2>/dev/null || echo "autospawn = yes" | sudo tee -a /etc/pulse/client.conf > /dev/null

    # --- PulseAudio Service ---
    cat <<EOF | sudo tee /etc/systemd/system/pulseaudio.service > /dev/null
[Unit]
Description=PulseAudio Sound Daemon
After=bluetooth.service alsa-restore.service
Before=emulationstation.service

[Service]
Type=simple
User=ark
Environment=PULSE_RUNTIME_PATH=/run/user/${ARK_UID}/pulse
ExecStartPre=/bin/mkdir -p /run/user/${ARK_UID}/pulse
ExecStartPre=/bin/chown ark:ark /run/user/${ARK_UID}/pulse
ExecStartPre=-/bin/rm -f /run/user/${ARK_UID}/pulse/pid
ExecStartPre=-/bin/rm -f $PULSE_SOCKET
ExecStart=/usr/bin/pulseaudio --daemonize=no --exit-idle-time=-1 --no-cpu-limit --disable-shm=false
Restart=always
RestartSec=2
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

    # --- Service Volume — runs as ark, event3 made accessible via udev rule ---
    cat <<EOF | sudo tee /etc/systemd/system/bt-volume-monitor.service > /dev/null
[Unit]
Description=R36S Volume Buttons Monitor
After=pulseaudio.service

[Service]
Type=simple
ExecStart=/usr/local/bin/bt-volume-monitor.sh
Restart=always
RestartSec=2
User=ark
Nice=-15

[Install]
WantedBy=multi-user.target
EOF

    # --- udev rule to make event3 accessible to ark ---
    echo 'KERNEL=="event3", SUBSYSTEM=="input", MODE="0666"' | sudo tee /etc/udev/rules.d/99-input-event3.rules > /dev/null
    sudo udevadm control --reload-rules

    # --- Service bt-sink-switch ---
    cat <<EOF | sudo tee /etc/systemd/system/bt-sink-switch.service > /dev/null
[Unit]
Description=Bluetooth Audio Sink Auto-Switch
After=pulseaudio.service bluetooth.service
After=sound.target

[Service]
Type=simple
User=ark
Environment=PULSE_RUNTIME_PATH=/run/user/${ARK_UID}/pulse
ExecStart=/usr/local/bin/bt-sink-switch.sh
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

# --- detect internal sink name ---
sleep 2
INTERNAL_SINK_NAME=$(pactl --server=unix:${PULSE_SOCKET} list short sinks 2>/dev/null | \
    grep -v bluez | grep -v auto_null | awk '{print $2}' | head -n1)
[ -z "$INTERNAL_SINK_NAME" ] && INTERNAL_SINK_NAME="internal_speaker"

    cat <<EOF | sudo tee /usr/local/bin/bt-sink-switch.sh > /dev/null
#!/bin/bash
PA="pactl --server=unix:$PULSE_SOCKET"

until [ -S $PULSE_SOCKET ] && \$PA info >/dev/null 2>&1; do
    sleep 1
done

LAST_STATE=""
declare -A LAST_SEEN
DEBOUNCE_SEC=5

(
    bluetoothctl --monitor |
    while read -r line; do
        case "\$line" in
                *"[NEW] Device "*|*"[CHG] Device "*)
                mac=\$(echo "\$line" | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}')
                [ -z "\$mac" ] && continue
                
                now=\$(date +%s)
                if [[ -n "\${LAST_SEEN[\$mac]}" ]]; then
                    diff=\$((now - LAST_SEEN[\$mac]))
                    [ "\$diff" -lt "\$DEBOUNCE_SEC" ] && continue
                fi
                LAST_SEEN[\$mac]=\$now

                info=\$(bluetoothctl info "\$mac")
                
                connected=\$(echo "\$info" | awk -F': ' '/Connected/ {print \$2}')
                paired=\$(echo "\$info" | awk -F': ' '/Paired/ {print \$2}')

                [ "\$paired" != "yes" ] && continue
                [ "\$connected" != "no" ] && continue

                sleep 1
                bluetoothctl connect "\$mac" >/dev/null 2>&1 &
            ;;
        esac
    done
) &

while true; do
    CONNECTED=\$(timeout 2 bluetoothctl info 2>/dev/null | grep -c "Connected: yes")
    if [ "\$CONNECTED" -gt 0 ] && [ "\$LAST_STATE" != "connected" ]; then
        ICON=\$(bluetoothctl info 2>/dev/null | grep "Icon:" | awk '{print \$2}')
        [[ "\$ICON" != audio* ]] && continue
        LAST_STATE="connected"
        sleep 1
        CARD=\$(\$PA list short cards 2>/dev/null | grep bluez_card | awk '{print \$2}')
        [ -n "\$CARD" ] && \$PA set-card-profile "\$CARD" a2dp_sink 2>/dev/null
        sleep 1
        BT_SINK=\$(\$PA list short sinks 2>/dev/null | grep bluez_sink | awk '{print \$2}')
        [ -n "\$BT_SINK" ] && \$PA set-default-sink "\$BT_SINK" 2>/dev/null
        for stream in \$(\$PA list short sink-inputs 2>/dev/null | awk '{print \$1}'); do
            \$PA move-sink-input "\$stream" "\$BT_SINK" 2>/dev/null
        done
    elif [ "\$CONNECTED" -eq 0 ] && [ "\$LAST_STATE" != "disconnected" ]; then
        LAST_STATE="disconnected"
        \$PA suspend ${INTERNAL_SINK_NAME} 0 2>/dev/null
        sleep 0.5
        \$PA set-default-sink ${INTERNAL_SINK_NAME} 2>/dev/null
        \$PA set-sink-mute ${INTERNAL_SINK_NAME} 0 2>/dev/null
        \$PA set-sink-volume ${INTERNAL_SINK_NAME} 65% 2>/dev/null
        for stream in \$(\$PA list short sink-inputs 2>/dev/null | awk '{print \$1}'); do
            \$PA move-sink-input "\$stream" ${INTERNAL_SINK_NAME} 2>/dev/null
        done
        /usr/local/bin/reset-alsa.sh
    fi
    sleep 2
done
EOF
    sudo chmod +x /usr/local/bin/bt-sink-switch.sh

    # --- Setting up Bluetooth ---
    sudo chmod 755 /etc/bluetooth
    cat <<EOF | sudo tee /etc/bluetooth/main.conf > /dev/null
[General]
ControllerMode = dual
JustWorksRepairing = always
AutoEnable = false
FastConnectable = true
Experimental = true
ReconnectAttempts = 7
ReconnectInterval = 5
EOF

# --- RetroArch and RetroArch32 Audio Setup ---
    local RA_CONFIGS=("/home/ark/.config/retroarch/retroarch.cfg" "/home/ark/.config/retroarch32/retroarch.cfg")
    
    for conf in "${RA_CONFIGS[@]}"; do
        if [ -f "$conf" ]; then
            if grep -q "^audio_driver =" "$conf"; then
                sudo sed -i 's/^audio_driver = .*/audio_driver = "sdl2"/' "$conf"
            else
        echo 'audio_driver = "sdl2"' | sudo tee -a "$conf" > /dev/null
            fi
        fi
    done
    
    FixVolumeScript

    grep -q "PULSE_SERVER" /etc/environment 2>/dev/null || \
        echo "PULSE_SERVER=unix:${PULSE_SOCKET}" >> /etc/environment
    grep -q "XDG_RUNTIME_DIR" /etc/environment 2>/dev/null || \
        echo "XDG_RUNTIME_DIR=/run/user/${ARK_UID}" >> /etc/environment
    
    sudo systemctl daemon-reload
    sudo systemctl unmask bluetooth.service 2>/dev/null
    sudo systemctl enable bluetooth.service
    sudo systemctl enable pulseaudio.service
    sudo systemctl enable bt-volume-monitor.service
    sudo systemctl enable bt-sink-switch.service
    
    # --- Immediate restart to test ---
    sudo systemctl restart bluetooth.service
    sudo systemctl restart pulseaudio.service
    sudo systemctl restart bt-volume-monitor.service
    sudo systemctl restart bt-sink-switch.service
    
    # Only load explicit ALSA sink if udev-detect didn't create one
    sleep 2
    if ! pactl --server=unix:${PULSE_SOCKET} list short sinks 2>/dev/null | grep -q "alsa_output"; then
        pactl --server=unix:${PULSE_SOCKET} load-module module-alsa-sink device=default sink_name=internal_speaker >/dev/null 2>&1
    fi
    
# --- Default to ALSA sink at boot ---
    # --- Create reset-alsa.service ---
    sudo tee /etc/systemd/system/reset-alsa.service > /dev/null <<'EOF'
[Unit]
Description=Force internal ALSA audio at boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/reset-alsa.sh
RemainAfterExit=yes
User=ark

[Install]
WantedBy=multi-user.target
EOF

    # --- Create reset-alsa.sh ---
    sudo tee /usr/local/bin/reset-alsa.sh > /dev/null <<'EOF'
#!/bin/bash

ASOUNDRC="/home/ark/.asoundrc"
ASOUNDRC_BAK="/home/ark/.asoundrcbak"

# Restore .asoundrc to direct ALSA
if [ -f "$ASOUNDRC_BAK" ] && [ -s "$ASOUNDRC_BAK" ]; then
    cp "$ASOUNDRC_BAK" "$ASOUNDRC"
else
    cat <<ASOUND > "$ASOUNDRC"
pcm.!default {
    type plug
    slave.pcm "dmixer"
}
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
# Find internal audio sink
# -------------------------------------------------------
GetInternalSink() {
    local sink
    sink=$(pactl --server=unix:${PULSE_SOCKET} list short sinks 2>/dev/null | grep -v bluez | grep -v auto_null | awk '{print $2}' | head -n1)
    echo "${sink:-internal_speaker}"
}

# -------------------------------------------------------
# Set Runtime,Start PulseAudio with Server Check
# -------------------------------------------------------
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

# -------------------------------------------------------
# Audio patch
# -------------------------------------------------------
ApplyAudioFix() {
    local PA_CMD="pactl --server=unix:$PULSE_SOCKET"
    
    # --- Only wait for bluez_card if a device is actually connected ---
    local CARD=""
    local attempts=0
    while [ -z "$CARD" ] && [ $attempts -lt 5 ]; do
        sleep 0.5
        CARD=$($PA_CMD list short cards 2>/dev/null | grep "bluez_card" | awk '{print $2}')
        attempts=$((attempts + 1))
    done
    [ -n "$CARD" ] && $PA_CMD set-card-profile "$CARD" a2dp_sink >/dev/null 2>&1
    
    local BT_SINK=$($PA_CMD list short sinks 2>/dev/null | grep "bluez_sink" | awk '{print $2}')
    
    if [ -n "$BT_SINK" ]; then
        $PA_CMD set-default-sink "$BT_SINK" >/dev/null 2>&1

        local CARD=$($PA_CMD list short cards 2>/dev/null | grep "bluez_card" | awk '{print $2}')
        if [ -n "$CARD" ]; then
            $PA_CMD set-card-profile "$CARD" a2dp_sink >/dev/null 2>&1
        fi

        $PA_CMD set-sink-volume "$BT_SINK" 60% >/dev/null 2>&1

        # Route ALSA through PulseAudio so SDL2/RetroArch audio goes to BT
        SetAsoundPulse
    else
        $PA_CMD set-default-sink $(GetInternalSink) >/dev/null 2>&1
        $PA_CMD set-sink-mute $(GetInternalSink) 0 >/dev/null 2>&1
        SetAsoundDirect
    fi

    # -- Move all current audio streams to the new output ---
    local DEFAULT_SINK=$($PA_CMD info 2>/dev/null | grep "Default Sink" | awk '{print $3}')
    for stream in $($PA_CMD list short sink-inputs 2>/dev/null | awk '{print $1}'); do
        $PA_CMD move-sink-input "$stream" "$DEFAULT_SINK" >/dev/null 2>&1
    done
}

# -------------------------------------------------------
# Route Audio Through Speakers
# -------------------------------------------------------
ForceInternalAudio() {
    local PA_CMD="pactl --server=unix:$PULSE_SOCKET"

    $PA_CMD set-default-sink $(GetInternalSink) >/dev/null 2>&1
    $PA_CMD set-sink-mute $(GetInternalSink) 0 >/dev/null 2>&1
    $PA_CMD set-sink-volume $(GetInternalSink) 65% >/dev/null 2>&1

    # --- Restore ALSA direct routing ---
    SetAsoundDirect

    # --- The current audio is being moved to the speaker ---
    for stream in $($PA_CMD list short sink-inputs 2>/dev/null | awk '{print $1}'); do
        $PA_CMD move-sink-input "$stream" $(GetInternalSink) >/dev/null 2>&1
    done
}

# -------------------------------------------------------
# Enable Bluetooth
# -------------------------------------------------------
EnableBT() {
    rfkill unblock bluetooth > /dev/null 2>&1
    systemctl start bluetooth > /dev/null 2>&1 &
    bluetoothctl power on > /dev/null 2>&1
    
    (
    CheckPulse
    sleep 1
    bluetoothctl devices | awk '{print $2}' | while read -r mac; do
        if bluetoothctl info "$mac" | grep -q "Paired: yes"; then
            bluetoothctl connect "$mac" >/dev/null 2>&1 &
            sleep 2
            
            if ! bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                bluetoothctl connect "$mac" >/dev/null 2>&1 &
            fi
        fi
    done
    sleep 2
    ApplyAudioFix
    ) &
}

# -------------------------------------------------------
# Toggle Bluetooth
# -------------------------------------------------------
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

# -------------------------------------------------------
# Auto-enable Bluetooth if not already on
# -------------------------------------------------------
AutoEnableBT() {
    if ! GetPowerStatus; then
        EnableBT
    fi
 }
 
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
is_connected_stable() {
    local mac="$1"
    local PA_CMD="pactl --server=unix:$PULSE_SOCKET"

    sleep 0.5

    if bluetoothctl info "$mac" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Connected: yes"; then
        return 0
    fi

    if $PA_CMD list short sinks | grep -q "bluez_sink"; then
        return 0
    fi
    
    return 1
}

# -------------------------------------------------------
# Connection (With PTY Ghost Terminal for BLE Keyboards)
# -------------------------------------------------------
ConnectProcess() {
    CheckPulse
    sleep 0.5
    systemctl stop bluetooth-icon-updater.service || true
    local mac="$1"
    local name=$(bluetoothctl info "$mac" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Alias: //p' | xargs)
    [ -z "$name" ] && name="$T_DEV_DEFAULT"

    # Clear previous pairing logs
    rm -f /tmp/bt_pair.log

    (
    echo "10"; echo "XXX"; echo "$T_PROCESS ..."; echo "XXX"

    # --- Pairing (With PTY Ghost Terminal) ---
    if ! bluetoothctl info "$mac" | grep -q "Paired: yes"; then

        # Launch bluetoothctl inside a Pseudo-Terminal (PTY)
        (
            sleep 1 # Wait for DBus to hook in
            echo "agent off"
            sleep 1 # CRITICAL: Give BlueZ time to unregister
            echo "agent KeyboardDisplay"
            sleep 1 # CRITICAL: Give BlueZ time to register the new agent
            echo "default-agent"
            sleep 1 # CRITICAL: Ensure it is set as default
            echo "pair $mac" 
            sleep 60 # Keep the PTY open so you have time to type the PIN
            echo "quit"
        ) | script -q -c "bluetoothctl" /tmp/bt_pair.log >/dev/null 2>&1 &
        SCRIPT_PID=$!

        TIMEOUT=60
        ELAPSED=0

        # Live Log Scraper Loop
        while kill -0 $SCRIPT_PID 2>/dev/null; do
            if [ $ELAPSED -ge $TIMEOUT ]; then
                break
            fi

            # Break early if pairing completes or fails
            if grep -q -iE "(Pairing successful)" /tmp/bt_pair.log; then
                break
            fi
            if grep -q -iE "(Failed to pair)" /tmp/bt_pair.log; then
                break
            fi

            # Extract the 6-digit PIN code
            PIN=$(grep -a -iE "(Passkey|PIN code)" /tmp/bt_pair.log | grep -oE "[0-9]{6}" | tail -n1)

            if [ -n "$PIN" ]; then
                # Inject it directly into the loading bar!
                echo "50"; echo "XXX"; echo "KEYBOARD PIN: $PIN (Type & press ENTER)"; echo "XXX"
            else
                echo "30"; echo "XXX"; echo "$T_PAIRING ..."; echo "XXX"
            fi

            sleep 1
            ELAPSED=$((ELAPSED + 1))
        done

        # Clean up the ghost terminal AND assassinate any zombie bluetoothctl processes
        kill -9 $SCRIPT_PID 2>/dev/null
        pkill -9 -x bluetoothctl 2>/dev/null

        # Restart a fresh bluetoothctl instance just to turn off the scan cleanly
        bluetoothctl scan off >/dev/null 2>&1
    fi

    # --- Trust and Connect ---
    echo "70"; echo "XXX"; echo "Finalizing pairing..."; echo "XXX"
    bluetoothctl trust "$mac" >/dev/null 2>&1
    sleep 0.5

    echo "80"; echo "XXX"; echo "$T_CONNECTING_TO $name ..."; echo "XXX"
    bluetoothctl connect "$mac" >/dev/null 2>&1
    sleep 3

    # THE FIX: Check icon AFTER connecting so BlueZ has actually resolved the device type!
    local icon=$(bluetoothctl info "$mac" | grep "Icon:" | awk '{print $2}')

    if [[ "$icon" == audio* ]]; then
        echo "100"; echo "XXX"; echo "$T_FIXING_AUDIO"; echo "XXX"
    else
        echo "100"; echo "XXX"; echo "$T_INIT"; echo "XXX"
    fi
    sleep 1

    ) | dialog --backtitle "$T_BACKTITLE" --title "$T_CONN_TITLE" --gauge "" 8 55 0 > "$CURR_TTY"

    # Move the Audio fix trigger to only fire if it's confirmed audio and stable
    local final_icon=$(bluetoothctl info "$mac" | grep "Icon:" | awk '{print $2}')
    if [[ "$final_icon" == audio* ]] && is_connected_stable "$mac"; then
        ApplyAudioFix
    fi

    if is_connected_stable "$mac"; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "\n $name $T_CONNECTED\n" 7 50 > "$CURR_TTY"
    else
        # Dump the failed ghost terminal log into your audit log for debugging
        echo "--- FAILED PAIRING LOG ---" >> /home/ark/bt_audit.log
        cat /tmp/bt_pair.log >> /home/ark/bt_audit.log 2>/dev/null
        dialog --backtitle "$T_BACKTITLE" --title "$T_FAILED" --msgbox "\n $T_FAIL_CONNECT $name.\n\n $T_FAIL_MSG\nCheck 'Read Last Audit' for reason." 12 50 > "$CURR_TTY"
    fi
    systemctl start bluetooth-icon-updater.service || true
}
# -------------------------------------------------------
# Disconnection
# -------------------------------------------------------
DisconnectProcess() {
    unset poptions
    while read -r line; do
    local mac=$(echo "$line" | awk '{print $2}')
    local name=$(echo "$line" | cut -d ' ' -f 3-)
      
        # --- Check if this device is connected ---
        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
          poptions+=("$mac" "$name")
        fi
        
    done < <(bluetoothctl devices)

        # --- If nothing is connected ---
        if [ ${#poptions[@]} -eq 0 ]; then
            dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --msgbox "\n $T_NONE $T_CONNECTED" 7 35 > "$CURR_TTY"
            return
        fi
 
    pselection=$(dialog --backtitle "$T_BACKTITLE" --title "$T_M_DISCONNECT" --menu "$T_CHOOSE_DEV" 9 50 2 "${poptions[@]}" 2>&1 > "$CURR_TTY")
    [ $? -ne 0 ] && return

    local sel_name=$(bluetoothctl info "$pselection" | sed -n 's/.*Alias: //p' | xargs)
    [ -z "$sel_name" ] && sel_name="$T_DEV_DEFAULT"

    (
    echo "20"; echo "XXX"; echo "$T_PROCESS"; echo "XXX"
    timeout 5 bluetoothctl disconnect "$pselection" > /dev/null 2>&1
    
    echo "80"; echo "XXX"; echo "$T_PROCESS"; echo "XXX"
    
    ForceInternalAudio
    echo "100"
    ) | dialog --backtitle "$T_BACKTITLE" --title "$T_CONN_TITLE" --gauge "\n $T_PROCESS" 8 50 0 > "$CURR_TTY"
    
    if bluetoothctl info "$pselection" | grep -q "Connected: no"; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "\n $sel_name $T_DISCONNECTED" 7 40 > "$CURR_TTY"
    else
        dialog --backtitle "$T_BACKTITLE" --title "$T_FAILED" --msgbox "\n $T_FAIL_DISCONNECT $sel_name" 7 40 > "$CURR_TTY"
    fi
}

# -------------------------------------------------------
# List of Known Devices
# -------------------------------------------------------
ListKnownAndConnect() {
    (
    AutoEnableBT
    CheckPulse
    sleep 0.5
    ) &
    local warmup_pid=$!
    
    unset koptions
    unset k_mac_list
    local index=1
    
    while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d ' ' -f 3-)
        
        # Map to index
        k_mac_list[$index]="$mac"
        koptions+=("$index" "$name ($mac)")
        index=$((index + 1))
    done < <(bluetoothctl devices | while read -r _ mac name; do
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        echo "Device $mac $name"
    fi
    done)
    
    if [ ${#koptions[@]} -eq 0 ]; then
       dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --msgbox "\n $T_NO_KNOWN" 7 33 > "$CURR_TTY"
       return
    fi
  
    kselection=$(dialog --backtitle "$T_BACKTITLE" --title "$T_KNOWN_DEV" --menu "$T_CONNECT_TO" 11 50 4 "${koptions[@]}" 2>&1 > "$CURR_TTY")
    local dialog_exit=$?
    wait $warmup_pid
    
    # Send the mapped MAC to the connection process
    [ $dialog_exit -eq 0 ] && ConnectProcess "${k_mac_list[$kselection]}"
}

# -------------------------------------------------------
# Forget a Device
# -------------------------------------------------------
DeleteDevice() {
    (
    AutoEnableBT
    ) &
    
    unset doptions
    unset d_mac_list
    local index=1
    
    while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d ' ' -f 3-)
        
        # Map to index
        d_mac_list[$index]="$mac"
        doptions+=("$index" "$name ($mac)")
        index=$((index + 1))
    done < <(bluetoothctl devices | while read -r _ mac name; do
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        echo "Device $mac $name"
    fi
    done)

    if [ ${#doptions[@]} -eq 0 ]; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --msgbox "\n $T_NOTHING_DEL" 7 25 > "$CURR_TTY"
        return
    fi

    dselection=$(dialog --backtitle "$T_BACKTITLE" --title "$T_DELETE_TITLE" --menu "$T_CHOOSE_DEL" 11 50 4 "${doptions[@]}" 2>&1 > "$CURR_TTY")
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

# -------------------------------------------------------
# Run Uninstaller
# -------------------------------------------------------
RunUninstall() {
    # -- Force audio back to internal speaker ---
    ForceInternalAudio
    sleep 0.1

    # --- Stop and Disable Services ---
    infobox_gui "$T_STEP1_TITLE" "$T_STEP1_MSG"

    for svc in bt-volume-monitor.service bt-sink-switch.service reset-alsa.service pulseaudio.service bluetooth.service; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" 2>/dev/null
        fi
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            systemctl disable "$svc" 2>/dev/null
        fi
    done

    # --- Remove Installed Files ---
    infobox_gui "$T_STEP2_TITLE" "$T_STEP2_MSG"

    FILES_TO_REMOVE=(
        "/usr/local/bin/bt-volume-monitor.sh"
        "/usr/local/bin/bt-sink-switch.sh"
        "/usr/local/bin/reset-alsa.sh"
        "/etc/systemd/system/pulseaudio.service"
        "/etc/systemd/system/bt-volume-monitor.service"
        "/etc/systemd/system/bt-sink-switch.service"
        "/etc/systemd/system/reset-alsa.service"
        "/etc/udev/rules.d/99-input-event3.rules"
        "/etc/pulse/default.pa"
        "/etc/pulse/daemon.conf"
        "$INSTALLED_FLAG"
    )

    for f in "${FILES_TO_REMOVE[@]}"; do
        if [ -f "$f" ]; then
            rm -f "$f"
        fi
    done
    
    rm -rf /home/ark/.config/pulse/ 2>/dev/null || true
    rm -rf /run/user/${ARK_UID}/pulse/ 2>/dev/null || true
    cp /home/ark/.asoundrcbak /home/ark/.asoundrc 2>/dev/null || true
    sed -i '/autospawn = yes/d' /etc/pulse/client.conf 2>/dev/null || true
    sed -i '/PULSE_SERVER/d' /etc/environment 2>/dev/null || true
    sed -i '/XDG_RUNTIME_DIR/d' /etc/environment 2>/dev/null || true
    sudo udevadm control --reload-rules

    # --- Restore /etc/bluetooth/main.conf ---
    infobox_gui "$T_STEP3_TITLE" "$T_STEP3_MSG"

    if [ -f "/etc/bluetooth/main.conf" ]; then
        cat <<'EOF' > /etc/bluetooth/main.conf
[Policy]
AutoEnable=false
EOF
    fi

    # --- Restore /etc/pulse/system.pa ---
    infobox_gui "$T_STEP4_TITLE" "$T_STEP4_MSG"

    if [ -f "/etc/pulse/system.pa" ]; then
        cat <<'EOF' > /etc/pulse/system.pa
### Automatically restore the volume of streams and devices
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore

### Automatically augment property information from .desktop files
load-module module-augment-properties

### Should be after module-*-restore but before module-*-detect
load-module module-switch-on-port-available

### Load audio drivers statically
load-module module-udev-detect

### Use the static hardware detection module (for systems without udev support)
# load-module module-detect

### Automatically restore the default sink/source when changed by the user
load-module module-default-device-restore

### Automatically move streams to the default sink if the sink they are
### connected to dies, similar for sources
load-module module-rescue-streams

### Make sure we always have a sink around, even if it is a null sink.
load-module module-always-sink

### Honour intended role device property
load-module module-intended-roles

### Automatically suspend sinks/sources that become idle for too long
load-module module-suspend-on-idle

### Enable positioned event sounds
load-module module-position-event-sounds

### Cork music/video streams when a phone stream is active
load-module module-role-cork

### Modules to allow autoloading of filters (such as echo cancellation)
### on demand. module-filter-heuristics tries to determine what filters
### make sense, module-filter-apply does the heavy-lifting of loading
### temporary modules with appropriate arguments and doing the switch.
load-module module-filter-heuristics
load-module module-filter-apply
EOF
    fi

    # --- Restore bluetooth.service ---
    infobox_gui "$T_STEP5_TITLE" "$T_STEP5_MSG"

    BT_SERVICE="/lib/systemd/system/bluetooth.service"
    if [ -f "$BT_SERVICE" ]; then
        REAL_BT_PATH=$(find /usr -name bluetoothd -type f -executable | head -n 1)
        if [ -n "$REAL_BT_PATH" ]; then
            if grep -q "\-\-noplugin=sap" "$BT_SERVICE"; then
                sed -i "s|^ExecStart=.*--noplugin=sap.*|ExecStart=$REAL_BT_PATH -d|" "$BT_SERVICE"
            fi
        fi
    fi

    # --- Restore RetroArch Audio Driver ---
    infobox_gui "$T_STEP6_TITLE" "$T_STEP6_MSG"

    RA_CONFIGS=(
        "/home/ark/.config/retroarch/retroarch.cfg"
        "/home/ark/.config/retroarch32/retroarch.cfg"
    )

    for conf in "${RA_CONFIGS[@]}"; do
        if [ -f "$conf" ]; then
            if grep -q '^audio_driver = "sdl2"' "$conf"; then
                sed -i 's/^audio_driver = "sdl2"/audio_driver = "alsa"/' "$conf"
            fi
        fi
    done

    # --- Reload systemd  ---
    infobox_gui "$T_STEP7_TITLE" "$T_STEP7_MSG"
    systemctl daemon-reload
    sleep 0.5

    # --- OPTIONAL: Remove Packages ---
    ask_gui "$T_PKG_TITLE" "$T_PKG_MSG"

    if [ $? -eq 0 ]; then
    (
        current_p=0

        progress_while_running() {
            local pid=$1
            local target=$2
            local msg=$3
            echo "XXX"; echo "$msg"; echo "XXX"
            while kill -0 $pid 2>/dev/null; do
                if [ $current_p -lt $target ]; then
                    current_p=$((current_p + 1))
                    echo "$current_p"
                fi
                sleep 0.3
            done
            current_p=$target
            echo "$current_p"
}

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

# -------------------------------------------------------
# Silent Audit: Writes hardware state to a log file
# -------------------------------------------------------
# -------------------------------------------------------
# Silent Audit: Writes hardware state & raw LE scan to a log file
# -------------------------------------------------------
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

# -------------------------------------------------------
# Power-Shift: Kill Wi-Fi, Force Bluetooth
# -------------------------------------------------------
# -------------------------------------------------------
# Toggle Driver (Generic vs Realtek)
# -------------------------------------------------------
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

# -------------------------------------------------------
# System Setup
# -------------------------------------------------------
SystemSetup() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_SETUP_TITLE" --infobox "$T_SETUP_MSG" 6 50 > "$CURR_TTY"
    FixBluetoothConfig
    dialog --backtitle "$T_BACKTITLE" --title "$T_SETUP_DONE_TITLE" --msgbox "$T_SETUP_DONE_MSG" 12 55 > "$CURR_TTY"
}

# -------------------------------------------------------
# Repair Bluetooth Stack
# -------------------------------------------------------
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

# -------------------------------------------------------
# Main Menu
# -------------------------------------------------------
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