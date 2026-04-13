# R36S Bluetooth Manager — Pixel Buds Edition

![Platform](https://img.shields.io/badge/Platform-R36S-blue)
![OS](https://img.shields.io/badge/OS-ArkOS%20|%20dArkOS-green)
![Shell](https://img.shields.io/badge/Bash-Script-yellow)
![License](https://img.shields.io/badge/License-Free-lightgrey)

This updated script, v4.0, attempts to rectify several issues I was encountering pairing wireless Pixel Buds to my R36S. My system is an R36S clone, running dAarkOSRE. I found that the existing script didn't work with my Pixel Buds, so I made a number of modifications to ensure pairing and audio routing worked for me. I also added several useful utilities for debugging like an error log. In my case, an older, BT 4.0 dongle (specifically [this one](https://www.amazon.com/Kinivo-USB-Bluetooth-4-0-Compatible/dp/B007Q45EF4/ref=sr_1_1_sspa?adgrpid=187936273402&dib=eyJ2IjoiMSJ9.8vKxfZvutfcO8T7yMSnXFeAwrfBUbxMvtcWhChpV0ddrVQ1waUEE5Z63MxEPYGQH.R9TUdQeSEcd18Ehrlqh9WjDro4jKvJtBgH2VU55Y_yg&dib_tag=se&hvadid=779502326817&hvdev=c&hvexpln=0&hvlocphy=9032941&hvnetw=g&hvocijid=238494959202933604--&hvqmt=e&hvrand=238494959202933604&hvtargid=kwd-331367752204&hydadcr=18004_13462264_11294&keywords=kinivo%2Bbtd%2B400&mcid=79f2cfb474c63ea4afd36109df4e4b8c&qid=1776082138&sr=8-1-spons&sp_csd=d2lkZ2V0TmFtZT1zcF9hdGY&th=1)) worked better than a newer, BT 5.3 dongle. Your milage may vary. I haven't tested this on other devices.

To Install, place `bt_manager.sh` in `/opt/system/Tools/`. I personally like to do this over scp with a wifi dongle, but you can do it manually by ejecting your SD card and inserting it in yoru computer. From there, I recommend first running option 11, which installs listener daemons that should try to automatically reconnect to known devices. (This part is still WIP)

From there, select option 1 to pair, and option 3 to connect to known devices.

I use the EPIC-CODY theme, and this script is designed to automatically isntall a bluetooth icon into that theme. If you are using a different theme, do a find and replace for `theme-EPIC-CODY` and your theme folder. Again, this hasn't been widely tested, but I assume if you're installing a custom bluetooth manager on your debian based R36S, you might know a thing or two about programming.

Finally, if you are having issues, you can run an audit with option six, read an audit with option eight, or play a test chime with option seven. The log lives at `/home/ark/bt_audit.log`.

Best of luck!

---

Original README from Jason and djparent below:

---

A complete Bluetooth management solution for the **R36XS running on Arkos & dArkOs**.  
Designed for stability, automatic configuration, and seamless audio integration.

Thank's to **djparent** for fix many problem

---

## ✨ Features

- Enable / Disable Bluetooth
- Scan and connect nearby devices
- Pair, trust and auto-connect
- Disconnect active devices
- Forget known devices
- Live Bluetooth status display
- PulseAudio system configuration
- RetroArch & RetroArch32 audio auto-fix
- Hardware volume button integration
- Multilingual interface (EN, FR, ES, PT, IT, DE, PL)

---


## 🔊 Audio Management

- Auto-switch to Bluetooth audio
- Automatic fallback to internal speaker
- Default volume preset
- Real-time hardware volume button handling

---

## 📋 Requirements

- [Realtek firmware ](https://github.com/Jason3x/Realtek-for-ArkOs-and-dArkOS-) (No need arkos AeUX, arkos4clone and dArkOS RE) 
- Internet connection (first-time install only)

---

## 🚀 Installation

1. Download the `Bluetooth Manager.sh` script.
2. Copy it to one of the following directories:
 - roms/tools or
 - roms2/tools
3. Launch it from the Tools section on your device.

---

## ☕ A coffee to support the project?

[![Ko-fi](https://img.shields.io/badge/☕_Buy_me_a_coffee-jason3x-red?style=for-the-badge)](https://ko-fi.com/jason3x)

