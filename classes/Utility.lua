local cbe     = CraftBagExtended
local class   = cbe.classes
class.Utility = ZO_Object:Subclass()
local util    = class.Utility
function util:New(...)
    self.name = cbe.name .. "Utility"
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