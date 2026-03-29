local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local plugin_dir = debug.getinfo(1, "S").source:match("@(.+)/[^/]+$") or "."
local meta = dofile(plugin_dir .. "/_meta.lua")

local StatsQR = WidgetContainer:extend{
    name = "statsqr",
    is_doc_only = false,
}

function StatsQR:init()
    self.ui.menu:registerToMainMenu(self)
end

function StatsQR:addToMainMenu(menu_items)
    menu_items.statsqr = {
        text = _("StatsQR"),
        sorting_hint = "setting",
        sub_item_table = {
            {
                text_func = function()
                    local Manager = require("statsqr/manager")
                    if Manager:isRunning() then
                        return _("Stop sharing statistics.sqlite3")
                    end
                    return _("Start sharing statistics.sqlite3")
                end,
                callback = function()
                    local Manager = require("statsqr/manager")
                    if Manager:isRunning() then
                        Manager:stop()
                    else
                        Manager:start()
                    end
                end,
                keep_menu_open = false,
            },
            {
                text = _("Show QR code again"),
                enabled_func = function()
                    local Manager = require("statsqr/manager")
                    return Manager:isRunning()
                end,
                callback = function()
                    require("statsqr/manager"):showQRCode()
                end,
                keep_menu_open = false,
            },
            {
                text = _("Show current number"),
                enabled_func = function()
                    local Manager = require("statsqr/manager")
                    return Manager:isRunning()
                end,
                callback = function()
                    require("statsqr/manager"):showChallengeValue()
                end,
                keep_menu_open = false,
            },
            {
                text = _("Show direct URL"),
                enabled_func = function()
                    local Manager = require("statsqr/manager")
                    return Manager:isRunning()
                end,
                callback = function()
                    local Manager = require("statsqr/manager")
                    UIManager:show(InfoMessage:new{
                        text = Manager:getURL(),
                        timeout = 10,
                    })
                end,
                keep_menu_open = false,
            },
            {
                text = _("About"),
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = T(_("%1 v%2\n\nShares only the KOReader statistics database (statistics.sqlite3) over your local Wi‑Fi and shows a QR code on the e-reader so the file can be downloaded on your phone.\n\nA temporary private access token is added to the URL for each sharing session. A random challenge number is shown above the QR code on the device, and the phone must choose that same number from three options before the file is downloaded.\n\nThe server stops automatically after 2 minutes."), meta.fullname, meta.version),
                    })
                end,
                keep_menu_open = true,
            },
        },
    }
end

function StatsQR:onExit()
    local Manager = require("statsqr/manager")
    if Manager:isRunning() then
        Manager:stop(true)
    end
end

return StatsQR
