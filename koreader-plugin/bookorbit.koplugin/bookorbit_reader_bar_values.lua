local Device = require("device")
local Values = {}

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
    if Device:hasBattery() then
        local power = Device:getPowerDevice()
        local capacity = power:getCapacity()
        local icon = power:getBatterySymbol(power:isCharged(), power:isCharging(), capacity)
        values.battery = (icon or "") .. " " .. tostring(capacity) .. "%"
    end
    local _ = require("gettext")
    local needs = {}
    for _, zone in ipairs({ "left", "center", "right" }) do
        for key, selected in pairs(cfg[zone] or {}) do if selected then needs[key] = true end end
    end
    if needs.wifi then
        local network = require("ui/network/manager")
        if Device:hasWifiToggle() then
            values.wifi = network:isWifiOn() and "" or ""
        end
    end
    if needs.brightness or needs.warmth then
        local power = Device:getPowerDevice()
        if Device:hasFrontlight() and power then
            local on = power:isFrontlightOn()
            if needs.brightness then
                values.brightness = on and string.format("☼ %d%%", power:frontlightIntensity()) or ("☼ " .. _("Off"))
            end
            if needs.warmth and Device:hasNaturalLight() then
                local warmth = on and power:frontlightWarmth()
                values.warmth = warmth and string.format("⊛ %d%%", warmth) or ("⊛ " .. _("Off"))
            end
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
