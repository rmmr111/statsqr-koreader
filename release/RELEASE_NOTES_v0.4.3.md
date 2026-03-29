# StatsQR v0.4.3

## Fixed

- Kindle QR URLs now prefer the `wlan0` Wi‑Fi address instead of whichever network interface is discovered first.
- StatsQR now attempts to open the Kindle local firewall automatically while the sharing session is active and closes it again when the session stops.

## Why this release exists

The v0.4.2 cross-device variant worked on Kobo, but some Kindle devices could show a QR code that resolved to an unreachable page. Two practical causes were addressed in this release:

1. the wrong local IP could be chosen on Kindle when multiple interfaces existed;
2. inbound HTTP on the chosen port could be blocked by the Kindle firewall.

## Notes

- Kobo behavior is unchanged.
- Kindle behavior is improved, but still depends on the jailbreak environment and whether the device exposes the necessary firewall tooling.
- If the phone still cannot load the page on Kindle, try another port and inspect the Kindle firewall/network setup.
