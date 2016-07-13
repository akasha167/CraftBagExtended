CBE_InventoryController = ZO_Object:Subclass()

function CBE_InventoryController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

local me

function CBE_InventoryController:Initialize()

	me = self
	me.name = "CBE_InventoryController"

    --[[ When listening for a transfer callback, handle any "Inventory Full"
         alerts that get raised by stopping the transfer. ]]
	local function OnTransferDialogFailed(category, soundId, message, ...)
		if not me.waitingForTransfer then return end
		local errorStringId = (me.waitingForTransfer.targetBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
		if message == errorStringId then
			me:StopTransfer()
		end
	end
    ZO_PreHook("ZO_Alert", OnTransferDialogFailed)
    
    --[[ Insert our custom craft bag actions into the keybind buttons and 
         context menu whenever an item is hovered. ]]
    local function PreDiscoverSlotActions(inventorySlot, slotActions) 
    
		local slotType = ZO_InventorySlot_GetType(inventorySlot)
		local bag, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
		
		-- fromCraftBag flag marks backpack slots for return/stow actions
		local fromCraftBag = SHARED_INVENTORY:GenerateSingleSlotData(bag, slotIndex).fromCraftBag
		if slotType == SLOT_TYPE_CRAFT_BAG_ITEM or slotType == SLOT_TYPE_MAIL_QUEUED_ATTACHMENT or fromCraftBag then
			me.slotInfo = { 
				inventorySlot = inventorySlot,
				slotType      = slotType, 
				bag           = bag,
				slotIndex     = slotIndex,
				fromCraftBag  = fromCraftBag, 
				slotActions   = slotActions 
			}
			for _, actionHandler in pairs({ CBE.Mail.AddSlotActions, CBE.GuildBank.AddSlotActions}) do
				actionHandler()
			end
			me.slotInfo = nil
		end
	end
	ZO_PreHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", PreDiscoverSlotActions)
	
	-- Get transfer dialog configuration object
	local transferDialogInfo = me:GetTransferDialogInfo()
	
	--[[ Stop listening for backpack slot updates if the transfer dialog is 
	     canceled via button click. ]]
	local transferCancelButton = transferDialogInfo.buttons[2]
	local transferCancelButtonCallback = transferCancelButton.callback
	transferCancelButton.callback = function(...)
		-- If canceled, stop listening for any outstanding transfers
		me:StopTransfer()
		-- Call any other callbacks that already existed
		if transferCancelButtonCallback then
			transferCancelButtonCallback(...)
		end
	end
	
	--[[ Stop listening for backpack slot updates if the transfer dialog is 
	     canceled with no selection (i.e. ESC keypress) ]]
	local transferNoChoiceCallback = transferDialogInfo.noChoiceCallback
	transferDialogInfo.noChoiceCallback = function(...)
		-- If canceled, stop listening for any outstanding transfers
		me:StopTransfer()
		-- Call any other callbacks that already existed
		if noChoiceCallback then
			transferNoChoiceCallback(...)
		end
	end
end

--[[ Handles backpack item slot update events thrown from a "Retrieve" 
     from craft bag dialog. ]]
local function OnBackpackSlotUpdated(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)

	if not me.waitingForTransfer then 
		CBE:Debug("Not waiting for transfer")
		return 
	end
	
	-- Don't handle any update events in the craft bag. We want the backpack events.
	if me.waitingForTransfer.targetBag ~= bagId then 
		CBE:Debug("bag id ("..tostring(bagId)..") does not match "..tostring(me.waitingForTransfer.targetBag))
		return 
	end
	
	-- Double check that the item matches what we are waiting for. I can't 
	-- imagine it would ever be different, but it's best to make sure.
	local backpackItemLink = GetItemLink(bagId, slotId)
	local backpackItemId
	_, _, _, backpackItemId = ZO_LinkHandler_ParseLink( backpackItemLink )
	local waitingForItemId
	_, _, _, waitingForItemId = ZO_LinkHandler_ParseLink( me.waitingForTransfer.itemLink )
	if backpackItemId ~= waitingForItemId then 
		CBE:Debug("item id mismatch")
		return 
	end
	
	-- This flag marks backpack slots for return/stow actions
	SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotId).fromCraftBag = true
	
	-- Raise the callback.  It should never be nil or a nonfunction, 
	-- but check just in case
	if type(me.waitingForTransfer.callback) == "function" then
		CBE:Debug("calling callback")
		me.waitingForTransfer.targetSlotIndex = slotId
		me.waitingForTransfer.callback()
	else
		CBE:Debug("callback was not a function")
	end
	
	-- Stop listening for backpack slot update events
	me:StopTransfer()	
	
	-- Refresh the backpack slot list
	local inventoryType = PLAYER_INVENTORY.bagToInventoryType[bagId]
	PLAYER_INVENTORY:UpdateList(inventoryType, true)
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

--[[ Cancels any pending StartTransfer() requests. ]]
function CBE_InventoryController:StopTransfer()

	-- Unregister pending callback information
	me.waitingForTransfer = nil
	
	-- Stop listening for backpack slot update events that would trigger a callback
	EVENT_MANAGER:UnregisterForEvent(CBE.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
	
	-- Change the transfer dialog's title and button text back to the defaults
	local transferDialogInfo = me:GetTransferDialogInfo()
	transferDialogInfo.title.text = SI_PROMPT_TITLE_REMOVE_ITEMS_FROM_CRAFT_BAG
	transferDialogInfo.buttons[1].text = SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG
end

--[[ Opens the "Retrieve" from craft bag dialog with a custom action name for
     the transfer button.  Automatically runs a given callback once the transfer
     is complete. ]]
function CBE_InventoryController:StartTransfer(inventorySlot, dialogTitle, buttonText, callback)
	local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
	
	-- Validate that there is enough bag space for the transfer.  
	-- Should probably verify an empty slot instead, since that's what the callback
	-- function uses.
	if not DoesBagHaveSpaceFor(BAG_BACKPACK, bag, index) then
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
		return
	end
	
	-- Register callback information
	local itemLink = GetItemLink(bag, index)
	me.waitingForTransfer = { 
		itemLink = itemLink,
		targetBag = BAG_BACKPACK,
		callback  = callback
	}
	
	-- Listen for backpack slot update events so that we can process the callback
	EVENT_MANAGER:RegisterForEvent(CBE.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBackpackSlotUpdated)
	
	-- Override the text of the transfer dialog's title and/or button
	local transferDialogInfo = me:GetTransferDialogInfo()
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
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", bag, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    else
        RequestMoveItem(bag, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    end
end