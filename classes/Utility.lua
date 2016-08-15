local cbe     = CraftBagExtended
local class   = cbe.classes
class.Utility = ZO_Object:Subclass()
local util    = class.Utility
function util:New(...)
    self.name = cbe.name .. "Utility"
    self.transferQueueCache = {}
    return ZO_Object.New(self)
end
cbe.utility = util:New()

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

--[[ Adds a craft bag button to the given menu bar with callback as the click handler ]]
function util.AddCraftBagButton(menuBar, callback)
    local buttonData = CreateButtonData(menuBar, SI_INVENTORY_MODE_CRAFT_BAG, "Craftbag", callback)
    buttonData.CustomTooltipFunction = GetCraftBagTooltip
    buttonData.statusIcon = GetCraftBagStatusIcon
    local button = ZO_MenuBar_AddButton(menuBar, buttonData)
    return button
end

--[[ Adds an inventory items button to the given menu bar with callback as the click handler ]]
function util.AddItemsButton(menuBar, callback)
    local buttonData = CreateButtonData(menuBar, SI_INVENTORY_MODE_ITEMS, "items", callback)
    local button = ZO_MenuBar_AddButton(menuBar, buttonData)
    return button
end

--[[ Outputs formatted message to chat window if debugging is turned on ]]
function util.Debug(input, scopeDebug)
    if not cbe.debug and not scopeDebug then return end
    local output = zo_strformat("<<1>>|cFFFFFF: <<2>>|r", cbe.title, input)
    d(output)
end

--[[ Outputs a string without spaces describing the given inventory bag.  
     Used for naming instances related to certain bags. ]]
function util.GetBagName(bag)
    if bag == BAG_WORN then
        return GetString(SI_CHARACTER_EQUIP_TITLE)
    elseif bag == BAG_BACKPACK then
        return GetString(SI_GAMEPAD_INVENTORY_CATEGORY_HEADER)
    elseif bag == BAG_BANK then 
        return GetString(SI_GAMEPAD_BANK_CATEGORY_HEADER)
    elseif bag == BAG_GUILDBANK then 
        return string.gsub(GetString(SI_GAMEPAD_GUILD_BANK_CATEGORY_HEADER), " ", "")
    elseif bag == BAG_BUYBACK then 
        return string.gsub(GetString(SI_STORE_MODE_BUY_BACK), " ", "")
    elseif bag == BAG_VIRTUAL then
        return string.gsub(GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER), " ", "")
    end
end

--[[ Gets the "inventory slot", which is to say the button control for a slot ]]
function util.GetInventorySlot(bag, slotIndex)
    local slot = SHARED_INVENTORY:GenerateSingleSlotData(bag, slotIndex)
    if slot and slot.slotControl then
        return slot.slotControl:GetNamedChild("Button")
    end
end

--[[ Gets the config table for the "Retrieve" from craft bag dialog. ]]
function util.GetRetrieveDialogInfo()
    local transferDialogInfoIndex
    if IsInGamepadPreferredMode() then
        transferDialogInfoIndex = "ITEM_TRANSFER_REMOVE_FROM_CRAFT_BAG_GAMEPAD"
    else
        transferDialogInfoIndex = "ITEM_TRANSFER_REMOVE_FROM_CRAFT_BAG_KEYBOARD"
    end
    return ESO_Dialogs[transferDialogInfoIndex]
end

--[[ Searches all available cached transfer queues for an item that is queued
     up for transfer to the given bag. If found, dequeues the transfer item and 
     returns it and the source bag it was transferred from. ]]
function util.GetTransferItem(bag, slotIndex, quantity)
    local self = cbe.utility
    if not self.transferQueueCache[bag] then return end
    for sourceBag, queue in pairs(self.transferQueueCache[bag]) do
        local transferItem = queue:Dequeue(bag, slotIndex, quantity)
        if transferItem then
            return transferItem, sourceBag
        end
    end
end

--[[ Returns a lazy-loaded, cached transfer queue given a source 
     and a destination bag id. ]]
function util.GetTransferQueue(sourceBag, destinationBag)
    local self = cbe.utility
    if not self.transferQueueCache[destinationBag] then
        self.transferQueueCache[destinationBag] = {}
    end
    if not self.transferQueueCache[destinationBag][sourceBag] then
        local queueName = cbe.name .. self.GetBagName(sourceBag) 
                          .. self.GetBagName(destinationBag) .. "Queue"
        self.transferQueueCache[destinationBag][sourceBag] = 
            class.TransferQueue:New(queueName, sourceBag, destinationBag)
    end
    return self.transferQueueCache[destinationBag][sourceBag]
end

--[[ Determines if an inventory slot should be protected against storing in the
     guild bank, selling or mailing. ]]
function util.IsSlotProtected(slot)
    return ( IsItemBound(slot.bagId, slot.slotIndex) 
             or slot.stolen 
             or slot.isPlayerLocked 
             or IsItemBoPAndTradeable(slot.bagId, slot.slotIndex) )
end

--[[ Similar to ZO_PreHook, but works with functions that return a value. 
     The original function will only be called if the hookFunction returns nil. ]]
function util.PreHookReturn(objectTable, existingFunctionName, hookFunction)
    if(type(objectTable) == "string") then
        hookFunction = existingFunctionName
        existingFunctionName = objectTable
        objectTable = _G
    end
     
    local existingFn = objectTable[existingFunctionName]
    if((existingFn ~= nil) and (type(existingFn) == "function"))
    then    
        local newFn =   function(...)
                            local hookReturn = hookFunction(...)
                            if(hookReturn ~= nil) then
                                return hookReturn
                            end
                            return existingFn(...)
                        end

        objectTable[existingFunctionName] = newFn
    end
end
    
--[[ Similar to ZO_PreHook, but works for callback functions, even if none
     is yet defined.  Since this is for callbacks, objectTable is required. ]]
function util.PreHookCallback(objectTable, existingFunctionName, hookFunction)
    local existingFn = objectTable[existingFunctionName]

    local newFn =   function(...)
                        if(not hookFunction(...) 
                           and existingFn ~= nil 
                           and type(existingFn) == "function") 
                        then
                            existingFn(...)
                        end
                    end
    objectTable[existingFunctionName] = newFn
    
end

--[[ Refreshes current item tooltip with latest bag / bank quantities ]]
function util.RefreshActiveTooltip()
    if ItemTooltip:IsHidden() then return end
    local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()
    if not mouseOverControl or mouseOverControl.slotControlType ~= "listSlot" then return end
    local inventorySlot = mouseOverControl:GetNamedChild("Button")
    if inventorySlot then
        util.Debug("Active tooltip refreshed")
        ZO_InventorySlot_OnMouseEnter(inventorySlot)
    end
end

--[[ Changes the keybind mapped to a particular descriptor, identified by its
     old keybind. ]]
function util.RemapKeybind(descriptors, oldKeybind, newKeybind)
    for _,descriptor in ipairs(descriptors) do
        if descriptor.keybind == oldKeybind then
            descriptor.keybind = newKeybind
        end
    end
end

--[[ Combines two functions into a single function, with type checking. ]]
function util.WrapFunctions(function1, function2)
    if type(function1) == "function" then
        if type(function2) == "function" then
            return function(...)
                       function1(...)
                       function2(...)
                   end
        else
            return function1
        end
    else
        return function2
    end
end