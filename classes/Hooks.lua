local cbe  = CraftBagExtended
local util = cbe.utility

 --[[ Handle craft bag open/close events ]]
local function OnCraftBagFragmentStateChange(oldState, newState)
    -- On craft bag exit, stop listening for any transfers
    if newState == SCENE_FRAGMENT_HIDDEN then 
        util:ClearTransferQueues()
        return 
    -- On craft bag showing event, move the info bar to the craft bag
    elseif newState == SCENE_FRAGMENT_SHOWING then
        ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
        if TweakIt and ExtendedInfoBar then
            ExtendedInfoBar:SetParent(ZO_CraftBag)
        end
    end
end

--[[ Handle player inventory open events ]]
local function OnInventoryFragmentStateChange(oldState, newState)
    -- On enter, move the info bar back to the backpack, if not there already
    if newState == SCENE_FRAGMENT_SHOWING then
        ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
        if TweakIt and ExtendedInfoBar then
            ExtendedInfoBar:SetParent(ZO_PlayerInventory)
        end
    end
end

--[[ Handles inventory item slot update events and raise any callbacks queued up. ]]
local function OnInventorySingleSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)

    local transferredItem, sourceBagId = util.GetTransferItem(bagId, slotId)
    
    -- Don't handle any update events in the craft bag. We want the backpack events.
    if not transferredItem then 
        util.Debug("No outstanding transfers found for bag "..tostring(bagId).." slot id "..tostring(slotId).." reason "..tostring(itemSoundCategory))
        return 
    end
    
    -- This flag marks inventory and bank slots for return/stow actions
    if bagId ~= BAG_VIRTUAL and not transferredItem.noAutoReturn then
        SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotId).fromCraftBag = true
    end
    
    -- Refresh the appropriate bag slot list
    local inventoryType = PLAYER_INVENTORY.bagToInventoryType[bagId]
    PLAYER_INVENTORY:UpdateList(inventoryType, true)
    
    -- Perform any configured callbacks
    transferredItem:ExecuteCallback(slotId)
end

--[[ Handle scene changes involving a craft bag. ]]
local function OnModuleSceneStateChange(oldState, newState)
    if newState == SCENE_SHOWING then
        -- When switching craft bag scenes, we need to do a list update, since
        -- ZOS doesn't do it by default like they do with the main backpack
        if cbe.currentScene ~= SCENE_MANAGER.currentScene then
            cbe.currentScene = SCENE_MANAGER.currentScene
            local UPDATE_EVEN_IF_HIDDEN = true
            PLAYER_INVENTORY:UpdateList(INVENTORY_CRAFT_BAG, UPDATE_EVEN_IF_HIDDEN)
        end
    end
end

--[[ Runs whenever a new inventory slot action is added. Used to ammend the
     available keybinds, as well as supporess existing slot actions names that 
     would conflict with ours. ]]
local function PreAddSlotAction(slotActions, actionStringId, actionCallback, actionType, visibilityFunction, options)
   
    -- Add a keybind3 handler for the Q key
    if cbe.addingSlotActions then
        
        if actionType == "keybind3" then
            local actionName = GetString(actionStringId)
            slotActions.m_keybindActions[3] = { 
                actionName, actionCallback, "keybind", 
                visibilityFunction, options 
            }
        end
    
    -- Suppress existing slot actions that would conflict with ours.
    elseif cbe.customSlotActionDescriptors then
        for _, moduleSlotAction in ipairs(cbe.customSlotActionDescriptors) do
            if moduleSlotAction[1] == actionStringId then
                return true
            end
        end
    end
end

--[[ When listening for transfer callbacks, handle any inventory or bank full
     alerts that get raised by stopping all transfers. ]]
local function PreAlert(category, soundId, message, ...)
    if message == SI_INVENTORY_ERROR_INVENTORY_FULL 
	   or message == SI_INVENTORY_ERROR_BANK_FULL
	then
        util:ClearTransferQueues()
    end
end

local function PreInventorySlotActionsGetAction(slotActions)
    if not cbe.customSlotActionDescriptors 
       or not slotActions 
       or not slotActions.m_inventorySlot 
       or slotActions.craftBagExtendedPostHooked
    then 
        return 
    end
    cbe.addingSlotActions = true
    for _, moduleSlotAction in ipairs(cbe.customSlotActionDescriptors) do
        if moduleSlotAction[3] == "secondary" then
            slotActions:AddSlotAction(unpack(moduleSlotAction))
        end
    end
    cbe.addingSlotActions = nil
    slotActions.craftBagExtendedPostHooked = true
end

local function PreInventorySlotActionsClear(slotActions)
    slotActions.craftBagExtendedPostHooked = false
end

--[[ Insert our custom craft bag actions into the keybind buttons and 
     context menu whenever an item is hovered. ]]
