
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
