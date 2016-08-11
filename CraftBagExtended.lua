CBE = {
    name = "CraftBagExtended",
    title = GetString(SI_CBE),
    author = "|c99CCEFsilvereyes|r",
    version = "1.5.3",
    debug = false,
}

local function CreateButtonData(menuBar, descriptor, tabIconCategory, callback)
    local iconTemplate = "EsoUI/Art/Inventory/inventory_tabIcon_<<1>>_<<2>>.dds"
    return {
        normal = zo_strformat(iconTemplate, tabIconCategory, "up"),
        pressed = zo_strformat(iconTemplate, tabIconCategory, "down"),
        highlight = zo_strformat(iconTemplate, tabIconCategory, "over"),
        descriptor = descriptor,
        categoryName = descriptor,
        callback = callback,
        menu = menuBar
    }
end

local function GetCraftBagStatusIcon()
    if SHARED_INVENTORY and SHARED_INVENTORY:AreAnyItemsNew(nil, nil, BAG_VIRTUAL) then
        return ZO_KEYBOARD_NEW_ICON
    end
    return nil
end

local function GetCraftBagTooltip(...)
    return ZO_InventoryMenuBar:LayoutCraftBagTooltip(...)
end

local function OnAddonLoaded(event, name)
    if name ~= CBE.name then return end
    EVENT_MANAGER:UnregisterForEvent(CBE.name, EVENT_ADD_ON_LOADED)
    
    CBE.Settings  = CBE_SettingsController:New()
    CBE.GuildBank = CBE_GuildBankController:New()
    CBE.Mail      = CBE_MailController:New()
    CBE.Trade     = CBE_TradeController:New()
    CBE.Inventory = CBE_InventoryController:New()
    
end

function CBE:AddCraftBagButton(menuBar, callback)
    local buttonData = CreateButtonData(menuBar, SI_INVENTORY_MODE_CRAFT_BAG, "Craftbag", callback)
    buttonData.CustomTooltipFunction = GetCraftBagTooltip
    buttonData.statusIcon = GetCraftBagStatusIcon
    local button = ZO_MenuBar_AddButton(menuBar, buttonData)
    return button
end

function CBE:AddItemsButton(menuBar, callback)
    local buttonData = CreateButtonData(menuBar, SI_INVENTORY_MODE_ITEMS, "items", callback)
    local button = ZO_MenuBar_AddButton(menuBar, buttonData)
    return button
end

--[[ Outputs formatted message to chat window if debugging is turned on ]]
function CBE:Debug(input, scopeDebug)
    if not CBE.debug and not scopeDebug then return end
    local output = zo_strformat("<<1>>|cFFFFFF: <<2>>|r", CBE.title, input)
    d(output)
end

EVENT_MANAGER:RegisterForEvent(CBE.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
