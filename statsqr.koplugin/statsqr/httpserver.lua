local logger = require("logger")
local socket = require("socket")
local UIManager = require("ui/uimanager")

local HttpServer = {
    bind_ip = "*",
    port = 8765,
    file_path = nil,
    access_token = nil,
    access_choice = nil,
    choice_options = nil,
    _server_socket = nil,
    _running = false,
}

function HttpServer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function HttpServer:start()
    local server, err = socket.bind(self.bind_ip or "*", self.port)
    if not server then
        error("Could not bind to port " .. tostring(self.port) .. ": " .. tostring(err))
    end

    server:settimeout(0)
    self._server_socket = server
    self._running = true
    self:_schedulePoll()
    logger.info("StatsQR HTTP: listening on ", self.bind_ip or "*", ":", self.port)
end

function HttpServer:stop()
    self._running = false
    if self._server_socket then
        self._server_socket:close()
        self._server_socket = nil
    end
    logger.info("StatsQR HTTP: server stopped")
end

function HttpServer:_schedulePoll()
    if not self._running then
        return
    end
    UIManager:scheduleIn(0.1, function()
        self:_poll()
    end)
end

function HttpServer:_poll()
    if not self._running or not self._server_socket then
        return
    end

    for _ = 1, 4 do
        local client = self._server_socket:accept()
        if not client then
            break
        end

        client:settimeout(5)
        local ok, err = pcall(function()
            self:_handleClient(client)
        end)
        if not ok then
            logger.warn("StatsQR HTTP: request failed: ", err)
            pcall(function()
                self:_sendError(client, 500, "Internal Server Error")
            end)
        end
        pcall(function()
            client:close()
        end)
    end

    self:_schedulePoll()
end

function HttpServer:_parseQuery(path)
    local query = path:match("%?(.*)$")
    if not query then
        return {}
    end
    local args = {}
    for part in query:gmatch("[^&]+") do
        local key, value = part:match("^([^=]+)=?(.*)$")
        if key then
            value = value:gsub("%+", " "):gsub("%%(%x%x)", function(hex)
                return string.char(tonumber(hex, 16))
            end)
            args[key] = value
        end
    end
    return args
end

function HttpServer:_tokenFromPath(path)
    local path_only = path:match("^([^?]+)") or path
    local path_token = path_only:match("^/t/([%w%-_]+)$")
    if path_token then
        return path_token
    end
    local download_token = path_only:match("^/download/([%w%-_]+)/")
    if download_token then
        return download_token
    end
    return nil
end

function HttpServer:_hasValidToken(path)
    if not self.access_token then
        return true
    end
    local path_token = self:_tokenFromPath(path)
    if path_token then
        return path_token == self.access_token
    end
    local args = self:_parseQuery(path)
    return args.token == self.access_token
end

function HttpServer:_hasValidChoice(path)
    if not self.access_choice then
        return true
    end
    local path_only = path:match("^([^?]+)") or path
    local path_choice = path_only:match("^/download/[%w%-_]+/([%w%-_]+)$")
    if path_choice then
        return path_choice == self.access_choice
    end
    local args = self:_parseQuery(path)
    return args.choice == self.access_choice
end

function HttpServer:_renderChoiceButtons(token)
    local out = {}
    local options = self.choice_options or {}
    for _, option in ipairs(options) do
        out[#out + 1] = table.concat({
            [[<a class="choice-link" href="/download/]], token, [[/]], option, [[">]], option, [[</a>]],
        })
    end
    return table.concat(out)
end

function HttpServer:_handleClient(client)
    local request_line = client:receive("*l")
    if not request_line then
        self:_sendError(client, 400, "Bad Request")
        return
    end

    local method, path = request_line:match("^(%S+)%s+(%S+)%s+")
    if not method or not path then
        self:_sendError(client, 400, "Bad Request")
        return
    end

    while true do
        local line = client:receive("*l")
        if not line or line == "" then
            break
        end
    end

    local path_only = path:match("^([^?]+)") or path

    if method ~= "GET" and method ~= "HEAD" then
        self:_sendError(client, 405, "Method Not Allowed")
        return
    end

    if path_only ~= "/favicon.ico" and not self:_hasValidToken(path) then
        self:_sendError(client, 403, "Forbidden")
        return
    end

    if path_only == "/" or path_only:match("^/t/[%w%-_]+$") then
        self:_sendChoicePage(client, method, false)
        return
    end

    if path_only == "/download" or path_only:match("^/download/[%w%-_]+/[%w%-_]+$") then
        if not self:_hasValidChoice(path) then
            self:_sendChoicePage(client, method, true)
            return
        end
        self:_sendFile(client, method)
        return
    end

    if path_only == "/favicon.ico" then
        self:_sendNoContent(client)
        return
    end

    self:_sendError(client, 404, "Not Found")
end

