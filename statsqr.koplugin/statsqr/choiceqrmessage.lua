local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local QRWidget = require("ui/widget/qrwidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Input = Device.input
local Screen = Device.screen

local ChoiceQRMessage = InputContainer:extend{
    modal = true,
    timeout = nil,
    _timeout_func = nil,
    text = nil,
    width = nil,
    height = nil,
    dismiss_callback = nil,
    alpha = nil,
    scale_factor = 1,
    challenge_value = nil,
}

function ChoiceQRMessage:init()
    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = Screen:getWidth(),
                    h = Screen:getHeight(),
                }
            }
        }
    end

    local fullscreen_padding = Size.padding.fullscreen
    local qr_padding = Size.padding.large
    local qr_max = math.min(Screen:getWidth() - 2 * fullscreen_padding, Screen:getHeight() * 0.62)

    local title_widget = TextWidget:new{
        text = _("Select this number on your phone"),
        face = Font:getFace("smallinfofont", 20),
        bold = true,
        padding = 0,
    }

    local challenge_widget = TextWidget:new{
        text = tostring(self.challenge_value or "---"),
        face = Font:getFace("infont", 56),
        bold = true,
        padding = 0,
    }

    local qr_widget = QRWidget:new{
        text = self.text,
        width = qr_max - 2 * qr_padding,
        height = qr_max - 2 * qr_padding,
        alpha = self.alpha,
        scale_factor = self.scale_factor,
    }

    local qr_frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        padding = qr_padding,
        qr_widget,
    }

    local content = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        padding = fullscreen_padding,
        VerticalGroup:new{
            align = "center",
            title_widget,
            VerticalSpan:new{ width = Screen:scaleBySize(10) },
            challenge_widget,
            VerticalSpan:new{ width = Screen:scaleBySize(18) },
            qr_frame,
        },
    }

    self[1] = CenterContainer:new{
        dimen = Screen:getSize(),
        content,
    }
end

function ChoiceQRMessage:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self[1][1].dimen
    end)
    if self._timeout_func then
        UIManager:unschedule(self._timeout_func)
        self._timeout_func = nil
    end
    if self.dismiss_callback then
        self.dismiss_callback()
        self.dismiss_callback = nil
    end
end

function ChoiceQRMessage:onShow()
    UIManager:setDirty(self, function()
        return "ui", self[1][1].dimen
    end)
    if self.timeout then
        self._timeout_func = function()
            self._timeout_func = nil
            UIManager:close(self)
        end
        UIManager:scheduleIn(self.timeout, self._timeout_func)
    end
    return true
end

function ChoiceQRMessage:onTapClose()
    UIManager:close(self)
    return true
end
ChoiceQRMessage.onAnyKeyPressed = ChoiceQRMessage.onTapClose

return ChoiceQRMessage
