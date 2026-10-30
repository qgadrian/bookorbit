local Config = {}

Config.items = {
    { "title", "Book title" }, { "author", "Author" }, { "chapter", "Chapter" },
    { "progress", "Progress percentage" }, { "current_page", "Current page" },
    { "total_pages", "Total pages" }, { "pages", "Current / total pages" },
    { "time", "Time" }, { "battery", "Battery percentage" }, { "wifi", "Wi-Fi status" },
    { "bluetooth", "Bluetooth status" }, { "brightness", "Frontlight brightness" },
    { "warmth", "Frontlight warmth" }, { "custom", "Custom text" },
}

function Config.get(settings)
    if not settings.reader_bar_config then
        settings.reader_bar_config = { left = { title = true }, center = { progress = true }, right = { time = true, battery = true } }
    end
    return settings.reader_bar_config
end

function Config.copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = Config.copy(item) end
    return copy
end

function Config.orderFor(cfg, zone)
    cfg.order = cfg.order or {}
    local order, seen = {}, {}
    for index, key in ipairs(cfg.order[zone] or {}) do
        if cfg[zone] and cfg[zone][key] and not seen[key] then
            table.insert(order, key)
            seen[key] = true
        end
    end
    for index, item in ipairs(Config.items) do
        local key = item[1]
        if cfg[zone] and cfg[zone][key] and not seen[key] then table.insert(order, key) end
    end
    return order
end

return Config
