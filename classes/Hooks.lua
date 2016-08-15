local cbe  = CraftBagExtended
local util = cbe.utility

 --[[ Handle craft bag open/close events ]]
local function OnCraftBagFragmentStateChange(oldState, newState)
    -- On craft bag exit, stop listening for any transfers
    if newState == SCENE_FRAGMENT_HIDDEN then 
        cbe.backpackTransferQueue:Clear()
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
    
    -- This flag marks backpack slots for return/stow actions
    if sourceBagId == BAG_VIRTUAL then
        SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotId).fromCraftBag = true
    end
    
    -- Perform any configured callbacks
    transferredItem:ExecuteCallback(slotId)
    
    -- Refresh the appropriate bag slot list
    local inventoryType = PLAYER_INVENTORY.bagToInventoryType[bagId]
    PLAYER_INVENTORY:UpdateList(inventoryType, true)
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

--[[ When listening for transfer callbacks, handle any "Inventory Full"
     alerts that get raised by stopping all transfers. ]]
local function OnTransferDialogFailed(category, soundId, message, ...)
    if not cbe.backpackTransferQueue:HasItems() then return end
    local errorStringId = SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
    if message == errorStringId then
        cbe.backpackTransferQueue:Clear()
    end
end

--[[ Do not add duplicate inventory slot context menu actions with the same names ]]
local function PreAddSlotAction(slotActions, actionStringId, actionCallback, actionType, visibilityFunction, options)
    local actionName = GetString(actionStringId)
    for i=1,slotActions:GetNumSlotActions() do
        local action = slotActions:GetSlotAction(i)
        if action and action[1] == actionName then
            return true
        end
    end
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
    
    -- We don't have any slot actions for bags other than the backpack, the
    -- craft bag, and the guild bank.
    if bag ~= BAG_BACKPACK and bag ~= BAG_VIRTUAL and bag ~= BAG_GUILDBANK then
        return
    end
    
    -- fromCraftBag flag marks backpack slots for return/stow actions
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(bag, slotIndex)
    
    if not slotData then return end
    
    local fromCraftBag = slotData.fromCraftBag
    
    if slotType == SLOT_TYPE_CRAFT_BAG_ITEM or slotType == SLOT_TYPE_MAIL_QUEUED_ATTACHMENT or slotType == SLOT_TYPE_MY_TRADE or fromCraftBag then
        local slotInfo = { 
            inventorySlot = inventorySlot,
            slotType      = slotType, 
            bag           = bag,
            slotIndex     = slotIndex,
            fromCraftBag  = fromCraftBag, 
            slotActions   = slotActions 
        }
        for moduleName,module in pairs(cbe.modules) do
            module:AddSlotActions(slotInfo)
        end
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
    
local function PreTransferDialogCanceled(dialog)
    -- If canceled, remove the transfer item from the queue
    local transferItem = cbe.transferDialogItem
    if not transferItem then return end
    transferItem.queue:Dequeue(transferItem.slotIndex, cbe.constants.QUANTITY_UNSPECIFIED)
    cbe.transferDialogItem = nil
end

local function PreTransferDialogFinished(dialog)
    local transferDialogInfo = dialog.info
    -- Record the quantity entered from the dialog
    local transferItem = cbe.transferDialogItem
    if transferItem then
        cbe.transferDialogItem = nil
        local quantity
        if IsInGamepadPreferredMode() then
            quantity = ZO_GamepadDialogItemSliderItemSliderSlider:GetValue()
        else
            quantity = tonumber(ZO_ItemTransferDialogSpinnerDisplay:GetText())
        end
        transferItem.queue:SetQuantity(transferItem, quantity)
    end

    --[[ Change the transfer dialog's title and button text back to the defaults
    transferDialogInfo.title.text = SI_PROMPT_TITLE_REMOVE_ITEMS_FROM_CRAFT_BAG
    transferDialogInfo.buttons[1].text = SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG
    
    -- Restore the transfer button's callback function to its original state
    if type(transferDialogInfo.originalTransferCallback) == "function" then
        transferDialogInfo.buttons[1].callback = transferDialogInfo.originalTransferCallback
        transferDialogInfo.originalTransferCallback = nil
    end]]
end

function CraftBagExtended:InitializeHooks()

    ZO_PreHook("ZO_Alert", OnTransferDialogFailed)
    
    -- Disallow duplicates with same names
    ZO_PreHook(ZO_InventorySlotActions, "AddSlotAction", PreAddSlotAction)
    
    ZO_PreHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", PreDiscoverSlotActions)
    
    util.PreHookReturn("IsItemBound", PreIsItemBound)
    
    ZO_PreHook(PLAYER_INVENTORY, "ShouldAddSlotToList", PreInventoryShouldAddSlotToList)
    
    -- Listen for bag slot update events so that we can process the callback
    EVENT_MANAGER:RegisterForEvent(cbe.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
    
    -- Get transfer dialog configuration object
    local transferDialogInfo = util.GetRetrieveDialogInfo()
    
    --[[ Dequeue the transfer if the transfer dialog is canceled via button click. ]]
    local transferCancelButton = transferDialogInfo.buttons[2]
    util.PreHookCallback(transferCancelButton, "callback", PreTransferDialogCanceled)
    
    --[[ Dequeue the transfer if the transfer dialog is canceled with no 
         selection (i.e. ESC keypress) ]]
    util.PreHookCallback(transferDialogInfo, "noChoiceCallback", PreTransferDialogCanceled)
    
    --[[ Whenever the transfer dialog is finished, set the quantity in the queue ]]
    util.PreHookCallback(transferDialogInfo, "finishedCallback", PreTransferDialogFinished)
    
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