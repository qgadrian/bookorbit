local Config = require("bookorbit_reader_bar_config")
local config, orderFor = Config.get, Config.orderFor
local Device = require("device")
local Screen = Device.screen
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local ColorText = require("bookorbit_color_text")
local Blitbuffer = require("ffi/blitbuffer")
local Render = {}

local function paintBorder(view, bb, x, y, height, width, left_margin, right_margin, cfg)
    local footer = view.footer
    if cfg.border then
        local line_width = math.max(0, width - left_margin - right_margin)
        local line_height = math.max(1, Screen:scaleBySize(2))
        local line_y = y + height - line_height
        if cfg.border_progress then
            bb:paintRect(x + left_margin, line_y, line_width, line_height, Blitbuffer.COLOR_LIGHT_GRAY)
            local ratio = footer and tonumber(footer.percent_finished) or 0
            ratio = math.max(0, math.min(1, ratio))
            if ratio > 0 then bb:paintRect(x + left_margin, line_y, math.ceil(line_width * ratio), line_height, Blitbuffer.COLOR_GRAY_5) end
            local toc, document = view.ui.toc, view.ui.document
            local pages = document and document.getPageCount and document:getPageCount()
            if cfg.chapter_marks and toc and toc.getTocTicksFlattened and pages and pages > 0
                    and not (document.hasHiddenFlows and document:hasHiddenFlows()) then
                for _, page in ipairs(toc:getTocTicksFlattened() or {}) do
                    if type(page) == "number" and page >= 0 and page <= pages then
                        local tick_width = math.max(1, Screen:scaleBySize(1))
                        local tick_x = math.min(math.max(0, line_width - tick_width), math.floor(line_width * page / pages))
                        bb:paintRect(x + left_margin + tick_x, line_y, math.min(tick_width, line_width), line_height, Blitbuffer.COLOR_BLACK)
                    end
                end
            end
        else
            bb:paintRect(x + left_margin, line_y, line_width, line_height, Blitbuffer.COLOR_GRAY)
        end
    end
end

function Render.paint(view, bb, x, y, height)
    local width = Screen:getWidth()
    local settings = G_reader_settings:readSetting("bookorbit") or {}
    local cfg = config(settings)
    local pad = math.min(Screen:scaleBySize(cfg.side_margin or 20), math.floor(width / 3))
    local book_margins = cfg.align_margins and view.ui.document.getPageMargins and view.ui.document:getPageMargins()
    local left_margin = book_margins and math.max(0, book_margins.left or 0) or pad
    local right_margin = book_margins and math.max(0, book_margins.right or 0) or pad
    local face = Font:getFace(cfg.font_face or "smallinfofont", cfg.font_size or 14)
    local values = require("bookorbit_reader_bar_values").collect(view, cfg)
    local function zoneText(zone)
        local parts = {}
        for index, key in ipairs(orderFor(cfg, zone)) do
            if values[key] and values[key] ~= "" then table.insert(parts, values[key]) end
        end
        local separators = { dot = "  ·  ", bar = "  |  ", dash = "  -  ", space = "  ", small = " ", none = "", bullet = "  •  " }
        return table.concat(parts, separators[cfg.separator] or separators.dot)
    end
    local function paint(text, left, available, align, zone)
        if available <= 0 then return end
        local widget = TextWidget:new{ text = text, face = face, max_width = available, truncate = true }
        local size = widget:getSize()
        local offset = align == "right" and available - size.w or align == "center" and (available - size.w) / 2 or 0
        local origin = x + left + math.max(0, math.floor(offset))
        local colors = {
            wifi = Blitbuffer.ColorRGB32(0x33, 0x88, 0xcc, 0xff),
            bluetooth = Blitbuffer.ColorRGB32(0x33, 0x88, 0xcc, 0xff),
            battery = Blitbuffer.ColorRGB32(0x33, 0x99, 0x55, 0xff),
            brightness = Blitbuffer.ColorRGB32(0xdd, 0x88, 0x00, 0xff),
            warmth = Blitbuffer.ColorRGB32(0xdd, 0x88, 0x00, 0xff),
        }
        if cfg.colored and Device:hasColorScreen() and zone then
            local separators = { dot = "  ·  ", bar = "  |  ", dash = "  -  ", space = "  ", small = " ", none = "", bullet = "  •  " }
            local parts, segments, total = {}, {}, 0
            for _, key in ipairs(orderFor(cfg, zone)) do
                if values[key] and values[key] ~= "" then table.insert(parts, key) end
            end
            for i, key in ipairs(parts) do
                if i > 1 then table.insert(segments, { text = separators[cfg.separator] or separators.dot }) end
                table.insert(segments, { text = values[key], color = colors[key] })
            end
            local visible = {}
            for _, segment in ipairs(segments) do
                local remaining = available - total
                if remaining <= 0 then break end
                local line = TextWidget:new{
                    text = segment.text, face = face, fgcolor = segment.color and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
                    max_width = remaining, truncate = true,
                }
                segment.widget = segment.color and ColorText:new{ line = line, color = segment.color } or line
                local segment_width = segment.widget:getSize().w
                total = total + segment_width
                table.insert(visible, segment)
                if segment_width >= remaining then break end
            end
            origin = x + left + math.max(0, math.floor(align == "right" and available - total or align == "center" and (available - total) / 2 or 0))
            for _, segment in ipairs(visible) do
                local part_size = segment.widget:getSize()
                segment.widget:paintTo(bb, origin, y + math.floor((height - part_size.h) / 2))
                origin = origin + part_size.w
                segment.widget:free()
            end
        else
            widget:paintTo(bb, origin, y + math.floor((height - size.h) / 2))
        end
        widget:free()
    end
    bb:paintRect(x, y, width, height, Blitbuffer.COLOR_WHITE)
    local left_pad, right_pad = left_margin, right_margin
    local highlight = view.ui.highlight
    local rolling = view.ui.rolling
    if (highlight and (highlight.select_mode or highlight.long_hold_reached))
            or (rolling and rolling.rendering_state) then
        left_pad = math.max(left_pad, Screen:scaleBySize(32) + pad)
    end
    if view.dogear_visible and view.dogear then
        right_pad = math.max(right_pad, (view.dogear.dogear_size or 0) + pad)
    end
    local side = math.max(left_pad, right_pad)
    local third = math.max(0, math.floor((width - 2 * side) / 3))
    paint(zoneText("left"), side, third, "left", "left")
    paint(zoneText("center"), side + third, third, "center", "center")
    paint(zoneText("right"), side + 2 * third, third, "right", "right")
    paintBorder(view, bb, x, y, height, width, left_margin, right_margin, cfg)
    if view.dogear_visible and view.dogear then view.dogear:paintTo(bb, x, y) end
    if view.flipping then view.flipping:paintTo(bb, x, y) end
end

return Render
