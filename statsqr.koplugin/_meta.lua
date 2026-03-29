local _ = require("gettext")

return {
    name = "statsqr",
    fullname = _("StatsQR"),
    description = _([[Starts a local web server on your KOReader device, shows a QR code on screen, and lets your phone download the file statistics.sqlite3 directly from the device over Wi‑Fi through a temporary private link.]]),
    version = "0.4.4",
}
