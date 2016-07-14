CBE_MailController = ZO_Object:Subclass()

function CBE_MailController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

local me

function CBE_MailController:Initialize()

	me = self
	self.name = "CBE_MailController"

	--[[ Button click callback for toggling between backpack and craft bag. ]]
	local function OnCraftBagMenuButtonClicked(buttonData, playerDriven)
		if MAIL_SEND_SCENE.state ~= SCENE_SHOWN then
			return
		end
		if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
			ZO_PlayerInventory:SetHidden(true)
			ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
			SCENE_MANAGER:AddFragment(CRAFT_BAG_FRAGMENT)
		else
			SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
			ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
			PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK, true)
			ZO_PlayerInventory:SetHidden(false)
		end
	end
	
	--[[ Handle mail send scene open/close events ]]
	local function OnMailSendSceneStateChange(oldState, newState)
	
		-- On exit, remove additional craft bag filtering, and stop listening for any transfers
		if newState == SCENE_HIDDEN then 
			PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG].additionalFilter = nil
			CBE.Inventory:StopTransfer()	
			return 
			
		-- On enter, add filtering for the craft bag to exclude bound, stolen, and locked items
		elseif newState == SCENE_SHOWING then
			PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG].additionalFilter =  
				function(slot)
					-- Workaround for IsItemBound() not working on craft bag slots
					local itemLink = GetItemLink(slot.bagId, slot.slotIndex)
					local bindType = GetItemLinkBindType(itemLink)
					local isBound = (bindType == BIND_TYPE_ON_PICKUP or bindType == BIND_TYPE_ON_PICKUP_BACKPACK)
					local isValid = (not isBound) 
									and (not slot.stolen) 
									and (not slot.isPlayerLocked)
					return isValid
				end
			return
		
		-- Since reopening the mail send scene causes the inventory list to show regardless of 
		-- whether the craft bag was open when it last closed, we need to initialize the craft bag.
		elseif newState ~= SCENE_SHOWN then
			local button = CBE_MailSendMenu.m_object.m_clickedButton
			if not button then return end
			OnCraftBagMenuButtonClicked(button.m_buttonData, false)
		end
	end
    MAIL_SEND_SCENE:RegisterCallback("StateChange",  OnMailSendSceneStateChange)

	--[[ Create craft bag menu ]]
    local menuBar = CreateControlFromVirtual("CBE_MailSendMenu", ZO_MailSend, "ZO_LabelButtonBar")
    menuBar:SetAnchor(TOPRIGHT, ZO_MailSend, TOPLEFT, ZO_MailSendTo:GetWidth(), 22)
    CBE:AddItemsButton(menuBar, OnCraftBagMenuButtonClicked)
    CBE:AddCraftBagButton(menuBar, OnCraftBagMenuButtonClicked)
    ZO_MenuBar_SelectFirstVisibleButton(menuBar, true)
end

--[[ Returns true if the mail send interface is currently open. Otherwise returns false. ]]
local function IsSendingMail()
	if MAIL_SEND and not MAIL_SEND:IsHidden() then
		return true
	elseif MAIL_MANAGER_GAMEPAD and MAIL_MANAGER_GAMEPAD:GetSend():IsAttachingItems() then
		return true
	end
	return false
end

