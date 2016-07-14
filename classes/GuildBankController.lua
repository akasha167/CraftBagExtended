CBE_GuildBankController = ZO_Object:Subclass()

function CBE_GuildBankController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

local me

function CBE_GuildBankController:Initialize()

    me = self
    self.name = "CBE_GuildBankController"
    
    -- used by SwitchScene() below
    local guildBankFragments = {
        [SI_BANK_WITHDRAW] = { GUILD_BANK_FRAGMENT },
        [SI_BANK_DEPOSIT]  = { INVENTORY_FRAGMENT, BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT },
        [SI_INVENTORY_MODE_CRAFT_BAG] = { CRAFT_BAG_FRAGMENT },
    }
    
    -- used by OnGuildBankSceneStateChange() below
    local anchors = { }
    
	--[[ Removes and adds the appropriate window fragments to display the given tabs. ]]
    local function SwitchScene(oldScene, newScene) 
    
		-- Remove the old tab's fragments
        local removeFragments = guildBankFragments[oldScene]
        for i,removeFragment in pairs(removeFragments) do
            SCENE_MANAGER:RemoveFragment(removeFragment)
        end
        
        -- Move the item count bar at the bottom to the correct window
        if newScene == SI_INVENTORY_MODE_CRAFT_BAG then
            ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
        elseif oldScene == SI_INVENTORY_MODE_CRAFT_BAG then
            ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
        end
        
        -- Add the new tab's fragments
        local addFragments = guildBankFragments[newScene]
        for i,addFragment in pairs(addFragments) do
            SCENE_MANAGER:AddFragment(addFragment)
        end
    end

	--[[ Handle button clicks for deposit, withdraw, and craft bag buttons. ]]
    local function OnGuildBankTabChanged(buttonData, playerDriven)

        -- If the scene is in the process of showing still, no switch is needed
        local guildBankSceneState = SCENE_MANAGER.scenes["guildBank"].state
        if guildBankSceneState == SCENE_SHOWING then 
			-- Remember the previous tab so we know which scene to hide when changing
            self.lastButtonDescriptor = buttonData.descriptor
            return 
        end
        
        -- Show or hide the craft bag window
        if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG or self.lastButtonDescriptor == SI_INVENTORY_MODE_CRAFT_BAG then
            SwitchScene(self.lastButtonDescriptor, buttonData.descriptor)
        end
        
        -- Remember the previous tab so we know which scene to hide when changing
        self.lastButtonDescriptor = buttonData.descriptor
    end

	--[[ Handle guild bank screen open/close events ]]
    local function OnGuildBankSceneStateChange(oldState, newState)
        local anchorTemplate
        
        -- On enter, set craft bag window anchors to be the same as the guild 
        -- bank window's anchors
        if(newState == SCENE_SHOWING) then
            anchorTemplate = ZO_GuildBank:GetName()
            
        -- On exit, stop any outstanding transfers and restore craft bag window 
        -- anchors.
        elseif(newState == SCENE_HIDDEN) then
            CBE.Inventory:StopTransfer() 
            anchorTemplate = ZO_CraftBag:GetName()
        else
            return
        end
        
        --[[ Hacky way to adjust the craft bag window position when guild bank 
             scene is opened/closed.
		     Probably better to use backpack layout fragments in the future.
		     See EsoUI/ingame/inventory/backpacklayouts.lua for examples. ]]
        ZO_CraftBag:ClearAnchors()
        for i=0,1 do
            local anchor = anchors[anchorTemplate][i]
            ZO_CraftBag:SetAnchor(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
        end
    end
    
    --[[ Save anchor positions for the guild bank and craft bag windows for use
         on open/close events. ]]
	local windowAnchorsToSave = { ZO_GuildBank, ZO_CraftBag }
	for i,window in pairs(windowAnchorsToSave) do
		local windowAnchors = {}
		for j=0,1 do
			local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = window:GetAnchor(j)
			windowAnchors[j] = {
				point = point,
				relativeTo = relativeTo,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,    
			}
			anchors[window:GetName()] = windowAnchors
		end
	end
    SCENE_MANAGER.scenes["guildBank"]:RegisterCallback("StateChange",  OnGuildBankSceneStateChange)
    
    --[[ Wire up original guild bank buttons for tab changed event. ]]
	local buttons = ZO_GuildBankMenuBar.m_object.m_buttons
	for i, button in ipairs(buttons) do
		local buttonData = button[1].m_object.m_buttonData
		local callback = buttonData.callback
		buttonData.callback = function(...)
			OnGuildBankTabChanged(...)
			callback(...)
		end
	end
	
    --[[ Create craft bag button. ]]
	CBE:AddCraftBagButton(ZO_GuildBankMenuBar, 
		function (buttonData, playerDriven)
		
			-- Update the menu label to say "Craft Items"
			ZO_GuildBankMenuBarLabel:SetText(GetString(SI_INVENTORY_MODE_CRAFT_BAG))
			
			-- Tab changed callback
			OnGuildBankTabChanged(buttonData, playerDriven)
			
			-- Remove Deposit/withdraw keybind button when on craft bag tab
			local secondaryKeybindDescriptor = 
				KEYBIND_STRIP.keybinds["UI_SHORTCUT_SECONDARY"].keybindButtonDescriptor
			KEYBIND_STRIP:RemoveKeybindButton(secondaryKeybindDescriptor)
		end)
	
	
    --[[ When listening for a guild bank slot updated, handle any guild bank 
         alerts that get raised by stopping the transfer. ]]
    local guildBankMessages = {
		[GetString(SI_GUILDBANKRESULT2)]  = true,
		[GetString(SI_GUILDBANKRESULT3)]  = true,
		[GetString(SI_GUILDBANKRESULT4)]  = true,
		[GetString(SI_GUILDBANKRESULT5)]  = true,
		[GetString(SI_GUILDBANKRESULT6)]  = true,
		[GetString(SI_GUILDBANKRESULT7)]  = true,
		[GetString(SI_GUILDBANKRESULT8)]  = true,
		[GetString(SI_GUILDBANKRESULT9)]  = true,
		[GetString(SI_GUILDBANKRESULT10)] = true,
		[GetString(SI_GUILDBANKRESULT11)] = true,
		[GetString(SI_GUILDBANKRESULT12)] = true,
		[GetString(SI_GUILDBANKRESULT13)] = true,
		[GetString(SI_GUILDBANKRESULT14)] = true,
		[GetString(SI_GUILDBANKRESULT15)] = true,
		[GetString(SI_GUILDBANKRESULT16)] = true,
		[GetString(SI_GUILDBANKRESULT17)] = true,
		[GetString(SI_GUILDBANKRESULT18)] = true,
    }
	local function OnBankTransferFailed(category, soundId, message, ...)
		if not me.bankTransfer then return end
		
		if guildBankMessages[message] then
			me:StopWaitingForBank()
		end
	end
    ZO_PreHook("ZO_Alert", OnBankTransferFailed)
end

--[[ Handles bank item slot update events thrown from a "Deposit" action. ]]
local function OnBankSlotUpdated(eventCode, slotId)

	if not me.bankTransfer then 
		CBE:Debug("Not waiting for transfer")
		return 
	end
	
	-- Double check that the item matches what we are waiting for. I can't 
	-- imagine it would ever be different, but it's best to make sure.
	local backpackItemLink = GetItemLink(BAG_GUILDBANK, slotId)
	local backpackItemId
	_, _, _, backpackItemId = ZO_LinkHandler_ParseLink( backpackItemLink )
	local waitingForItemId
	_, _, _, waitingForItemId = ZO_LinkHandler_ParseLink( me.bankTransfer.itemLink )
	if backpackItemId ~= waitingForItemId then 
		CBE:Debug("item id mismatch")
		return 
	end
	
	me:StopWaitingForBank()
	
	-- Update the craft bag tooltip
	PLAYER_INVENTORY:UpdateList(INVENTORY_CRAFT_BAG, true)
end

local function StartWaitingForBank(bag, slotIndex, targetBag)

	local itemLink = GetItemLink(bag, slotIndex)
	me.bankTransfer = { itemLink = itemLink, targetBag = targetBag }
	
	-- Listen for bank slot updates
	EVENT_MANAGER:RegisterForEvent(me.name, EVENT_GUILD_BANK_ITEM_ADDED, OnBankSlotUpdated)
end

--[[ Checks to ensure that there is a free inventory slot available in both the
     backpack and in the guild bank. If there is, returns true.  If not, an 
     alert is raised and returns false. ]]
local function ValidateFreeSlots(bag, slotIndex)
    if bag ~= BAG_VIRTUAL then return false end
    
    -- Don't transfer if you don't have enough free slots in the guild bank
    if GetNumBagFreeSlots(BAG_GUILDBANK) < 1 then
        ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_SPACE_LEFT)
        return false
    end
    
    -- Don't transfer if you don't have a free proxy slot in your backpack
    if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then
        ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
        return false
    end
    
    return true
