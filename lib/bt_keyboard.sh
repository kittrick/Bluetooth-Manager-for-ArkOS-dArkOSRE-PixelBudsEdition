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