local function PreDiscoverSlotActions(inventorySlot, slotActions) 

    if not inventorySlot then return end
    
    local slotType = ZO_InventorySlot_GetType(inventorySlot)

    local bag, slotIndex
    if slotType == SLOT_TYPE_MY_TRADE then
        local tradeIndex = ZO_Inventory_GetSlotIndex(inventorySlot)
        bag, slotIndex = GetTradeItemBagAndSlot(TRADE_ME, tradeIndex)
    else
        bag, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    end
    
    -- We don't have any slot actions for bags other than those in BAG_TYPES
    if not cbe.constants.BAG_TYPES[bag] then
        return
    end
    
    -- fromCraftBag flag marks backpack slots for return/stow actions
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(bag, slotIndex)
    
    if not slotData then return end
    
    local fromCraftBag = slotData.fromCraftBag
    
    if fromCraftBag or cbe.constants.SLOT_TYPES[slotType] then
        
        if not slotActions.craftBagExtendedHooked then
            ZO_PreHook(slotActions, "Clear", PreInventorySlotActionsClear)
            ZO_PreHook(slotActions, "GetAction", PreInventorySlotActionsGetAction)
            ZO_PreHook(slotActions, "Show", PreInventorySlotActionsGetAction)
            slotActions.craftBagExtendedHooked = true
        end
        cbe.customSlotActionDescriptors = {}
        local slotInfo = { 
            inventorySlot = inventorySlot,
            slotType      = slotType, 
            bag           = bag,
            slotIndex     = slotIndex,
            slotData      = slotData,
            fromCraftBag  = fromCraftBag, 
            slotActions   = cbe.customSlotActionDescriptors,
        }
        for moduleName,module in pairs(cbe.modules) do
            if type(module.AddSlotActions) == "function" then
                module:AddSlotActions(slotInfo)
            end
        end
        cbe.addingSlotActions = true
        for _, moduleSlotAction in ipairs(cbe.customSlotActionDescriptors) do
            if moduleSlotAction[3] ~= "secondary" then
                slotActions:AddSlotAction(unpack(moduleSlotAction))
            end
        end
        cbe.addingSlotActions = nil
        cbe.slotActions = slotActions
    else
        cbe.customSlotActionDescriptors = nil
    end
end

--[[ Pre-hook for PLAYER_INVENTORY:ShouldAddSlotToList. Used to apply additional
     filters to the craft bag to remove items that don't make sense in the 
     current context. ]]
local function PreInventoryShouldAddSlotToList(inventoryManager, inventory, slot)
    if not slot or slot.stackCount <= 0
       or inventory ~= inventoryManager.inventories[INVENTORY_CRAFT_BAG]
    then
        return 
    end
    for moduleName, module in pairs(cbe.modules) do
        if type(module.FilterSlot) == "function" 
           and module:FilterSlot( inventoryManager, inventory, slot )
        then
            return true
        end
    end
end

--[[ Workaround for IsItemBound() not working on craft bag slots ]]
local function PreIsItemBound(bagId, slotIndex)
    if bagId == BAG_VIRTUAL then
        local itemLink = GetItemLink(bagId, slotIndex)
        local bindType = GetItemLinkBindType(itemLink)
        if bindType == BIND_TYPE_ON_PICKUP or bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
            return true
        end
    end
end

