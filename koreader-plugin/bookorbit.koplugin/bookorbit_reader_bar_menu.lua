local Config = require("bookorbit_reader_bar_config")
local items, config, copyConfig, orderFor = Config.items, Config.get, Config.copy, Config.orderFor
local Menu = {}

local function addItemSections(sections, plugin, save, _)
    for zone_index, zone in ipairs({ "left", "center", "right" }) do
        local choices = {
            { text = _("Arrange"), callback = function()
                local cfg = config(plugin.settings)
                local labels, sorted = {}, {}
                for index, item in ipairs(items) do labels[item[1]] = _(item[2]) end
                for index, key in ipairs(orderFor(cfg, zone)) do table.insert(sorted, { text = labels[key], orig_item = key }) end
                if #sorted == 0 then return end
                local SortWidget = require("ui/widget/sortwidget")
                require("ui/uimanager"):show(SortWidget:new{
                    title = _("Arrange items"), item_table = sorted,
                    callback = function()
                        local order = {}
                        for index, entry in ipairs(sorted) do table.insert(order, entry.orig_item) end
                        cfg.order = cfg.order or {}
                        cfg.order[zone] = order
                        save()
                    end,
                })
            end },
        }
        for item_index, item in ipairs(items) do
            local key, label = item[1], item[2]
            table.insert(choices, { text = _(label), keep_menu_open = true,
                checked_func = function() return config(plugin.settings)[zone] and config(plugin.settings)[zone][key] == true end,
                callback = function()
                    local cfg = config(plugin.settings)
                    cfg[zone] = cfg[zone] or {}
                    cfg[zone][key] = not cfg[zone][key]
                    save()
                end })
        end
        table.insert(sections, { text = _(({ left = "Left items", center = "Center items", right = "Right items" })[zone]), sub_item_table = choices })
    end
end

