# Route ALSA through PulseAudio (for Bluetooth audio)
# -------------------------------------------------------
SetAsoundPulse() {
    cat <<ASOUND > "$ASOUNDRC"
pcm.!default {
    type pulse
    server unix:$PULSE_SOCKET
}
ctl.!default {
    type pulse
    server unix:$PULSE_SOCKET
}
ASOUND
    chown ark:ark "$ASOUNDRC"
}

# -------------------------------------------------------
# Restore ALSA direct routing (for internal speaker)
# -------------------------------------------------------
SetAsoundDirect() {
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
}

# -------------------------------------------------------
# Exit the script
# -------------------------------------------------------
ExitMenu() {
    trap - EXIT
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    StopGPTKeyb
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"
    fi

    exit 0
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

            # --- Function to advance the bar while a command is being processed ---
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

            # --- Updating Repositories ---
            apt-get update -y >/dev/null 2>&1 &
            progress_while_running $! 25 "$T_UPDATE"

            # --- Installing Packages ---
            TOTAL=${#MISSING_PACKAGES[@]}
            COUNT=0
            for pkg in "${MISSING_PACKAGES[@]}"; do
                COUNT=$((COUNT + 1))
               
                start_section=$(( 25 + ( (COUNT - 1) * 70 / TOTAL ) ))
                end_section=$(( 25 + ( COUNT * 70 / TOTAL ) ))
                
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1 &
                progress_while_running $! $end_section "$T_PACKAGE $pkg ($COUNT/$TOTAL)..."
            done

            # --- Finalization ---
            while [ $current_p -lt 100 ]; do
                current_p=$((current_p + 1))
                echo "$current_p"
                echo "XXX"; echo "$T_COMPLETE"; echo "XXX"
                sleep 0.05
            done
            
        ) | dialog --backtitle "$T_BACKTITLE" --title "$T_DEPS" --gauge "\n$T_INIT" 8 50 0 > "$CURR_TTY"
    fi
}

# -------------------------------------------------------
# Volume Configuration
# -------------------------------------------------------
FixVolumeScript() {
    cat <<EOF | sudo tee /usr/local/bin/bt-volume-monitor.sh > /dev/null
#!/bin/bash
PA="pactl --server=unix:$PULSE_SOCKET"

until [ -S $PULSE_SOCKET ]; do
    sleep 1
done

EV="/dev/input/event3"
[ ! -e "\$EV" ] && EV="/dev/input/\$(grep -E 'Handlers|Name' /proc/bus/input/devices | grep -A1 "odroidgo3-keys" | grep -oE 'event[0-9]+' | head -n1)"

CUR_VOL=60
BT_SINK=""

refresh_sink() {
    BT_SINK=\$(\$PA list short sinks 2>/dev/null | grep bluez_sink | awk '{print \$2}')
}

sync_vol() {
    [ -z "\$BT_SINK" ] && return
    local V=\$(\$PA list sinks 2>/dev/null | awk "/Name: \$BT_SINK/{found=1} found && /Volume:/ && !/Base/{match(\\\$0,/[0-9]+%/); print substr(\\\$0,RSTART,RLENGTH-1); exit}")
    [ -n "\$V" ] && CUR_VOL=\$V
}

setvol() {
    local DIR=\$1
    [ -z "\$BT_SINK" ] && return
    CUR_VOL=\$(( DIR > 0 ? CUR_VOL + 2 : CUR_VOL - 2 ))
    [ "\$CUR_VOL" -gt 100 ] && CUR_VOL=100
    [ "\$CUR_VOL" -lt 0 ] && CUR_VOL=0
    \$PA set-sink-volume "\$BT_SINK" \${CUR_VOL}% >/dev/null 2>&1
    if [ "\$CUR_VOL" -eq 0 ]; then
        \$PA set-sink-mute "\$BT_SINK" 1 >/dev/null 2>&1
    else
        \$PA set-sink-mute "\$BT_SINK" 0 >/dev/null 2>&1
    fi
}

refresh_sink
sync_vol

while read line; do
    if [[ "\$line" == *"KEY_VOLUMEUP"* && "\$line" == *"value 1"* ]]; then
        refresh_sink; setvol 1
    elif [[ "\$line" == *"KEY_VOLUMEUP"* && "\$line" == *"value 2"* ]]; then
        setvol 1
    elif [[ "\$line" == *"KEY_VOLUMEDOWN"* && "\$line" == *"value 1"* ]]; then
        refresh_sink; setvol -1
    elif [[ "\$line" == *"KEY_VOLUMEDOWN"* && "\$line" == *"value 2"* ]]; then
        setvol -1
    fi
done < <(stdbuf -oL evtest "\$EV" 2>/dev/null)
EOF
    sudo chmod +x /usr/local/bin/bt-volume-monitor.sh
}