--[[ Add quantity keybind option for the custom "keybind3" action type ]]
local quantityKeybind = {
    name     = function()
                   return cbe.slotActions and cbe.slotActions:GetKeybindActionName(3)
               end,
    keybind  = cbe.constants.KEYBIND_QUANTITY,
    callback = function()
                   if cbe.slotActions then 
                       cbe.slotActions:DoKeybindAction(3)
                   end
               end,
    visible  = function()
                   return cbe.slotActions and cbe.slotActions:CheckKeybindActionVisibility(3)
               end,
    hasBind  = function()
                   return cbe.slotActions and cbe.slotActions:GetKeybindActionName(3) ~= nil
               end,
}
local function PreItemSlotActionsControllerAddSubCommand(slotActionsController, command, hasBind, activateCallback)

    -- Hook into when the tertiary keybind slot is created. 
    -- This should only be on keyboard mode.
    if command.keybind ~= "UI_SHORTCUT_TERTIARY" then return end
    
    -- Create the tertiary keybind as usual
    slotActionsController[#slotActionsController + 1] = 
        { command, hasBind = hasBind, activateCallback = activateCallback }
    
    -- Create a quickslot keybind whenever the tertiary keybind is created
    quantityKeybind.alignment = command.alignment
    slotActionsController:AddSubCommand(quantityKeybind, quantityKeybind.hasBind)
    
    -- Do not execute the tertiary keybind add, since it's already been added
    return true
end
    
local function PreTransferDialogCanceled(dialog)
    -- If canceled, remove the transfer item from the queue
    cbe.transferDialogCanceled = true
    local transferItem = cbe.transferDialogItem
    if not transferItem then return end
    transferItem.queue:Dequeue(transferItem.slotIndex, cbe.constants.QUANTITY_UNSPECIFIED)
    cbe.transferDialogItem = nil
end

local function PreTransferDialogFinished(dialog)
    if cbe.transferDialogCanceled then return end
    
    -- Record the quantity entered from the dialog
    local transferItem = cbe.transferDialogItem
    cbe.transferDialogItem = nil
    local quantity
    if IsInGamepadPreferredMode() then
        quantity = ZO_GamepadDialogItemSliderItemSliderSlider:GetValue()
    else
        local transferDialog = SYSTEMS:GetKeyboardObject("ItemTransferDialog")
        quantity = transferDialog:GetSpinnerValue()
        
        -- Save or clear default quantity
        local scope = util.GetTransferItemScope(transferDialog.targetBag)
        local default = ZO_CheckButton_IsChecked(transferDialog.checkboxControl) and quantity or nil
        local _, itemId = util.GetItemLinkAndId(transferDialog.bag, transferDialog.slotIndex)
        cbe.settings:SetTransferDefault(scope, itemId, default)
    end
    if transferItem then
        transferItem.queue:SetQuantity(transferItem, quantity)
    end
end

local function PreTransferDialogRefresh(transferDialog)

    local self = transferDialog
    local scope = util.GetTransferItemScope(transferDialog.targetBag)
    local _, itemId = util.GetItemLinkAndId(transferDialog.bag, transferDialog.slotIndex)
    local default = cbe.settings:GetTransferDefault(scope, itemId)
    ZO_CheckButton_SetCheckState(transferDialog.checkboxControl, default ~= nil)
    if type(default) == "number" then
        self.spinner:SetValue(default, true)
    end
end

function CraftBagExtended:InitializeHooks()

    -- Fix for craft bag tabs not adjusting correctly to backpack layout
    local _, _, _, _, tabsOffsetX = ZO_CraftBagTabs:GetAnchor(0)
    ZO_CraftBagTabs:ClearAnchors()
    ZO_CraftBagTabs:SetAnchor(BOTTOMRIGHT, ZO_CraftBagFilterDivider, TOPRIGHT, tabsOffsetX, -14, 0)
    
    ZO_PreHook("ZO_Alert", PreAlert)
    
    -- Disallow duplicates with same names
    ZO_PreHook(ZO_InventorySlotActions, "AddSlotAction", PreAddSlotAction)
    
    ZO_PreHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", PreDiscoverSlotActions)
    ZO_PreHook(ZO_ItemSlotActionsController, "AddSubCommand", PreItemSlotActionsControllerAddSubCommand)
    
    util.PreHookReturn("IsItemBound", PreIsItemBound)
    
    ZO_PreHook(PLAYER_INVENTORY, "ShouldAddSlotToList", PreInventoryShouldAddSlotToList)
    
    -- Listen for bag slot update events so that we can process the callback
    EVENT_MANAGER:RegisterForEvent(cbe.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
    
    -- Get transfer dialog configuration object
    local transferDialogKeys = { 
        "ITEM_TRANSFER_REMOVE_FROM_CRAFT_BAG_GAMEPAD", 
        "ITEM_TRANSFER_REMOVE_FROM_CRAFT_BAG_KEYBOARD", 
        "ITEM_TRANSFER_ADD_TO_CRAFT_BAG_GAMEPAD", 
        "ITEM_TRANSFER_ADD_TO_CRAFT_BAG_KEYBOARD" 
    }
    for i, transferDialogKey in ipairs(transferDialogKeys) do
    
        local transferDialogInfo = ESO_Dialogs[transferDialogKey]
        
        --[[ Dequeue the transfer if the transfer dialog is canceled via button click. ]]
        local transferCancelButton = transferDialogInfo.buttons[2]
        util.PreHookCallback(transferCancelButton, "callback", PreTransferDialogCanceled)
        
        --[[ Dequeue the transfer if the transfer dialog is canceled with no 
             selection (i.e. ESC keypress) ]]
        util.PreHookCallback(transferDialogInfo, "noChoiceCallback", PreTransferDialogCanceled)
        
        --[[ Whenever the transfer dialog is finished, set the quantity in the queue ]]
        util.PreHookCallback(transferDialogInfo, "finishedCallback", PreTransferDialogFinished)
    end
    
    --[[ Load any default values for the transfer dialog ]]
    ZO_PreHook(SYSTEMS:GetKeyboardObject("ItemTransferDialog"), "Refresh", PreTransferDialogRefresh)
    
    --[[ Handle craft bag open/close events ]]
    CRAFT_BAG_FRAGMENT:RegisterCallback("StateChange",  OnCraftBagFragmentStateChange)
    
    --[[ Handle player inventory open events ]]
    INVENTORY_FRAGMENT:RegisterCallback("StateChange",  OnInventoryFragmentStateChange)
    
    --[[ Handle craft bag scene changes ]]
    SCENE_MANAGER.scenes["inventory"]:RegisterCallback("StateChange",  OnModuleSceneStateChange)
    for moduleName, module in pairs(self.modules) do
        if type(module.sceneName) == "string" and SCENE_MANAGER.scenes[module.sceneName] then
            SCENE_MANAGER.scenes[module.sceneName]:RegisterCallback("StateChange",  OnModuleSceneStateChange)
        end
    end
    if AwesomeGuildStore then
        SCENE_MANAGER.scenes["tradinghouse"]:RegisterCallback("StateChange",  OnModuleSceneStateChange)
    end
    
end