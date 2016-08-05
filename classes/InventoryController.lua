CBE_InventoryController = ZO_Object:Subclass()

function CBE_InventoryController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

-- Stores the additionalFilter function of the craft bag inventory the first
-- time that a backpack layout is applied to ZO_CraftBag
local baseCraftBagFilter
local originalApplySharedBagLayout = PLAYER_INVENTORY.ApplySharedBagLayout

function CBE_InventoryController:Initialize()

    self.name = "CBE_InventoryController"
    self.debug = false
    self.backpackTransferQueue = CBE_TransferQueue:New(self.name.."Queue")

    --[[ When listening for transfer callbacks, handle any "Inventory Full"
         alerts that get raised by stopping all transfers. ]]
    local function OnTransferDialogFailed(category, soundId, message, ...)
        if not self.backpackTransferQueue:HasItems() then return end
        local errorStringId = SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
        if message == errorStringId then
            self.backpackTransferQueue:Clear()
        end
    end
    ZO_PreHook("ZO_Alert", OnTransferDialogFailed)
    
    --[[ Do not add duplicate inventory slot context menu actions with the same
         names ]]
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
            CBE.Mail:AddSlotActions(slotInfo)
            CBE.GuildBank:AddSlotActions(slotInfo)
            CBE.Trade:AddSlotActions(slotInfo)
        end
        
        -- Disallow duplicates with same names
        ZO_PreHook(slotActions, "AddSlotAction", PreAddSlotAction)
    end
    ZO_PreHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", PreDiscoverSlotActions)
    
    
    --[[ Workaround for IsItemBound() not working on craft bag slots ]]
    local isItemBound = _G["IsItemBound"]
    _G["IsItemBound"] = function(bagId, slotIndex)
        if bagId == BAG_VIRTUAL then
            local itemLink = GetItemLink(bagId, slotIndex)
            local bindType = GetItemLinkBindType(itemLink)
            if bindType == BIND_TYPE_ON_PICKUP or bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
                return true
            end
        end
        return isItemBound(bagId, slotIndex)
    end
    
    
    --[[ Pre-hook for PLAYER_INVENTORY:ApplySharedBagLayout. Used to hook the
         craft bag inventory additionalFilter the first time that a backpack layout
         is applied. ]]
    local function PreApplySharedBagLayout(inventoryManager, inventoryControl, layoutData)
        if inventoryControl ~= ZO_CraftBag then return end
        local inventory = inventoryManager.inventories[INVENTORY_CRAFT_BAG]
        baseCraftBagFilter = inventory.additionalFilter
        inventory.additionalFilter = CBE_InventoryController_AdditionalCraftBagFilter
        -- unhook ApplySharedBagLayout
        inventoryManager.ApplySharedBagLayout = originalApplySharedBagLayout
    end
    ZO_PreHook(PLAYER_INVENTORY, "ApplySharedBagLayout", PreApplySharedBagLayout)
    

    --[[ Handles backpack item slot update events thrown from a "Retrieve" 
         from craft bag dialog. ]]
    local function OnBackpackSlotUpdated(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)

        if bagId ~= BAG_BACKPACK then return end
        if not self.backpackTransferQueue:HasItems() then 
            CBE:Debug("Not waiting for any backpack transfers reason "..tostring(itemSoundCategory), self.debug)
            return 
        end
        
        local transferredItem = self.backpackTransferQueue:Dequeue(bagId, slotId)
        
        -- Don't handle any update events in the craft bag. We want the backpack events.
        if not transferredItem then 
            CBE:Debug("No outstanding transfers found for backpack slot id "..tostring(slotId).." reason "..tostring(itemSoundCategory), self.debug)
            return 
        end
        
        -- This flag marks backpack slots for return/stow actions
        SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotId).fromCraftBag = true
        
        -- Raise the callback.  It should never be nil or a nonfunction, 
        -- but check just in case
        if type(transferredItem.callback) == "function" then
            CBE:Debug("calling callback on backpack slot "..tostring(slotId).." reason "..tostring(itemSoundCategory), self.debug)
            transferredItem.targetSlotIndex = slotId
            transferredItem.callback(transferredItem)
        else
            CBE:Debug("callback on backpack slot "..tostring(slotId).." was not a function. it was a "..callbackType.." reason "..tostring(itemSoundCategory), self.debug)
        end
        
        -- Refresh the backpack slot list
        local inventoryType = PLAYER_INVENTORY.bagToInventoryType[bagId]
        PLAYER_INVENTORY:UpdateList(inventoryType, true)
    end
    
    -- Listen for backpack slot update events so that we can process the callback
    EVENT_MANAGER:RegisterForEvent(CBE.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBackpackSlotUpdated)
    
    -- Get transfer dialog configuration object
    local transferDialogInfo = self:GetTransferDialogInfo()
    
    local function OnTransferDialogCanceled()
        -- If canceled, remove the transfer item from the queue
        local transferItem = transferDialogInfo.CBE_transferItem
        if not transferItem then return end
        self.backpackTransferQueue:Dequeue(transferItem.bag, transferItem.slotIndex, CBE_QUANTITY_UNSPECIFIED)
        transferDialogInfo.CBE_transferItem = nil
    end
    
    --[[ Stop listening for backpack slot updates if the transfer dialog is 
         canceled via button click. ]]
    local transferCancelButton = transferDialogInfo.buttons[2]
    local transferCancelButtonCallback = transferCancelButton.callback
    transferCancelButton.callback = function(...)
        OnTransferDialogCanceled()
        -- Call any other callbacks that already existed
        if transferCancelButtonCallback then
            transferCancelButtonCallback(...)
        end
    end
    
    --[[ Stop listening for backpack slot updates if the transfer dialog is 
         canceled with no selection (i.e. ESC keypress) ]]
    local transferNoChoiceCallback = transferDialogInfo.noChoiceCallback
    transferDialogInfo.noChoiceCallback = function(...)
        OnTransferDialogCanceled()
        -- Call any other callbacks that already existed
        if noChoiceCallback then
            transferNoChoiceCallback(...)
        end
    end
    
    --[[ Whenever the "Retrieve" from craftbag dialog is closed, restore default settings ]]
    local transferFinishedCallback = transferDialogInfo.finishedCallback
    transferDialogInfo.finishedCallback = function(...)
    
        -- Record the quantity entered from the dialog
        local transferItem = transferDialogInfo.CBE_transferItem
        if transferItem then
            transferDialogInfo.CBE_transferItem = nil
            local quantity
            if IsInGamepadPreferredMode() then
                quantity = ZO_GamepadDialogItemSliderItemSliderSlider:GetValue()
            else
                quantity = tonumber(ZO_ItemTransferDialogSpinnerDisplay:GetText())
            end
            self.backpackTransferQueue:SetQuantity(transferItem, quantity)
        end
    
        -- Change the transfer dialog's title and button text back to the defaults
        transferDialogInfo.title.text = SI_PROMPT_TITLE_REMOVE_ITEMS_FROM_CRAFT_BAG
        transferDialogInfo.buttons[1].text = SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG
        
        -- Restore the transfer button's callback function to its original state
        if type(transferDialogInfo.originalTransferCallback) == "function" then
            transferDialogInfo.buttons[1].callback = transferDialogInfo.originalTransferCallback
            transferDialogInfo.originalTransferCallback = nil
        end
    
        -- Call any other callbacks that already existed
        if transferFinishedCallback then
            transferFinishedCallback(...)
        end
    end
    
