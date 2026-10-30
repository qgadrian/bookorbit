package.path = "koreader-plugin/bookorbit.koplugin/?.lua;" .. package.path
local settings = { reader_top_bar = true, reader_bar_config = {} }
G_reader_settings = { readSetting = function() return settings end }
local framebuffer = {}
local screen = { bb = framebuffer, scaleBySize = function(_, n) return n end, getWidth = function() return 600 end }
local paints, retries = 0, 0
local reader = { paintTo = function() end, onSetViewMode = function() end, onCloseWidget = function() end }
package.preload["device"] = function() return { screen = screen } end
package.preload["apps/reader/modules/readerview"] = function() return reader end
package.preload["apps/reader/modules/readertypeset"] = function() return { onSetPageMargins = function() end } end
package.preload["ui/uimanager"] = function() return {
    nextTick = function() retries = retries + 1 end,
    scheduleIn = function() end, unschedule = function() end,
} end
package.preload["ui/geometry"] = function() return {} end
package.preload["logger"] = function() return { info = function() end } end
package.preload["bookorbit_reader_bar_render"] = function() return { paint = function() paints = paints + 1 end } end
local Bar = require("bookorbit_reader_bar")
Bar.install({})
local margin = 10
local document = { getPageMargins = function() return { top = margin } end }
local view = { view_mode = "page", ui = { document = document, rolling = {}, typeset = { unscaled_margins = { 5, 10, 5, 10 } } } }
reader.paintTo(view, framebuffer, 0, 0)
assert(paints == 0 and retries == 1, "insufficient margin must hide the bar and request a retry")
reader.paintTo(view, framebuffer, 0, 0)
assert(retries == 1, "repeated paints do not schedule repeated retries")
margin = 40
reader.paintTo(view, framebuffer, 0, 0)
assert(paints == 1, "a reserved margin allows the bar to paint")
reader.paintTo(view, {}, 0, 0)
assert(paints == 1, "offscreen rendering must not paint the bar")
view.view_mode = "scroll"
reader.paintTo(view, framebuffer, 0, 0)
assert(paints == 1, "continuous mode must not paint the bar")
local fixed = { ui = { document = {}, paging = {} } }
reader.paintTo(fixed, framebuffer, 0, 0)
assert(paints == 1, "fixed-layout overlay is opt-in")
settings.reader_bar_config.fixed_layout = true
reader.paintTo(fixed, framebuffer, 0, 0)
assert(paints == 2, "fixed-layout overlay paints when enabled")
print("bookorbit_reader_bar_paint_test.lua: ok")
