# R36S Bluetooth Manager — Pixel Buds Edition

![Platform](https://img.shields.io/badge/Platform-R36S-blue)
![OS](https://img.shields.io/badge/OS-ArkOS%20|%20dArkOS-green)
![Shell](https://img.shields.io/badge/Bash-Script-yellow)
![License](https://img.shields.io/badge/License-Free-lightgrey)

This updated script, v4.0, rectifies issues encountered while pairing wireless Pixel Buds to the R36S. It includes numerous modifications to ensure stable pairing and audio routing.

---

### 📋 Credits
Built upon the incredible foundation of the original dArkOS Bluetooth Manager by **Jason** and **djparent**.

---

✨ Key Features
--------------

**The Autonomous Daemon (New in v4.0)**

*   **Zero-Touch Connections:** A background daemon silently monitors your hardware. Boot the system or hot-plug your BT dongle, and it will automatically find your trusted headphones, route the audio, and update your UI icon.
*   **Retro Audio Cue:** Plays a native PulseAudio C-Major arpeggio (C5-E5-G5-C6) directly into your headphones to confirm a successful connection.

**Core Functionality**

*   Enable / Disable Bluetooth
*   Scan, pair, trust, and auto-connect to nearby devices
*   Disconnect or forget known devices
*   PulseAudio system configuration and RetroArch audio auto-fixing
*   Real-time hardware volume button handling
*   Multilingual interface (EN, FR, ES, PT, IT, DE, PL)

🚀 Installation & Setup
-----------------------

1.  Download the `bt_manager.sh` script and the `lib/` directory.
2.  Copy them to your tools directory via SD card reader or SCP (e.g., `/opt/system/Tools/`).
3.  Launch from the **Tools** section on your R36S device.

### Initial Configuration

1.  Ensure your Wi-Fi dongle is connected and you have internet access.
2.  Select **Option 12 (System Setup)** to patch PulseAudio and activate background daemons.
3.  Use **Option 2 (Scan and Connect)** to pair your earbuds.

🛠️ Troubleshooting & Debugging
-------------------------------

*   **Perform System Audit (Option 7):** Snapshot hardware/driver state to `/tmp/bt_audit.log`.
*   **Repair Bluetooth Stack (Option 14):** Deep-reset Bluetooth hardware/drivers.
*   **Play Test Chime (Option 8):** Verify PulseAudio routing with a 440Hz test tone.
*   **Power-Shift (Option 10):** Force priority to Bluetooth by disabling Wi-Fi.

EOF
