# StatsQR for KOReader (Kobo + Kindle)

StatsQR is a KOReader plugin for **Kobo and Kindle** devices that shares the `statistics.sqlite3` database over your local Wi‑Fi and lets you download it on your phone by scanning a QR code shown on the device. KOReader itself supports both Kindle and Kobo, and its contrib plugins are installed under the device's `koreader/plugins` folder.

This repository is the **GitHub-ready source kit** based on **v0.4.4**. The plugin resolves the statistics database from KOReader's settings directory in code, instead of hardcoding a Kobo-only path. KOReader's current documentation also exposes a `datastorage` module, which is the cross-device basis used here.

![Device QR screen example](docs/images/qr-screen-example.png)
![Phone choice page example](docs/images/phone-choice-example.png)

## What it does

- Starts a tiny local HTTP server inside KOReader
- Resolves the file from KOReader's settings directory:
  - `DataStorage:getSettingsDir() .. "/statistics.sqlite3"`
- Shows a QR code on the device
- Shows a **3-digit challenge number above the QR code**
- Opens a small page on the phone where the user must choose the matching number from 3 options
- Downloads only `statistics.sqlite3`
- Stops automatically after 2 minutes

## Device paths shown in documentation

StatsQR resolves the real path dynamically at runtime, but the human-facing examples in the docs are:

- **Kobo:** `\.adds\koreader\settings\statistics.sqlite3`
- **Kindle:** `\koreader\settings\statistics.sqlite3`

## Current version

- Plugin version: **0.4.4**
- Status: **working Kobo release, Kindle compatibility hardening update**
- Menu location: **Settings → StatsQR**

## Repository layout

```text
statsqr-github-kit/
├── .github/workflows/package-release.yml
├── docs/images/
├── release/
├── scripts/
├── statsqr.koplugin/
├── CHANGELOG.md
├── LICENSE
├── README.md
└── README.pt-PT.md
```

## Installation on Kobo

1. Download the release ZIP from the `release/` folder or from GitHub Releases.
2. Extract it.
3. Copy the folder `statsqr.koplugin` to:

   ```text
   .adds/koreader/plugins/
   ```

4. Restart KOReader.

## Installation on Kindle

1. Download the release ZIP from the `release/` folder or from GitHub Releases.
2. Extract it.
3. Copy the folder `statsqr.koplugin` to:

   ```text
   koreader/plugins/
   ```

4. Restart KOReader.

## How to use

On the device:

1. Open the top menu.
2. Go to **Settings**.
3. Open **StatsQR**.
4. Tap **Start sharing statistics.sqlite3**.
5. Scan the QR code with your phone.
6. On the phone, select the same 3-digit number shown above the QR code on the device.
7. The browser downloads `statistics.sqlite3`.

Requirements:

- Device and phone must be on the same Wi‑Fi network
- If Wi‑Fi is off, StatsQR asks whether it should be turned on
- KOReader must remain awake until the download finishes

## Menu items

- **Start sharing statistics.sqlite3**
- **Stop sharing statistics.sqlite3**
- **Show QR code again**
- **Show current number**
- **Show direct URL**
- **About**

## Security model in v0.4.4

StatsQR is designed for **simple local transfer on a trusted home network**.

Current protections:

- Temporary random token in the URL path
- Random 3-digit challenge number shown on the device
- The phone must choose the correct number before download
- No caching headers
- Conservative browser security headers
- Auto-stop after 2 minutes

Important limitation:

- The transfer is still over **local HTTP**
- Some phone browsers may still warn that the file is **not being downloaded securely**
- That warning is expected for plain HTTP, even on a local network

## Troubleshooting

### The phone page does not open
- Make sure both devices are on the same Wi‑Fi
- Keep KOReader open and awake
- If the QR opens inside an in-app preview, use **Open in browser**
- Try **Show direct URL** and type the address manually on the phone
- On Kindle, v0.4.3+ prefers the Wi‑Fi `wlan0` address and also attempts to open the local firewall automatically
- If your Kindle still refuses inbound connections, test another port and verify that your Kindle jailbreak/network tools are not overriding firewall rules

### Wi‑Fi is off when I tap Start sharing
- StatsQR now asks whether Wi‑Fi should be turned on
- After you confirm, the plugin asks KOReader to enable Wi‑Fi and retries automatically
- If your device does not reconnect in time, connect manually and try again

### Download warning on phone
- This version uses local HTTP, not HTTPS
- Some browsers warn for local insecure downloads
- The plugin still works, but the warning may appear

### The file is not found
- StatsQR looks for:
  - `DataStorage:getSettingsDir() .. "/statistics.sqlite3"`
- Human-facing path examples:
  - Kobo: `\.adds\koreader\settings\statistics.sqlite3`
  - Kindle: `\koreader\settings\statistics.sqlite3`
- Open KOReader once and make sure statistics are enabled and have been generated

### Port already in use
- Default port is `8765`
- If you later want, this can be turned into a configurable option in the plugin settings

## Packaging a release

From the repository root:

```bash
bash scripts/package-release.sh
```

This creates a fresh ZIP in the `release/` folder containing only:

```text
statsqr.koplugin/
```

## Publishing on GitHub

Recommended steps:

1. Create a new GitHub repository
2. Upload the contents of this kit
3. Commit and push
4. Create a GitHub Release named `v0.4.4`
5. Attach the ZIP from `release/statsqr.koplugin.v0.4.4.zip`

Suggested repository name:

```text
statsqr-koreader
```

Suggested topics:

```text
koreader
kobo
kindle
lua
plugin
ereader
qr-code
statistics
```

## License

This kit includes an MIT license file as a simple starting point. Review and change it if you want another license.

## Example release text

A ready-to-paste release note is available in:

```text
release/RELEASE_NOTES_v0.4.4.md
```