end

--[[ Cancels any outstanding guild bank slot update event observers ]]
function CBE_GuildBankController:StopWaitingForBank()

	-- Stop listening for bank slot update events
	-- Unregister pending callback information
	me.bankTransfer = nil
	
	-- Stop listening for bank slot update events that would trigger a callback
	EVENT_MANAGER:UnregisterForEvent(me.name, EVENT_GUILD_BANK_ITEM_ADDED)
end

--[[ Adds guildbank-specific inventory slot crafting bag actions ]]
function CBE_GuildBankController:AddSlotActions()

	local slotInfo = CBE.Inventory.slotInfo

	-- Only add these actions when the guild bank screen is open on the craft bag tab
    if GetInteractionType() ~= INTERACTION_GUILDBANK 
       or not GetSelectedGuildBankId() 
       or slotInfo.slotType ~= SLOT_TYPE_CRAFT_BAG_ITEM then 
		return 
	end
	local inventorySlot = slotInfo.inventorySlot
	local bag = slotInfo.bag
	local slotIndex = slotInfo.slotIndex
	
	--[[ Deposit ]]--
	slotInfo.slotActions:AddSlotAction(
		SI_BANK_DEPOSIT,  
		function() 
			if not ValidateFreeSlots(bag, slotIndex) then return end
    
			local backpackSlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
			local stackSize, maxStackSize = GetSlotStackSize(bag, slotIndex)
			local quantity = math.min(stackSize, maxStackSize)
			
			if IsProtectedFunction("RequestMoveItem") then
				CallSecureProtected("RequestMoveItem", bag, slotIndex, BAG_BACKPACK, backpackSlotIndex, quantity)
			else
				RequestMoveItem(bag, slotIndex, BAG_BACKPACK, backpackSlotIndex, quantity)
			end
			
			-- Listen for guild bank slot updates
			StartWaitingForBank(BAG_BACKPACK, backpackSlotIndex, BAG_GUILDBANK)
			
			TransferToGuildBank(BAG_BACKPACK, backpackSlotIndex)
		end,
		"primary"
	)
	
	--[[ Retrieve and Deposit ]]--
	local actionName = SI_CBE_CRAFTBAG_BANK_DEPOSIT
	slotInfo.slotActions:AddSlotAction(
		actionName,  
		function()
		
			if not ValidateFreeSlots(bag, slotIndex) then return end
			
			CBE.Inventory:StartTransfer(inventorySlot, actionName, SI_ITEM_ACTION_BANK_DEPOSIT,
				function()
					local info = CBE.Inventory.waitingForTransfer
					if not info then return end
			
					-- Listen for guild bank slot updates
					StartWaitingForBank(info.targetBag, info.targetSlotIndex, BAG_GUILDBANK)
					
					TransferToGuildBank(info.targetBag, info.targetSlotIndex)
				end
			)
		end	,
		"keybind1"
	)
end
