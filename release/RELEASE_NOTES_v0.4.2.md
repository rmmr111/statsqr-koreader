# StatsQR v0.4.2

StatsQR is a KOReader plugin for Kobo and Kindle devices that lets you download `statistics.sqlite3` directly to your phone over local Wi‑Fi by scanning a QR code on the device.

## Highlights

- Settings menu integration
- QR code shown directly on the device
- 3-digit challenge number shown above the QR code
- Phone page with 3 random choices
- Temporary tokenized local URL
- Auto-stop after 10 minutes
- Cross-device documentation for Kobo + Kindle

## Install on Kobo

1. Download `statsqr.koplugin.v0.4.2.zip`
2. Extract it
3. Copy `statsqr.koplugin` to `.adds/koreader/plugins/`
4. Restart KOReader

## Install on Kindle

1. Download `statsqr.koplugin.v0.4.2.zip`
2. Extract it
3. Copy `statsqr.koplugin` to `koreader/plugins/`
4. Restart KOReader

## Notes

- Both devices must be on the same Wi‑Fi network
- This version uses local HTTP
- Some mobile browsers may still warn about insecure downloads on local HTTP
- Human-facing path examples:
  - Kobo: `\.adds\koreader\settings\statistics.sqlite3`
  - Kindle: `\koreader\settings\statistics.sqlite3`
