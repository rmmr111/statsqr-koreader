# Changelog

All notable changes to this project are documented in this file.

## [0.4.4] - 2026-03-29

### Changed
- Reduced the automatic sharing timeout from 10 minutes to 2 minutes
- When the user starts sharing with Wi‑Fi off, StatsQR now asks whether Wi‑Fi should be turned on

### Behavior
- After confirmation, the plugin asks KOReader to bring Wi‑Fi online and retries automatically once networking is ready

## [0.4.3] - 2026-03-29

### Fixed
- Hardened Kindle compatibility for local page loading
- Prefer the Kindle `wlan0` Wi‑Fi address when building the QR URL
- Attempt to open and close the Kindle local firewall automatically for the active TCP port

### Documentation
- Improved Kindle troubleshooting notes in the README files

## [0.4.2] - 2026-03-29

### Added
- Added Kindle-ready repository and documentation variant
- Added device-aware human-facing path hints for Kobo and Kindle

### Changed
- Replaced Kobo-specific UI and phone-page wording with generic device wording
- Updated GitHub kit, release notes, and installation instructions for Kobo + Kindle

## [0.4.1] - 2026-03-29

### Changed
- Server now listens on all Kobo interfaces while still displaying the detected local Wi‑Fi IP in the QR code URL
- Session token is now embedded in the URL path for better compatibility with QR scanners and in-app browsers
- Removed the extra popup after showing the QR screen so the QR code remains unobstructed

### Security and behavior
- Temporary tokenized local link
- 3-digit challenge selection flow
- Auto-stop after 10 minutes
- No-cache and restrictive response headers

## [0.4.0] - 2026-03-29

### Added
- Replaced typed PIN flow with a simpler challenge-choice flow
- Kobo now shows one 3-digit number above the QR code
- Phone page shows 3 random number choices
- Added menu action to show the current number again

## [0.3.1] - 2026-03-29

### Changed
- Increased the on-screen PIN size on the Kobo for better visibility

## [0.3.0] - 2026-03-29

### Added
- Added a 6-digit PIN gate before the download page could unlock the file

## [0.2.0] - 2026-03-29

### Changed
- Moved the plugin entry to the Settings menu
- Updated the phone page title and subtitle
- Added stronger cache and browser security headers

## [0.1.0] - 2026-03-29

### Added
- Initial working release
- Local HTTP server
- QR code flow
- Direct download of `statistics.sqlite3`
