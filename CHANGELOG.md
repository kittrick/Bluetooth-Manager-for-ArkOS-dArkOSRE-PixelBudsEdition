# Changelog
All notable changes to this project will be documented in this file.

## [3.7.0] - 2026-04-18
- Modularized codebase into `lib/` directory for better maintainability.
- Added autonomous Power-Shift diagnostic tool for hardware troubleshooting.
- Improved device discovery with dual-mode (Classic + LE) filtering.
- Implemented robust `rtk_btusb` driver initialization for combo dongles.
- Added branch selection to OTA update mechanism.
- Streamlined localization by moving strings to `lib/locale.sh`.
