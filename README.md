# R36S Bluetooth Manager — Pixel Buds Edition

![Platform](https://img.shields.io/badge/Platform-R36S-blue)
![OS](https://img.shields.io/badge/OS-ArkOS%20|%20dArkOS-green)
![Shell](https://img.shields.io/badge/Bash-Script-yellow)
![License](https://img.shields.io/badge/License-Free-lightgrey)

This updated script, v4.0, attempts to rectify several issues I was encountering pairing wireless Pixel Buds to my R36S. My system is an R36S clone, running dAarkOSRE. I found that the existing script didn't work with my Pixel Buds, so I made a number of modifications to ensure pairing and audio routing worked for me. I also added several useful utilities for debugging like an error log. In my case, an older, BT 4.0 dongle (specifically [this one](https://www.amazon.com/Kinivo-USB-Bluetooth-4-0-Compatible/dp/B007Q45EF4/ref=sr_1_1_sspa?adgrpid=187936273402&dib=eyJ2IjoiMSJ9.8vKxfZvutfcO8T7yMSnXFeAwrfBUbxMvtcWhChpV0ddrVQ1waUEE5Z63MxEPYGQH.R9TUdQeSEcd18Ehrlqh9WjDro4jKvJtBgH2VU55Y_yg&dib_tag=se&hvadid=779502326817&hvdev=c&hvexpln=0&hvlocphy=9032941&hvnetw=g&hvocijid=238494959202933604--&hvqmt=e&hvrand=238494959202933604&hvtargid=kwd-331367752204&hydadcr=18004_13462264_11294&keywords=kinivo%2Bbtd%2B400&mcid=79f2cfb474c63ea4afd36109df4e4b8c&qid=1776082138&sr=8-1-spons&sp_csd=d2lkZ2V0TmFtZT1zcF9hdGY&th=1)) worked better than a newer, BT 5.3 dongle. Your milage may vary. I haven't tested this on other devices.

Best of luck!

---

_Built upon the incredible foundation of the original dArkOS Bluetooth Manager by_ _**Jason**_ _and_ _**djparent**__._

---

✨ Key Features
--------------

**The Autonomous Daemon (New in v4.0)**

*   **Zero-Touch Connections:** A background daemon silently monitors your hardware. Boot the system or hot-plug your BT dongle, and it will automatically find your trusted headphones, route the audio, and update your UI icon.
    
*   **Multipoint Focus Stealing:** Blasts an inaudible 20Hz data stream upon connection to forcefully steal priority from your smartphone.
    
*   **Retro Audio Cue:** Plays a native PulseAudio C-Major arpeggio (C5-E5-G5-C6) directly into your headphones to confirm a successful connection.
    

**Core Functionality**

*   Enable / Disable Bluetooth
    
*   Scan, pair, trust, and auto-connect to nearby devices
    
*   Disconnect or forget known devices
    
*   PulseAudio system configuration and RetroArch audio auto-fixing
    
*   Real-time hardware volume button handling
    
*   Multilingual interface (EN, FR, ES, PT, IT, DE, PL)
    

📋 Requirements & Hardware Notes
--------------------------------

*   **Internet Connection:** ⚠️ **CRITICAL:** An active Wi-Fi connection is required on the first run to download and install the necessary Linux audio and Bluetooth dependencies.
    
*   **Bluetooth Dongle:** Modern TWS earbuds can be incredibly picky about Linux drivers. During testing on an R36S clone, an older BT 4.0 dongle (specifically the [Kinivo BTD-400](https://www.amazon.com/Kinivo-USB-Bluetooth-4-0-Compatible/dp/B007Q45EF4)) successfully maintained stable audio routing, whereas a newer BT 5.3 dongle failed. Your mileage may vary.
    
*   **Firmware:** [Realtek firmware](https://github.com/Jason3x/Realtek-for-ArkOs-and-dArkOS-) may be required depending on your OS version (No need for ArkOS AeUX, arkos4clone, or dArkOS RE).
    

🚀 Installation & Setup
-----------------------

1.  Download the bt\_manager.sh script.
    
2.  Copy it to your tools directory via SD card reader or SCP:
    
    *   /roms/tools/ (or /roms2/tools/) <- SD Card
        
    *   /opt/system/Tools/ <- This is the actual folder used by Emulation Station, better if you use SCP
        
3.  Launch it from the **Tools** section on your R36S device.
    

### Initial Configuration

For the best experience, follow these steps on your first run:

1.  Ensure your Wi-Fi dongle is connected and you have internet access.
    
2.  Select **Option 11 (System Setup)**. This is a run-once installer that patches PulseAudio, generates your UI icons, and activates the background auto-connect daemons.
    
3.  Unplug your Wi-Fi dongle, plug in your Bluetooth dongle, and select **Option 2 (Scan and Connect)** to pair your earbuds.
    
4.  In the future, simply select **Option 3 (Known Devices)** or let the background daemon auto-connect them for you!
    

> **🎨 UI Theme Note:** This script dynamically updates the top-bar Bluetooth icon. By default, it is hardcoded to look for the **EPIC-CODY** theme folder. If you use a different theme, open the script in a text editor and do a find-and-replace, changing theme-EPIC-CODY to your specific theme folder name.

🛠️ Troubleshooting & Debugging
-------------------------------

If you are having issues getting audio to route or devices to pair, v4.0 includes a suite of onboard debugging tools:

*   **Perform System Audit (Option 6):** Takes a snapshot of your USB bus, loaded drivers, PulseAudio sinks, and kernel logs, saving them to /home/ark/bt\_audit.log.
    
*   **Read Last Audit (Option 8):** Acts as an auto-scrolling teleprompter so you can read the audit log directly on your R36S screen without needing to SSH into the device.
    
*   **Play Test Chime (Option 7):** Pushes a native 440Hz test tone directly into PulseAudio to verify if the software pipes are connected to your headphones, bypassing EmulationStation entirely.
    
*   **Power-Shift (Option 9):** Wi-Fi and Bluetooth share the same low-powered USB bus and 2.4GHz spectrum. Use this to forcefully kill the Wi-Fi drivers and prioritize the Bluetooth radio to prevent interference. Note, I haven't yet found any combo bluetooth wifi dongles that work with R36S. I believe the OTG port is simply too low power to do both at the same time, but I could be wrong.
    

☕ Support the Original Creators
-------------------------------

If you love the foundation of this script, please consider supporting the original author, Jason:

[![Ko-fi](https://img.shields.io/badge/☕_Buy_me_a_coffee-jason3x-red?style=for-the-badge)](https://ko-fi.com/jason3x)