--[[ Returns the index of the attachment slot that's bound to a given inventory slot, 
     or nil if it's not attached. ]]
local function GetAttachmentSlotIndex(bag, slotIndex)
	if (bag) then
		for i = 1, MAIL_MAX_ATTACHED_ITEMS do
			local bagId, attachmentIndex = GetQueuedItemAttachmentInfo(i)
			if bagId == bag and attachmentIndex == slotIndex then
				return i
			end
		end
	end
end

--[[ Returns true if a given inventory slot is attached to the sending mail. 
     Otherwise, returns false. ]]
local function IsAttached(bag, slotIndex)
	local attachmentSlotIndex = GetAttachmentSlotIndex(bag, slotIndex)
	if attachmentSlotIndex then
		return GetQueuedItemAttachmentInfo(attachmentSlotIndex) ~= 0
	end
end

--[[ Called after a Retrieve and Add to Mail operation successfully retrieves a craft bag item 
     to the backpack. Responsible for executing the "Add to Mail" part of the operation. ]]
local function TransferAttachItemCallback()

	if not IsSendingMail() or not CBE.Inventory.waitingForTransfer then return end
	
	local errorStringId = nil
	
	-- Find the first empty attachment slot
	local emptyAttachmentSlotIndex = 0
	for i = 1, MAIL_MAX_ATTACHED_ITEMS do
		local queuedFromBag = GetQueuedItemAttachmentInfo(i)
		if queuedFromBag == 0 then
			emptyAttachmentSlotIndex = i
			break
		end
	end
	
	-- There were no empty attachment slots left
	if emptyAttachmentSlotIndex == 0 then
		errorStringId = SI_MAIL_ATTACHMENTS_FULL
	
	-- Empty attachment slot found.
	else
		local info = CBE.Inventory.waitingForTransfer
		
		-- Attempt the attachment
		local result = QueueItemAttachment(info.targetBag, info.targetSlotIndex, emptyAttachmentSlotIndex)

		-- Assign error messages to different results
		if(result == MAIL_ATTACHMENT_RESULT_ALREADY_ATTACHED) then
			errorStringId = SI_MAIL_ALREADY_ATTACHED
		elseif(result == MAIL_ATTACHMENT_RESULT_BOUND) then
			errorStringId = SI_MAIL_BOUND
		elseif(result == MAIL_ATTACHMENT_RESULT_ITEM_NOT_FOUND) then
			errorStringId = SI_MAIL_ITEM_NOT_FOUND
		elseif(result == MAIL_ATTACHMENT_RESULT_LOCKED) then
			errorStringId = SI_MAIL_LOCKED
		elseif(result == MAIL_ATTACHMENT_RESULT_STOLEN) then
			errorStringId = SI_STOLEN_ITEM_CANNOT_MAIL_MESSAGE
		end
	end
	
	-- If there is an error adding the attachment, output it as an alert and return the mats
	-- back to the craft bag.
	if errorStringId then
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(errorStringId))
		local info = CBE.Inventory.waitingForTransfer
		if not info then return end
		CBE.Inventory:TransferToCraftBag(info.targetBag, info.targetSlotIndex)
	end
end

--[[ Adds mail-specific inventory slot crafting bag actions ]]
function CBE_MailController:AddSlotActions()
	
	local info = CBE.Inventory.slotInfo
	if not IsSendingMail() then return end
	
	-- For attachment slots, check the actual entry slot for the fromCraftBag flag
	if info.slotType == SLOT_TYPE_MAIL_QUEUED_ATTACHMENT then
		local inventoryType = PLAYER_INVENTORY.bagToInventoryType[info.bag]
		local slot = PLAYER_INVENTORY.inventories[inventoryType].slots[info.slotIndex]
		info.fromCraftBag = slot.fromCraftBag
	end
	
	--[[ Detach and Stow ]]
	if IsAttached(info.bag, info.slotIndex) then
		if info.fromCraftBag then
			info.slotActions:AddSlotAction(
				SI_CBE_CRAFTBAG_MAIL_DETACH, 
				function() 
					local attachmentSlotIndex = 
						GetAttachmentSlotIndex(info.bag, info.slotIndex)
					RemoveQueuedItemAttachment(attachmentSlotIndex)
					-- Update the keybind strip command
					ZO_InventorySlot_OnMouseEnter(info.inventorySlot)
					-- Transfer mats back to craft bag
					CBE.Inventory:TransferToCraftBag(info.bag, info.slotIndex)
				end, 
				"primary")
		end
		
	--[[ Retrieve and Add to Mail ]]
	elseif info.slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
		local actionName = SI_CBE_CRAFTBAG_MAIL_ATTACH
		info.slotActions:AddSlotAction(
			actionName, 
			function() 
				CBE.Inventory:StartTransfer(
					info.inventorySlot, 
					actionName, SI_ITEM_ACTION_MAIL_ATTACH, 
					TransferAttachItemCallback) 
			end, 
			"primary")
	end
end