local function addCustomText(sections, plugin, save, _)
    table.insert(sections, { text = _("Custom text"), callback = function()
        local InputDialog = require("ui/widget/inputdialog")
        local UIManager = require("ui/uimanager")
        local dialog
        dialog = InputDialog:new{
            title = _("Custom text"), input = config(plugin.settings).custom_text or "",
            buttons = { { { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
                { text = _("Save"), is_enter_default = true, callback = function()
                    config(plugin.settings).custom_text = dialog:getInputText()
                    UIManager:close(dialog)
                    save()
                end } } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end })
end

local function addPresets(sections, plugin, save, _)
    local presets = {
        { "Minimal", { left = {}, center = { time = true }, right = {} } },
        { "Reading", { left = { title = true }, center = { progress = true }, right = { time = true, battery = true } } },
        { "Chapter", { left = { chapter = true }, center = { pages = true }, right = { time = true } } },
    }
    local preset_menu = {}
    for index, preset in ipairs(presets) do
        local label, layout = preset[1], preset[2]
        table.insert(preset_menu, { text = _(label), callback = function()
            local cfg = config(plugin.settings)
            for _, zone in ipairs({ "left", "center", "right" }) do
                cfg[zone] = {}
                for key, value in pairs(layout[zone]) do cfg[zone][key] = value end
            end
            cfg.order = nil
            save()
        end })
    end
    plugin.settings.reader_bar_named_presets = plugin.settings.reader_bar_named_presets or {}
    if plugin.settings.reader_bar_presets then
        for slot, preset in pairs(plugin.settings.reader_bar_presets) do
            local name = string.format(_("My preset %d"), slot)
            if not plugin.settings.reader_bar_named_presets[name] then
                plugin.settings.reader_bar_named_presets[name] = copyConfig(preset)
            end
        end
        plugin.settings.reader_bar_presets = nil
    end
    local preset_obj = {
        presets = plugin.settings.reader_bar_named_presets,
        buildPreset = function() return copyConfig(config(plugin.settings)) end,
        loadPreset = function(preset)
            plugin.settings.reader_bar_config = copyConfig(preset)
            save()
        end,
    }
    table.insert(sections, { text = _("Presets"), sub_item_table_func = function()
        local entries = require("ui/presets").genPresetMenuItemTable(preset_obj, _("Save current settings as preset"))
        for index, item in ipairs(preset_menu) do table.insert(entries, item) end
        return entries
    end })
end

local function addAppearance(sections, plugin, save, _)
    table.insert(sections, { text = _("Font"), callback = function()
        local FontChooser = require("ui/widget/fontchooser")
        local footer = G_reader_settings:readSetting("footer") or {}
        local default_font = footer.text_font_face or "NotoSans-Regular.ttf"
        require("ui/uimanager"):show(FontChooser:new{
            title = _("Top bar font"), font_file = config(plugin.settings).font_face or default_font,
            default_font_file = default_font,
            callback = function(file) config(plugin.settings).font_face = file; save() end,
        })
    end })
    local sizes = {}
    for size_index, value in ipairs({ 12, 14, 16, 18, 20 }) do
        local size = value
        table.insert(sizes, { text = tostring(size), checked_func = function() return (config(plugin.settings).font_size or 14) == size end,
            callback = function() config(plugin.settings).font_size = size; save() end })
    end
    table.insert(sections, { text = _("Font size"), sub_item_table = sizes })
    local separators = { { "dot", "Dot" }, { "bar", "Bar" }, { "dash", "Dash" }, { "space", "Space" }, { "small", "Small space" }, { "none", "None" }, { "bullet", "Bullet" } }
    local separator_menu = {}
    for index, entry in ipairs(separators) do
        local key, label = entry[1], entry[2]
        table.insert(separator_menu, { text = _(label), checked_func = function() return (config(plugin.settings).separator or "dot") == key end,
            callback = function() config(plugin.settings).separator = key; save() end })
    end
    table.insert(sections, { text = _("Separator"), sub_item_table = separator_menu })
    local margins = {}
    for index, amount in ipairs({ 10, 20, 30, 40 }) do
        local margin = amount
        table.insert(margins, { text = tostring(margin), checked_func = function() return (config(plugin.settings).side_margin or 20) == margin end,
            callback = function() config(plugin.settings).side_margin = margin; save() end })
    end
    table.insert(sections, { text = _("Side margin"), sub_item_table = margins })
end

local function addDisplayOptions(sections, plugin, save, _)
    table.insert(sections, { text = _("Progress in bottom border"), checked_func = function() return config(plugin.settings).border_progress == true end,
        callback = function()
            local cfg = config(plugin.settings)
            cfg.border_progress = not cfg.border_progress
            if cfg.border_progress then cfg.border = true end
            save()
        end })
    table.insert(sections, { text = _("Colored status items"), checked_func = function() return config(plugin.settings).colored == true end,
        callback = function() local cfg = config(plugin.settings); cfg.colored = not cfg.colored; save() end })
    table.insert(sections, { text = _("Chapter marks"), checked_func = function() return config(plugin.settings).chapter_marks == true end,
        callback = function()
            local cfg = config(plugin.settings)
            cfg.chapter_marks = not cfg.chapter_marks
            if cfg.chapter_marks then cfg.border = true; cfg.border_progress = true end
            save()
        end })
    table.insert(sections, { text = _("Align with book margins"), checked_func = function() return config(plugin.settings).align_margins == true end,
        callback = function() local cfg = config(plugin.settings); cfg.align_margins = not cfg.align_margins; save() end })
    table.insert(sections, { text = _("Show over PDF and CBZ content"), checked_func = function() return config(plugin.settings).fixed_layout == true end,
        callback = function() local cfg = config(plugin.settings); cfg.fixed_layout = not cfg.fixed_layout; save() end })
    table.insert(sections, { text = _("Bottom border"), checked_func = function() return config(plugin.settings).border == true end,
        callback = function() local cfg = config(plugin.settings); cfg.border = not cfg.border; save() end })
end

function Menu.build(plugin, refresh)
    local _ = require("gettext")
    local function save()
        G_reader_settings:saveSetting("bookorbit", plugin.settings)
        G_reader_settings:flush()
        refresh(plugin)
    end
    local sections = {
        { text = _("Show top bar"), checked_func = function() return plugin.settings.reader_top_bar == true end,
            callback = function() plugin.settings.reader_top_bar = not plugin.settings.reader_top_bar; save() end },
    }
    addItemSections(sections, plugin, save, _)
    addCustomText(sections, plugin, save, _)
    addPresets(sections, plugin, save, _)
    addAppearance(sections, plugin, save, _)
    addDisplayOptions(sections, plugin, save, _)
    return sections
end

return Menu