end

--[[ Gets the config table for the "Retrieve" from craft bag dialog ]]
function CBE_InventoryController:GetTransferDialogInfo()
    local transferDialogInfoIndex
    if IsInGamepadPreferredMode() then
        transferDialogInfoIndex = "ITEM_TRANSFER_REMOVE_FROM_CRAFT_BAG_GAMEPAD"
    else
        transferDialogInfoIndex = "ITEM_TRANSFER_REMOVE_FROM_CRAFT_BAG_KEYBOARD"
    end
    return ESO_Dialogs[transferDialogInfoIndex]
end

--[[ Refreshes current item tooltip with latest bag / bank quantities ]]
function CBE_InventoryController:RefreshActiveTooltip()
    if ItemTooltip:IsHidden() then return end
    local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()
    if not mouseOverControl or mouseOverControl.slotControlType ~= "listSlot" then return end
    local inventorySlot = mouseOverControl:GetNamedChild("Button")
    if inventorySlot then
        CBE:Debug("Active tooltip refreshed", self.debug)
        ZO_InventorySlot_OnMouseEnter(inventorySlot)
    end
end

--[[ Registers a new transfer item and callback for backpack slot updates for the 
     item originating at the given bag and index. ]]
function CBE_InventoryController:StartWaitingForTransfer(bag, index, callback, quantity)
    
    -- Validate that there is a free slot in the backpack to receive the stack
    if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
        return
    end
    
    -- Register callback information
    if not callback then
        CBE:Debug("null callback encountered for bag "..tostring(bag).." slot "..tostring(index).." qty "..tostring(quantity), this.debug)
    end
    local transferItem = self.backpackTransferQueue:Enqueue(bag, index, quantity, BAG_BACKPACK, callback)
    
    return transferItem
