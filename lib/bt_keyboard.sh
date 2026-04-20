#!/bin/bash

# -------------------------------------------------------
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
        dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --msgbox "\n $T_NO_DEVICE\n\nCheck /tmp/bt_audit.log for details." 10 45 > "$CURR_TTY"
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
        
        d_mac_list[$index]="$mac"
        doptions+=("$index" "$name ($mac)")
        index=$((index + 1))
    done < <(bluetoothctl devices)

    if [ ${#doptions[@]} -eq 0 ]; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_INFO" --msgbox "\n $T_NOTHING_DEL" 7 35 > "$CURR_TTY"
        return
    fi

    dselection=$(dialog --backtitle "$T_BACKTITLE" --title "$T_DELETE_TITLE" --menu "$T_CHOOSE_DEL" 15 50 8 "${doptions[@]}" 2>&1 > "$CURR_TTY")
    
    if [ $? -eq 0 ]; then
        # Use the mapped MAC address for the removal command
        bluetoothctl remove "${d_mac_list[$dselection]}" > /dev/null 2>&1
        dialog --backtitle "$T_BACKTITLE" --title "$T_SUCCESS" --msgbox "\n $T_FORGOTTEN" 7 30 > "$CURR_TTY"
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
        echo "--- FAILED PAIRING LOG ---" >> /tmp/bt_audit.log
        cat /tmp/bt_pair.log >> /tmp/bt_audit.log 2>/dev/null
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
