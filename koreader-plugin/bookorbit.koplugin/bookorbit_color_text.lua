local Geom = require("ui/geometry")
local Widget = require("ui/widget/widget")

-- One line of text in an RGB colour. TextWidget paints glyphs in gray only,
-- so the line is set white on black once, which is its coverage mask, and
-- blitted in the colour. (Blitbuffer:invert only flips a flag that the C
-- blitter ignores when both buffers carry it, as a night-mode screen does.)
local ColourLine = Widget:extend{ line = nil, color = nil }

function ColourLine:getSize()
    return self.line:getSize()
end

function ColourLine:isTruncated()
    return self.line:isTruncated()
end

function ColourLine:paintTo(bb, x, y)
    local Blitbuffer = require("ffi/blitbuffer")
    local size = self.line:getSize()
    self.dimen = Geom:new{ x = x, y = y, w = size.w, h = size.h }
    if not self.mask then
        local canvas = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BB8)
        canvas:fill(Blitbuffer.COLOR_BLACK)
        self.line:paintTo(canvas, 0, 0)
        self.mask = canvas
    end
    if bb.colorblitFromRGB32 then
        bb:colorblitFromRGB32(self.mask, x, y, 0, 0, size.w, size.h, self.color)
    else
        bb:colorblitFrom(self.mask, x, y, 0, 0, size.w, size.h, self.color)
    end
end

function ColourLine:free()
    if self.mask then self.mask:free(); self.mask = nil end
    if self.line and self.line.free then self.line:free() end
end

return ColourLine
