local DataStorage = require("datastorage")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local socket = require("socket")
local _ = require("gettext")
local T = require("ffi/util").template

local Manager = {
    _running = false,
    _server = nil,
    _ip = nil,
    _port = nil,
    _qr_widget = nil,
    _auto_stop_callback = nil,
    _standby_prevented = false,
    _session_token = nil,
    _challenge_value = nil,
    _challenge_options = nil,
    _firewall_rule_opened = false,
    _firewall_cmd = nil,
    _wifi_wait_callback = nil,
    _wifi_wait_attempts = 0,
}

local DEFAULT_PORT = 8765
local AUTO_STOP_SECONDS = 120

local function shell_success(command)
    local ok, why, code = os.execute(command .. " >/dev/null 2>&1")
    if type(ok) == "number" then
        return ok == 0
    end
    if ok == true then
        return true
    end
    return why == "exit" and code == 0
end

local function read_random_hex(num_bytes)
    local handle = io.open("/dev/urandom", "rb")
    if handle then
        local data = handle:read(num_bytes)
        handle:close()
        if data and #data > 0 then
            return (data:gsub(".", function(c)
                return string.format("%02x", string.byte(c))
            end))
        end
    end

    math.randomseed(os.time() + math.floor((socket.gettime and socket.gettime() or 0) * 1000000))
    local out = {}
    for _ = 1, num_bytes do
        out[#out + 1] = string.format("%02x", math.random(0, 255))
    end
    return table.concat(out)
end

local function read_random_index(limit)
    if limit <= 1 then
        return 1
    end
    local hex = read_random_hex(2)
    local value = tonumber(hex, 16) or 1
    return (value % limit) + 1
end

local function shuffle_in_place(values)
    for i = #values, 2, -1 do
        local j = read_random_index(i)
        values[i], values[j] = values[j], values[i]
    end
    return values
end

local function read_random_number_string(length)
    local hex = read_random_hex(math.max(4, length))
    local digits = {}
    for i = 1, #hex do
        digits[#digits + 1] = tostring((tonumber(hex:sub(i, i), 16) or 0) % 10)
        if #digits >= length then
            break
        end
    end
    while #digits < length do
        digits[#digits + 1] = tostring(math.random(0, 9))
    end
    if digits[1] == "0" then
        digits[1] = tostring(math.random(1, 9))
    end
    return table.concat(digits)
end

function Manager:getPort()
    if self._port then
        return self._port
    end
    self._port = G_reader_settings:readSetting("statsqr_port", DEFAULT_PORT)
    return self._port
end

function Manager:isKindleDevice()
    local ok, result = pcall(function()
        return Device:isKindle()
    end)
    return ok and result or false
end

function Manager:isKoboDevice()
    local ok, result = pcall(function()
        return Device:isKobo()
    end)
    return ok and result or false
end

function Manager:getDeviceLabel()
    if self:isKindleDevice() then
        return "Kindle"
    end
    if self:isKoboDevice() then
        return "Kobo"
    end
    return _("device")
end

function Manager:getDisplayStatisticsPath()
    if self:isKindleDevice() then
        return [[\koreader\settings\statistics.sqlite3]]
    end
    if self:isKoboDevice() then
        return [[\.adds\koreader\settings\statistics.sqlite3]]
    end
    return DataStorage:getSettingsDir() .. "/statistics.sqlite3"
end

function Manager:getStatisticsPath()
    return DataStorage:getSettingsDir() .. "/statistics.sqlite3"
end

function Manager:fileExists(path)
    local handle = io.open(path, "rb")
    if handle then
        handle:close()
        return true
    end
    return false
end

function Manager:_findShellCommand(candidates)
    for _, candidate in ipairs(candidates) do
        if candidate:find("/") then
            if self:fileExists(candidate) then
                return candidate
            end
        elseif shell_success("command -v " .. candidate) then
            return candidate
        end
    end
    return nil
end

function Manager:getKindleWlanIP()
    if not self:isKindleDevice() then
        return nil
    end

    local commands = {
        "ifconfig wlan0 2>/dev/null",
        "ip -4 addr show dev wlan0 2>/dev/null",
    }

    for _, command in ipairs(commands) do
        local fd = io.popen(command)
        if fd then
            local output = fd:read("*all")
            fd:close()
            if output and #output > 0 then
                local ip = output:match("inet addr:(%d+%.%d+%.%d+%.%d+)")
                    or output:match("inet%s+(%d+%.%d+%.%d+%.%d+)")
                if ip and ip ~= "0.0.0.0" and ip ~= "127.0.0.1" then
                    return ip
                end
            end
        end
    end

    return nil
end

function Manager:openKindleFirewallPort()
    if not self:isKindleDevice() then
        return true
    end
    if self._firewall_rule_opened then
        return true
    end

    local iptables = self:_findShellCommand({ "/usr/sbin/iptables", "/sbin/iptables", "iptables" })
    if not iptables then
        logger.warn("StatsQR: Kindle firewall auto-open skipped because iptables was not found")
        return nil, "iptables not found"
    end

    local port = tonumber(self:getPort()) or DEFAULT_PORT
    local rules = {
        string.format("%s -I INPUT -i wlan0 -p tcp --dport %d -j ACCEPT", iptables, port),
        string.format("%s -I INPUT -p tcp --dport %d -j ACCEPT", iptables, port),
    }

    for _, rule in ipairs(rules) do
        if shell_success(rule) then
            self._firewall_cmd = iptables
            self._firewall_rule_opened = true
            logger.info("StatsQR: opened Kindle firewall for TCP port ", port)
            return true
        end
    end

    logger.warn("StatsQR: failed to add Kindle firewall rule for TCP port ", port)
    return nil, "iptables rule failed"
end

function Manager:closeKindleFirewallPort()
    if not self:isKindleDevice() or not self._firewall_rule_opened then
        self._firewall_cmd = nil
        self._firewall_rule_opened = false
        return
    end

    local iptables = self._firewall_cmd or self:_findShellCommand({ "/usr/sbin/iptables", "/sbin/iptables", "iptables" })
    if not iptables then
        self._firewall_cmd = nil
        self._firewall_rule_opened = false
        return
    end

    local port = tonumber(self:getPort()) or DEFAULT_PORT
    local rules = {
        string.format("%s -D INPUT -i wlan0 -p tcp --dport %d -j ACCEPT", iptables, port),
        string.format("%s -D INPUT -p tcp --dport %d -j ACCEPT", iptables, port),
    }

    for _, rule in ipairs(rules) do
        for _ = 1, 3 do
            if not shell_success(rule) then
                break
            end
        end
    end

    logger.info("StatsQR: closed Kindle firewall for TCP port ", port)
    self._firewall_cmd = nil
    self._firewall_rule_opened = false
end

function Manager:getLocalIP()
    local kindle_wlan_ip = self:getKindleWlanIP()
    if kindle_wlan_ip then
        return kindle_wlan_ip
    end

    if NetworkMgr and NetworkMgr.getLocalIpAddress then
        local ip = NetworkMgr:getLocalIpAddress()
        if ip and ip ~= "0.0.0.0" and ip ~= "127.0.0.1" then
            return ip
        end
    end

    local udp = socket.udp()
    if udp then
        udp:setpeername("8.8.8.8", 80)
        local ip = udp:getsockname()
        udp:close()
        if ip and ip ~= "0.0.0.0" and ip ~= "127.0.0.1" then
            return ip
        end
    end

    local fd = io.popen("ifconfig 2>/dev/null || ip addr show 2>/dev/null")
    if fd then
        local output = fd:read("*all")
        fd:close()
        if output then
            for ip in output:gmatch("inet%s+(%d+%.%d+%.%d+%.%d+)") do
                if ip ~= "127.0.0.1" then
                    return ip
                end
            end
        end
    end

    return nil
end

function Manager:_cancelWifiWait()
    if self._wifi_wait_callback then
        UIManager:unschedule(self._wifi_wait_callback)
        self._wifi_wait_callback = nil
    end
    self._wifi_wait_attempts = 0
end

function Manager:_isWifiOn()
    local ok, result = pcall(function()
        return NetworkMgr and NetworkMgr:isWifiOn()
    end)
    return ok and result or false
end

function Manager:_checkWifiReadyAndStart()
    if self._running then
        self:_cancelWifiWait()
        return
    end

    if self:_isWifiOn() then
        local ip = self:getLocalIP()
        if ip then
            self:_cancelWifiWait()
            self:start(true)
            return
        end
    end

    self._wifi_wait_attempts = (self._wifi_wait_attempts or 0) + 1
    if self._wifi_wait_attempts >= 15 then
        self:_cancelWifiWait()
        UIManager:show(InfoMessage:new{
            text = _("Could not bring Wi‑Fi online in time. Please connect to Wi‑Fi and try again."),
            timeout = 5,
        })
        return
    end

    self._wifi_wait_callback = function()
        self._wifi_wait_callback = nil
        self:_checkWifiReadyAndStart()
    end
    UIManager:scheduleIn(2, self._wifi_wait_callback)
end

function Manager:_requestWifiThenStart()
    self:_cancelWifiWait()

    local handled = false

    if NetworkMgr and NetworkMgr.turnOnWifi then
        local ok, err = pcall(function()
            NetworkMgr:turnOnWifi()
        end)
        if ok then
            handled = true
        else
            logger.warn("StatsQR: NetworkMgr:turnOnWifi() failed: ", tostring(err))
        end
    end

    if not handled and NetworkMgr and NetworkMgr.turnOnWifiAndWaitForConnection then
        local ok, err = pcall(function()
            NetworkMgr:turnOnWifiAndWaitForConnection()
        end)
        if ok then
            handled = true
        else
            logger.warn("StatsQR: NetworkMgr:turnOnWifiAndWaitForConnection() failed: ", tostring(err))
        end
    end

    if not handled and NetworkMgr and NetworkMgr.goOnlineToRun then
        local ok, err = pcall(function()
            NetworkMgr:goOnlineToRun(function()
                self:_cancelWifiWait()
                self:start(true)
            end)
        end)
        if ok then
            handled = true
        else
            logger.warn("StatsQR: NetworkMgr:goOnlineToRun() failed: ", tostring(err))
        end
    end

    if not handled then
        UIManager:show(InfoMessage:new{
            text = _("Could not ask KOReader to turn Wi‑Fi on automatically. Please enable Wi‑Fi and try again."),
            timeout = 5,
        })
        return
    end

    UIManager:show(InfoMessage:new{
        text = _("Turning Wi‑Fi on…"),
        timeout = 2,
    })
    self:_checkWifiReadyAndStart()
end

function Manager:_promptToEnableWifi()
    UIManager:show(ConfirmBox:new{
        text = _("Wi‑Fi is turned off. Do you want to turn it on now?"),
        ok_text = _("Turn on"),
        ok_callback = function()
            self:_requestWifiThenStart()
        end,
    })
end

function Manager:isRunning()
    return self._running
end

function Manager:getURL()
    if not self._ip or not self._session_token then
        return nil
    end
    return string.format("http://%s:%d/t/%s", self._ip, self._port, self._session_token)
end

function Manager:getSessionToken()
    if not self._session_token then
        self._session_token = read_random_hex(16)
    end
    return self._session_token
end

function Manager:getChallengeValue()
    if not self._challenge_value then
        self._challenge_value = read_random_number_string(3)
    end
    return self._challenge_value
end

function Manager:getChallengeOptions()
    if not self._challenge_options then
        local correct = self:getChallengeValue()
        local options = { correct }
        local seen = { [correct] = true }
        while #options < 3 do
            local candidate = read_random_number_string(3)
            if not seen[candidate] then
                seen[candidate] = true
                options[#options + 1] = candidate
            end
        end
        self._challenge_options = shuffle_in_place(options)
    end
    return self._challenge_options
end

function Manager:_cancelAutoStop()
    if self._auto_stop_callback then
        UIManager:unschedule(self._auto_stop_callback)
        self._auto_stop_callback = nil
    end
end

function Manager:_scheduleAutoStop()
    self:_cancelAutoStop()
    self._auto_stop_callback = function()
        self._auto_stop_callback = nil
        if self._running then
            self:stop(true)
            UIManager:show(InfoMessage:new{
                text = _("Statistics sharing stopped automatically after 2 minutes."),
                timeout = 4,
            })
        end
    end
    UIManager:scheduleIn(AUTO_STOP_SECONDS, self._auto_stop_callback)
end

function Manager:preventStandby()
    if self._standby_prevented then
        return
    end

    UIManager:preventStandby()

    local ok, PluginShare = pcall(require, "pluginshare")
    if ok and PluginShare then
        PluginShare.pause_auto_suspend = true
    end

    self._standby_prevented = true
end

function Manager:allowStandby()
    if not self._standby_prevented then
        return
    end

    local ok, PluginShare = pcall(require, "pluginshare")
    if ok and PluginShare then
        PluginShare.pause_auto_suspend = nil
    end

    UIManager:allowStandby()
    self._standby_prevented = false
end

function Manager:closeQRCode()
    if self._qr_widget then
        UIManager:close(self._qr_widget)
        self._qr_widget = nil
    end
end

function Manager:showChallengeValue()
    if not self._running then
        UIManager:show(InfoMessage:new{
            text = _("The statistics sharing server is not running."),
            timeout = 3,
        })
        return
    end

    UIManager:show(InfoMessage:new{
        text = T(_("StatsQR number\n\n%1\n\nSelect this same number on your phone to unlock the download."), self:getChallengeValue()),
        font_size = 48,
        show_icon = false,
        timeout = 12,
    })
end

function Manager:showQRCode()
    if not self._running then
        UIManager:show(InfoMessage:new{
            text = _("The statistics sharing server is not running."),
            timeout = 3,
        })
        return
    end

    self:closeQRCode()
    local ChoiceQRMessage = require("statsqr/choiceqrmessage")
    self._qr_widget = ChoiceQRMessage:new{
        text = self:getURL(),
        challenge_value = self:getChallengeValue(),
        width = Device.screen:getWidth(),
        height = Device.screen:getHeight(),
        dismiss_callback = function()
            self._qr_widget = nil
        end,
    }
    UIManager:show(self._qr_widget, "full")
end

function Manager:start(skip_wifi_prompt)
    if self._running then
        self:showQRCode()
        return
    end

    if not self:_isWifiOn() then
        if skip_wifi_prompt then
            UIManager:show(InfoMessage:new{
                text = _("Wi‑Fi is still connecting. Please try again in a moment."),
                timeout = 4,
            })
            return
        end
        self:_promptToEnableWifi()
        return
    end

    local file_path = self:getStatisticsPath()
    if not self:fileExists(file_path) then
        UIManager:show(InfoMessage:new{
            text = T(_("File not found:\n%1"), file_path),
            timeout = 6,
        })
        return
    end

    local ip = self:getLocalIP()
    if not ip then
        UIManager:show(InfoMessage:new{
            text = _("Could not determine the device IP address. Make sure Wi‑Fi is connected."),
            timeout = 5,
        })
        return
    end

    self._session_token = self:getSessionToken()
    self._challenge_value = self:getChallengeValue()
    self._challenge_options = self:getChallengeOptions()

    local HttpServer = require("statsqr/httpserver")
    local ok, err = pcall(function()
        self._server = HttpServer:new{
            bind_ip = "*",
            port = self:getPort(),
            file_path = file_path,
            access_token = self._session_token,
            access_choice = self._challenge_value,
            choice_options = self._challenge_options,
        }
        self._server:start()
    end)

    if not ok then
        logger.err("StatsQR: failed to start server: ", err)
        self._server = nil
        UIManager:show(InfoMessage:new{
            text = T(_("Failed to start the server:\n%1"), tostring(err)),
            timeout = 6,
        })
        return
    end

    local firewall_ok, firewall_err = self:openKindleFirewallPort()
    if self:isKindleDevice() and not firewall_ok then
        logger.warn("StatsQR: Kindle firewall open warning: ", tostring(firewall_err))
    end

    self._ip = ip
    self._running = true
    self:preventStandby()
    self:_scheduleAutoStop()
    self:showQRCode()
end

function Manager:stop(silent)
    self:_cancelAutoStop()
    self:_cancelWifiWait()
    self:closeQRCode()

    if self._server then
        pcall(function()
            self._server:stop()
        end)
        self._server = nil
    end

    self:closeKindleFirewallPort()

    local was_running = self._running
    self._running = false
    self._ip = nil
    self._session_token = nil
    self._challenge_value = nil
    self._challenge_options = nil
    self:allowStandby()

    if was_running and not silent then
        UIManager:show(InfoMessage:new{
            text = _("Statistics sharing stopped."),
            timeout = 3,
        })
    end
end

return Manager
