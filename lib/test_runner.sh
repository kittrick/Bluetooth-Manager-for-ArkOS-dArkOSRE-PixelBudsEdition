#!/bin/bash
# Small test runner script to call specific internal functions
source /opt/system/Tools/lib/bt_utils.sh

case "$1" in
    powershift) PowerShiftBT ;;
    restore) RestoreWiFi ;;
    repair) RepairStack ;;
    audit) RunAudit ;;
    *) echo "Usage: $0 {powershift|restore|repair|audit}" ;;
esac
