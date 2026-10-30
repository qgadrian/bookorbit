local Device = require("device")
local Values = {}

local function call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, result = pcall(object[method], object, ...)
    if ok then return result end
end

local function percent(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return math.floor(math.max(0, math.min(100, value)) + 0.5)
end

function Values.collect(view, cfg)
    local footer = view.footer
    local props = view.ui.doc_props or {}
    local values = {
        title = props.display_title or "", author = props.authors or "",
        chapter = footer and footer.pageno and view.ui.toc and view.ui.toc:getTocTitleByPage(footer.pageno) or "",
        progress = footer and footer.percent_finished and string.format("%d%%", math.floor(footer.percent_finished * 100 + 0.5)) or "",
        pages = footer and footer.pageno and footer.pages and string.format("%s / %s", footer.pageno, footer.pages) or "",
        current_page = footer and footer.pageno and tostring(footer.pageno) or "",
        total_pages = footer and footer.pages and tostring(footer.pages) or "",
        time = os.date("%H:%M"), custom = cfg.custom_text or "",
        battery = "",

    }
    local power = call(Device, "getPowerDevice")
    if call(Device, "hasBattery") and power then
        local capacity = percent(call(power, "getCapacity"))
        if capacity then
            local icon = call(power, "getBatterySymbol", call(power, "isCharged"), call(power, "isCharging"), capacity)
            values.battery = (type(icon) == "string" and icon ~= "" and icon .. " " or "") .. capacity .. "%"
        end
    end
    local _ = require("gettext")
    local needs = {}
    for _, zone in ipairs({ "left", "center", "right" }) do
        for key, selected in pairs(cfg[zone] or {}) do if selected then needs[key] = true end end
    end
    if needs.wifi and call(Device, "hasWifiToggle") then
        local ok, network = pcall(require, "ui/network/manager")
        local on = ok and call(network, "isWifiOn")
        if on == true then values.wifi = "" elseif on == false then values.wifi = "" end
    end
    if (needs.brightness or needs.warmth) and call(Device, "hasFrontlight") and power then
        local on = call(power, "isFrontlightOn")
        if on == false then
            if needs.brightness then values.brightness = "☼ " .. _("Off") end
            if needs.warmth and call(Device, "hasNaturalLight") then values.warmth = "⊛ " .. _("Off") end
        elseif on == true then
            local brightness = needs.brightness and percent(call(power, "frontlightIntensity"))
            local warmth = needs.warmth and call(Device, "hasNaturalLight") and percent(call(power, "frontlightWarmth"))
            if brightness then values.brightness = string.format("☼ %d%%", brightness) end
            if warmth then values.warmth = string.format("⊛ %d%%", warmth) end
        end
    end
    if needs.bluetooth then
        local kobo = view.ui.kobo or view.ui.kobo_plugin
        if not kobo then
            local ok, loader = pcall(require, "pluginloader")
            if ok and loader.getPluginInstance then
                local found, instance = pcall(loader.getPluginInstance, loader, "kobo")
                if found then kobo = instance end
            end
        end
        local bluetooth = kobo and kobo.kobo_bluetooth
        if bluetooth and type(bluetooth.isDeviceSupported) == "function"
                and type(bluetooth.isBluetoothEnabled) == "function" then
            local ok, supported = pcall(bluetooth.isDeviceSupported, bluetooth)
            if ok and supported then
                local state_ok, state = pcall(bluetooth.isBluetoothEnabled, bluetooth)
                if state_ok and state ~= nil then values.bluetooth = "BT " .. (state and _("On") or _("Off")) end
            end
        elseif Device.isKindle and Device:isKindle() then
            local ok, lipc = pcall(require, "liblipclua")
            if ok and lipc then
                local opened, handle = pcall(lipc.init, "com.github.bookorbit.status")
                if opened and handle then
                    local read_ok, state = pcall(handle.get_int_property, handle, "com.lab126.btfd", "BTstate")
                    pcall(handle.close, handle)
                    if read_ok and type(state) == "number" then values.bluetooth = "BT " .. (state ~= 0 and _("On") or _("Off")) end
                end
            end
        end
    end
    return values
end

return Values
