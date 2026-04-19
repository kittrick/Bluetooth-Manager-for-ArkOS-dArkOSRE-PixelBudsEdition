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
    
    # 1. Stop all services
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    
    # 2. Kill the kernel modules entirely
    sudo /sbin/modprobe -r btusb 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb 2>/dev/null
    sudo /sbin/modprobe -r 8821cu 2>/dev/null
    sleep 2
    
    # 3. Force binding rtk_btusb
    sudo /sbin/modprobe rtk_btusb 2>>"/home/ark/bt_audit.log"

    # Wait for the driver to actually bind
    echo "Waiting for rtk_btusb bind..." >> "/home/ark/bt_audit.log"
    for i in {1..10}; do
        if lsmod | grep -q "rtk_btusb"; then
            echo "rtk_btusb loaded successfully." >> "/home/ark/bt_audit.log"
            break
        fi
        sleep 1
    done
    sleep 3
    
    # 4. Bring up the interface
    if command -v hciconfig >/dev/null; then
        sudo hciconfig hci0 up 2>>"/home/ark/bt_audit.log"
    fi
    sleep 2
    
    # 5. Restart services
    sudo systemctl start bluetooth
    sleep 10
    sudo bluetoothctl power on
    
    dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "Shift complete. Check bt_audit.log." 8 50 > "$CURR_TTY"
}
RestoreWiFi() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_RES_TITLE" --infobox "$T_RES_MSG1" 5 40 > "$CURR_TTY"
    
    # 1. Kill Bluetooth processes and drivers
    sudo bluetoothctl power off > /dev/null 2>&1
    sudo systemctl stop bluetooth bluetooth-icon-updater bt-sink-switch bt-volume-monitor 2>/dev/null
    sudo /sbin/modprobe -r rtk_btusb btusb 2>/dev/null
    sleep 1
    
    # 2. Forceful USB Reset to clear any BT firmware hangs
    if [ -e "/sys/bus/usb/drivers/usb/1-1" ]; then
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/unbind > /dev/null
        sleep 1
        echo "1-1" | sudo tee /sys/bus/usb/drivers/usb/bind > /dev/null
        sleep 1
    fi
    
    # 3. Reload Wi-Fi Driver
    sudo /sbin/modprobe 8821cu
    
    # 4. Give the system a moment to find the network
    sleep 2
    dialog --backtitle "$T_BACKTITLE" --title "$T_RES_TITLE" --msgbox "$T_RES_MSG2" 8 40 > "$CURR_TTY"
}