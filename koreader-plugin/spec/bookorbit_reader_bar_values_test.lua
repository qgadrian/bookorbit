package.path = "koreader-plugin/bookorbit.koplugin/?.lua;" .. package.path
package.preload.device = function()
    return { hasBattery = function() return false end }
end
package.preload.gettext = function() return function(text) return text end end
local Values = require("bookorbit_reader_bar_values")
local view = {
    footer = { pageno = 30, pages = 100, percent_finished = 0.3 },
    ui = { doc_props = { display_title = "A book", authors = "An author" },
        toc = { getTocTitleByPage = function(_, page) return page == 30 and "Chapter" end } },
}
local values = Values.collect(view, { left = {}, center = {}, right = {}, custom_text = "hello" })
assert(values.title == "A book" and values.author == "An author")
assert(values.chapter == "Chapter" and values.pages == "30 / 100")
assert(values.progress == "30%" and values.current_page == "30" and values.total_pages == "100")
assert(values.custom == "hello" and values.battery == "")
print("bookorbit_reader_bar_values_test.lua: ok")
local device = require("device")
local power = {
    getCapacity = function() return nil end,
    isFrontlightOn = function() return true end,
    frontlightIntensity = function() error("unavailable") end,
    frontlightWarmth = function() return nil end,
}
device.hasBattery = function() return true end
device.hasFrontlight = function() return true end
device.hasNaturalLight = function() return true end
device.getPowerDevice = function() return power end
local cfg = { left = { battery = true, brightness = true, warmth = true }, center = {}, right = {} }
values = Values.collect(view, cfg)
assert(values.battery == "" and values.brightness == nil and values.warmth == nil, "unavailable device values are omitted")
power.getCapacity = function() return 105 end
power.frontlightIntensity = function() return 12.4 end
power.frontlightWarmth = function() return 50 end
values = Values.collect(view, cfg)
assert(values.battery == "100%" and values.brightness == "☼ 12%" and values.warmth == "⊛ 50%")
power.isFrontlightOn = function() return false end
values = Values.collect(view, cfg)
assert(values.brightness == "☼ Off" and values.warmth == "⊛ Off")
print("bookorbit_reader_bar_device_values_test.lua: ok")