function HttpServer:_commonHeaders(extra)
    local headers = {
        ["Cache-Control"] = "no-store, max-age=0",
        ["Connection"] = "close",
        ["Referrer-Policy"] = "no-referrer",
        ["X-Content-Type-Options"] = "nosniff",
        ["X-Frame-Options"] = "DENY",
        ["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
        ["Permissions-Policy"] = "accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), geolocation=(), gyroscope=(), microphone=(), payment=(), usb=()",
        ["X-Robots-Tag"] = "noindex, nofollow, noarchive",
    }
    if extra then
        for k, v in pairs(extra) do
            headers[k] = v
        end
    end
    return headers
end

function HttpServer:_sendChoicePage(client, method, show_error)
    local filename = self.file_path:match("([^/]+)$") or "statistics.sqlite3"
    local token = self.access_token or ""
    local error_html = ""
    if show_error then
        error_html = [[<p class="error">That was not the correct number. Choose the same number that appears above the QR code on your device.</p>]]
    end

    local body = table.concat({
        [[<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>StatsQR - KOReader Statistics download</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:42rem;margin:2rem auto;padding:0 1rem;line-height:1.55;color:#111}
.card{border:1px solid #d9d9d9;border-radius:1rem;padding:1.25rem 1rem;background:#fff}
h1{font-family:Georgia,'Times New Roman',serif;font-size:2rem;line-height:1.15;margin:0 0 .3rem}
.subtitle{font-size:1rem;margin:0 0 1rem;color:#333}
.choices{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:.75rem;margin:1rem 0}
.choice-link{display:block;width:100%;padding:1rem .5rem;border:1px solid #111;border-radius:.9rem;background:#fff;color:#111;font-weight:700;font-size:1.5rem;letter-spacing:.06em;text-decoration:none;text-align:center;box-sizing:border-box}
small{display:block;color:#444;margin-top:1rem}
.muted{color:#666}
.error{margin:.85rem 0;color:#8a1c1c;font-weight:600}
@media (max-width:560px){.choices{grid-template-columns:1fr}}
</style>
</head><body>
<div class="card">
<h1>StatsQR - KOReader Statistics download</h1>
<p class="subtitle">Save your most recent stats in your smartphone</p>
<p>Select the same number shown <strong>above the QR code on your device</strong> to unlock the download of <strong>]],
        filename,
        [[</strong>.</p>]],
        error_html,
        [[<div class="choices">]],
        self:_renderChoiceButtons(token),
        [[</div>
<p class="muted">The exact save location is controlled by your phone browser or download manager.</p>
<small>Keep the device awake and on the same Wi‑Fi network until the download finishes. This temporary link works only while sharing is active. If your phone browser opens an isolated in-app preview, use its “open in browser” option.</small>
</div>
</body></html>]],
    })

    self:_sendResponse(client, show_error and 403 or 200, show_error and "Forbidden" or "OK", self:_commonHeaders({
        ["Content-Type"] = "text/html; charset=utf-8",
        ["Content-Length"] = tostring(#body),
    }), method == "HEAD" and nil or body)
end

function HttpServer:_sendFile(client, method)
    local file = io.open(self.file_path, "rb")
    if not file then
        self:_sendError(client, 404, "File Not Found")
        return
    end

    local size = file:seek("end") or 0
    file:seek("set", 0)
    local filename = self.file_path:match("([^/]+)$") or "statistics.sqlite3"

    self:_sendResponse(client, 200, "OK", self:_commonHeaders({
        ["Content-Type"] = "application/octet-stream",
        ["Content-Disposition"] = string.format('attachment; filename="%s"', filename),
        ["Content-Length"] = tostring(size),
    }), nil)

    if method ~= "HEAD" then
        while true do
            local chunk = file:read(65536)
            if not chunk then
                break
            end
            local ok, err = self:_sendAll(client, chunk)
            if not ok then
                logger.warn("StatsQR HTTP: send chunk failed: ", err)
                break
            end
        end
    end

    file:close()
end

function HttpServer:_sendNoContent(client)
    self:_sendResponse(client, 204, "No Content", self:_commonHeaders({
        ["Content-Length"] = "0",
    }), nil)
end

function HttpServer:_sendError(client, status, message)
    local body = string.format("<h1>%d %s</h1>", status, message)
    self:_sendResponse(client, status, message, self:_commonHeaders({
        ["Content-Type"] = "text/html; charset=utf-8",
        ["Content-Length"] = tostring(#body),
    }), body)
end

function HttpServer:_sendResponse(client, status, status_text, headers, body)
    local lines = { string.format("HTTP/1.1 %d %s\r\n", status, status_text) }
    for key, value in pairs(headers) do
        lines[#lines + 1] = string.format("%s: %s\r\n", key, value)
    end
    lines[#lines + 1] = "\r\n"
    local ok, err = self:_sendAll(client, table.concat(lines))
    if not ok then
        return nil, err
    end
    if body and #body > 0 then
        return self:_sendAll(client, body)
    end
    return true
end

function HttpServer:_sendAll(client, data)
    local index = 1
    while index <= #data do
        local sent, err, partial = client:send(data, index)
        if sent then
            index = sent + 1
        else
            if partial and partial >= index then
                index = partial + 1
            else
                return nil, err or "send failed"
            end
        end
    end
    return true
end

return HttpServer