end

--[[ Opens the "Retrieve" from craft bag dialog with a custom action name for
     the transfer button.  Automatically runs a given callback once the transfer
     is complete. ]]
function CBE_InventoryController:StartTransfer(inventorySlot, dialogTitle, buttonText, callback)
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    
    -- Start listening for backpack slot update events
    local transferItem = self:StartWaitingForTransfer(bag, index, callback, CBE_QUANTITY_UNSPECIFIED)
    if not transferItem then return end
    
    -- Override the text of the transfer dialog's title and/or button
    local transferDialogInfo = self:GetTransferDialogInfo()
    
    transferDialogInfo.CBE_transferItem = transferItem
    
    if dialogTitle then
        transferDialogInfo.title.text = dialogTitle
    end
    if buttonText then
        transferDialogInfo.buttons[1].text = buttonText
    end
    
    -- Open the transfer dialog
    local transferDialog = SYSTEMS:GetObject("ItemTransferDialog")
    transferDialog:StartTransfer(bag, index, BAG_BACKPACK)
end

--[[ Moves an item at the given bag and slot index into the craft bag. ]]
function CBE_InventoryController:TransferToCraftBag(bag, slotIndex)
    
    local inventoryLink = GetItemLink(bag, slotIndex)
    
    -- Find any existing slots in the craft bag that have the given item already
    local targetSlotIndex = nil
    for currentSlotIndex,slotData in ipairs(PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG].slots) do
        local craftBagLink = GetItemLink(BAG_VIRTUAL, currentSlotIndex)
        if craftBagLink == inventoryLink then
            targetSlotIndex = currentSlotIndex
            break
        end
    end
    
    -- The craft bag didn't have the item yet, so get a new empty slot
    if not targetSlotIndex then
        targetSlotIndex = FindFirstEmptySlotInBag(BAG_VIRTUAL)
    end
    
    -- Move the item into the identified craft bag slot
    local quantity = GetSlotStackSize(bag, slotIndex)
    
    CBE:Debug("Transferring "..tostring(quantity).." "..inventoryLink.." to craft bag slot "..tostring(targetSlotIndex), self.debug)
    
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", bag, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    else
        RequestMoveItem(bag, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    end
end

--[[ Run on inventory slots when determining if they should be added to the 
     ZO_CraftBag control. Applies backpack layouts with filters to craft bag ]]
function CBE_InventoryController_AdditionalCraftBagFilter(slot)
    -- Exclude all items that are not crafting mats
    if type(baseCraftBagFilter)=="function" and not baseCraftBagFilter(slot) then
        return false
    end
    local layout = PLAYER_INVENTORY.appliedLayout
    if layout and type(layout.additionalFilter) == "function" and not layout.additionalFilter(slot) then
        return false
    end
    return true
end