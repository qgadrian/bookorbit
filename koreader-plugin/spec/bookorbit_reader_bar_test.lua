package.path = "koreader-plugin/bookorbit.koplugin/?.lua;" .. package.path
package.preload.gettext = function() return function(text) return text end end
local saved
G_reader_settings = { saveSetting = function(_, key, value) saved = value end, flush = function() end }
local Bar = require("bookorbit_reader_bar")
local plugin = { settings = {} }
local menu = Bar.menu(plugin)
assert(menu[1].text == "Show top bar")
menu[1].callback()
assert(saved.reader_top_bar == true)
local left, center = menu[2].sub_item_table, menu[3].sub_item_table
assert(left[2].checked_func())
left[2].callback()
assert(not left[2].checked_func())
left[3].callback()
assert(left[3].checked_func() and not center[3].checked_func())
local separators = menu[9].sub_item_table
separators[2].callback()
assert(saved.reader_bar_config.separator == "bar")
menu[11].callback()
assert(saved.reader_bar_config.border and saved.reader_bar_config.border_progress)
menu[10].sub_item_table[3].callback()
assert(saved.reader_bar_config.side_margin == 30)
local preset_obj
package.preload["ui/presets"] = function() return { genPresetMenuItemTable = function(obj) preset_obj = obj; return {} end } end
menu[6].sub_item_table_func()
local preset = preset_obj.buildPreset()
plugin.settings.reader_bar_config.side_margin = 10
plugin.settings.reader_bar_config.left.author = false
preset_obj.loadPreset(preset)
assert(plugin.settings.reader_bar_config.side_margin == 30)
assert(plugin.settings.reader_bar_config.left.author == true)
plugin.settings.reader_bar_config.left.author = false
preset_obj.loadPreset(preset)
assert(plugin.settings.reader_bar_config.left.author == true, "applying a preset must not mutate the saved copy")
print("bookorbit_reader_bar_test.lua: ok")
local viewclass = { paintTo = function() end, onSetViewMode = function() end, onCloseWidget = function() end }
local typesetclass = { onSetPageMargins = function(self, m) self.ui.document:setPageMargins(m[1], m[2], m[3], m[4]) end }
package.preload["apps/reader/modules/readerview"] = function() return viewclass end
package.preload["apps/reader/modules/readertypeset"] = function() return typesetclass end
package.preload.device = function() return { screen = { scaleBySize = function(_, n) return n end } } end
package.preload["bookorbit_color_text"] = function() return {} end
for _, name in ipairs({ "ui/font", "ui/widget/textwidget", "ffi/blitbuffer", "ui/uimanager", "ui/geometry", "logger" }) do
    package.preload[name] = function() return {} end
end
local settings = { reader_top_bar = true }
G_reader_settings.readSetting = function() return settings end
local applied
local document = { setPageMargins = function(_, l, t, r, b) applied = { l, t, r, b } end }
local view = { view_mode = "page", ui = { rolling = true, document = document } }
local typeset = { ui = view.ui, view = view }
Bar.install({})
typesetclass.onSetPageMargins(typeset, { 5, 10, 5, 10 })
assert(applied[2] == 40, "header height is added to the document top margin")
assert(document.setPageMargins ~= nil, "instance method restored")
print("bookorbit_reader_bar_margin_test.lua: ok")
settings.reader_top_bar = false
typesetclass.onSetPageMargins(typeset, { 5, 10, 5, 10 })
assert(applied[2] == 10, "disabled header restores the original margin")
settings.reader_top_bar = true
view.view_mode = "scroll"
typesetclass.onSetPageMargins(typeset, { 5, 10, 5, 10 })
assert(applied[2] == 10, "scroll mode does not reserve header space")
view.view_mode = "page"
settings.reader_bar_config = { font_size = 20 }
typesetclass.onSetPageMargins(typeset, { 5, 10, 5, 10 })
assert(applied[2] == 46, "font size changes the reserved height")
print("bookorbit_reader_bar_lifecycle_test.lua: ok")
local original_set = document.setPageMargins
settings.reader_top_bar = true
view.view_mode = "page"
local calls = 0
local old_set = document.setPageMargins
document.setPageMargins = function(...) calls = calls + 1; return old_set(...) end
local saved_method = document.setPageMargins
local failing_typeset = { ui = view.ui, view = view }
local bad_document = { setPageMargins = function() error("margin failure") end }
failing_typeset.ui = { document = bad_document, rolling = true }
failing_typeset.view = { view_mode = "page", ui = failing_typeset.ui }
local bad_set = bad_document.setPageMargins
local ok = pcall(typesetclass.onSetPageMargins, failing_typeset, { 5, 10, 5, 10 })
assert(not ok and bad_document.setPageMargins == bad_set, "margin method is restored on failure")
assert(document.setPageMargins == saved_method and original_set ~= nil)
print("bookorbit_reader_bar_error_test.lua: ok")
local UIManager = require("ui/uimanager")
UIManager.setDirty = function() end
local top = 46
local refreshes = 0
document.getPageMargins = function() return { top = top } end
view.ui.view = view
view.ui.typeset = { unscaled_margins = { 5, 10, 5, 10 }, onSetPageMargins = function() refreshes = refreshes + 1 end }
view.ui.rolling = { onUpdatePos = function() end }
Bar.refresh({ ui = view.ui })
assert(refreshes == 0, "unchanged header geometry does not reflow the book")
settings.reader_bar_config.font_size = 18
Bar.refresh({ ui = view.ui })
assert(refreshes == 1, "a changed header height reflows the book")
print("bookorbit_reader_bar_refresh_test.lua: ok")
