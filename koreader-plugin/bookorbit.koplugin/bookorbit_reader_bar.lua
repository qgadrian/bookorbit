-- Optional reader header for paginated reflowable books.
local Config = require("bookorbit_reader_bar_config")
local config = Config.get
local Bar = {}

function Bar.menu(plugin)
    return require("bookorbit_reader_bar_menu").build(plugin, Bar.refresh)
end

function Bar.install(plugin)
    local ReaderView = require("apps/reader/modules/readerview")
    if ReaderView._bookorbit_bar_installed then return end
    ReaderView._bookorbit_bar_installed = true
    local Screen = require("device").screen
    local ReaderTypeset = require("apps/reader/modules/readertypeset")
    local UIManager = require("ui/uimanager")
    local Geom = require("ui/geometry")
    local logger = require("logger")

    local function enabled(view)
        local settings = G_reader_settings:readSetting("bookorbit") or {}
        if not (settings.reader_top_bar == true and view and view.ui and view.ui.document) then return false end
        if view.ui.rolling then return view.view_mode == "page" end
        return view.ui.paging and config(settings).fixed_layout == true
    end
    local function height() local settings = G_reader_settings:readSetting("bookorbit") or {}; return Screen:scaleBySize((config(settings).font_size or 14) + 16) end
    local original_typeset = ReaderTypeset.onSetPageMargins
    ReaderTypeset.onSetPageMargins = function(typeset, margins, ...)
        local document = typeset.ui and typeset.ui.document
        local own_method, original_margins, reserve
        if document then
            reserve = enabled(typeset.view) and height() or 0
            own_method = rawget(document, "setPageMargins")
            original_margins = document.setPageMargins
            document.setPageMargins = function(doc, left, top, right, bottom)
                return original_margins(doc, left, top + reserve, right, bottom)
            end
        end
        local ok, result = pcall(original_typeset, typeset, margins, ...)
        if document then document.setPageMargins = own_method end
        if not ok then error(result) end
        return result
    end
    local original_mode = ReaderView.onSetViewMode
    ReaderView.onSetViewMode = function(view, mode, ...)
        local previous = view.view_mode
        local result = original_mode(view, mode, ...)
        local typeset = view.ui and view.ui.typeset
        local highlight = view.ui and view.ui.highlight
        if previous ~= view.view_mode and typeset and typeset.unscaled_margins
                and not (highlight and highlight.restore_page_mode_func) then
            typeset:onSetPageMargins(typeset.unscaled_margins)
        end
        return result
    end
    local original_close = ReaderView.onCloseWidget
    ReaderView.onCloseWidget = function(view, ...)
        if view._bookorbit_bar_timer then UIManager:unschedule(view._bookorbit_bar_timer); view._bookorbit_bar_timer = nil end
        return original_close(view, ...)
    end
    local original_paint = ReaderView.paintTo
    ReaderView.paintTo = function(view, bb, x, y)
        original_paint(view, bb, x, y)
        if bb ~= Screen.bb or not enabled(view) then return end
        local typeset = view.ui.typeset
        local margins = view.ui.rolling and view.ui.document:getPageMargins()
        local expected = typeset and typeset.unscaled_margins
            and Screen:scaleBySize(typeset.unscaled_margins[2]) + height()
        if view.ui.rolling and (not expected or not margins or not margins.top or margins.top < expected) then
            if not view._bookorbit_margin_retry then
                logger.info("BookOrbit reader bar: margin not ready", "actual", margins and margins.top, "expected", expected)
                view._bookorbit_margin_retry = true
                UIManager:nextTick(function()
                    if view.ui and view.ui.document then Bar.refresh({ ui = view.ui }) end
                end)
            end
            return
        end
        view._bookorbit_margin_retry = nil
        require("bookorbit_reader_bar_render").paint(view, bb, x, y, height())
        local width = Screen:getWidth()
        view._bookorbit_bar_region = { x = x, y = y, w = width, h = height() }
        if not view._bookorbit_bar_timer then
            view._bookorbit_bar_timer = function()
                local top = UIManager:getTopmostVisibleWidget()
                if enabled(view) and (top == view.ui or (view.ui.show_parent and top == view.ui.show_parent)) then
                    local region = view._bookorbit_bar_region
                    if region then UIManager:setDirty(view.ui, "partial", Geom:new(region)) end
                end
                if view._bookorbit_bar_timer then UIManager:scheduleIn(60, view._bookorbit_bar_timer) end
            end
            UIManager:scheduleIn(60 - tonumber(os.date("%S")), view._bookorbit_bar_timer)
        end
    end
end

function Bar.refresh(plugin)
    local ui = plugin.ui
    local typeset = ui and ui.typeset
    local document = ui and ui.document
    if typeset and typeset.unscaled_margins and document and ui.rolling then
        local screen = require("device").screen
        local settings = G_reader_settings:readSetting("bookorbit") or {}
        local active = settings.reader_top_bar == true and ui.view and ui.view.view_mode == "page"
        local reserve = active and screen:scaleBySize((config(settings).font_size or 14) + 16) or 0
        local expected = screen:scaleBySize(typeset.unscaled_margins[2]) + reserve
        local margins = document:getPageMargins()
        if not margins or margins.top ~= expected then
            typeset:onSetPageMargins(typeset.unscaled_margins)
            if ui.rolling.onUpdatePos then ui.rolling:onUpdatePos(true) end
        end
    end
    if ui then require("ui/uimanager"):setDirty(ui, "full") end
end

return Bar
