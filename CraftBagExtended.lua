local addon = {
	name = "CraftBagExtended",
	title = GetString(SI_CBE),
	author = "|c99CCEFsilvereyes|r",
	version = "1.0.0",
	guildBankFragments = {
		[SI_BANK_WITHDRAW] = { GUILD_BANK_FRAGMENT },
		[SI_BANK_DEPOSIT]  = { INVENTORY_FRAGMENT, BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT },
		[SI_INVENTORY_MODE_CRAFT_BAG] = { CRAFT_BAG_FRAGMENT },
	},
	anchors = { }
}

-- Output formatted message to chat window, if configured
local function pOutput(input)
	local output = zo_strformat("<<1>>|cFFFFFF: <<2>>|r", addon.title, input)
	d(output)
end

local function SwitchScene(oldScene, newScene) 
	local removeFragments = addon.guildBankFragments[oldScene]
	for i,removeFragment in pairs(removeFragments) do
		SCENE_MANAGER:RemoveFragment(removeFragment)
	end
	
	if newScene == SI_INVENTORY_MODE_CRAFT_BAG then
        ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
	elseif oldScene == SI_INVENTORY_MODE_CRAFT_BAG then
        ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
	end
	
	local addFragments = addon.guildBankFragments[newScene]
	for i,addFragment in pairs(addFragments) do
		SCENE_MANAGER:AddFragment(addFragment)
	end
end

local function OnGuildBankTabChanged(buttonData, playerDriven)

	-- If the scene is in the process of showing still, no switch is needed
	local guildBankSceneState = SCENE_MANAGER.scenes["guildBank"].state
	if guildBankSceneState == SCENE_SHOWING then 
		addon.lastButtonName = buttonData.descriptor
		return 
	end
	
	if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG or addon.lastButtonName == SI_INVENTORY_MODE_CRAFT_BAG then
		SwitchScene(addon.lastButtonName, buttonData.descriptor)
	end
	
	addon.lastButtonName = buttonData.descriptor
end

local function OnGuildBankSceneStateChange(oldState, newState)
	local anchorTemplate
	if(newState == SCENE_SHOWING) then
		anchorTemplate = ZO_GuildBank:GetName()
	elseif(newState == SCENE_HIDDEN) then
		anchorTemplate = ZO_CraftBag:GetName()
	else
		return
	end
	ZO_CraftBag:ClearAnchors()
	for i=0,1 do
		local anchor = addon.anchors[anchorTemplate][i]
		ZO_CraftBag:SetAnchor(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
	end
end

local function RegisterAnchors() 
    local windowAnchorsToSave = { ZO_GuildBank, ZO_CraftBag }
    for i,window in pairs(windowAnchorsToSave) do
		local anchors = {}
		for j=0,1 do
			local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = window:GetAnchor(j)
			anchors[j] = {
				point = point,
				relativeTo = relativeTo,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,	
			}
			addon.anchors[window:GetName()] = anchors
		end
    end
end

local function OnCraftBagButtonClicked(buttonData, playerDriven)
	ZO_GuildBankMenuBarLabel:SetText(GetString(SI_INVENTORY_MODE_CRAFT_BAG))
	OnGuildBankTabChanged(buttonData, playerDriven)
	
	-- Remove Deposit/withdraw keybind button when on craft bag tab
	local keybindDescriptor = KEYBIND_STRIP.keybinds["UI_SHORTCUT_SECONDARY"].keybindButtonDescriptor
	KEYBIND_STRIP:RemoveKeybindButton(keybindDescriptor)
end

local function SetupButtons()
	local buttons = ZO_GuildBankMenuBar.m_object.m_buttons
	
	-- Wire up original guild bank buttons for tab changed event
	for i, button in ipairs(buttons) do
		local buttonData = button[1].m_object.m_buttonData
		local callback = buttonData.callback
		buttonData.callback = function(...)
			OnGuildBankTabChanged(...)
			callback(...)
		end
	end
	
	-- Create craft bag button
	local name = SI_INVENTORY_MODE_CRAFT_BAG
	ZO_MenuBar_AddButton(
		ZO_GuildBankMenuBar, 
		{
            normal = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_up.dds",
            pressed = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_down.dds",
            highlight = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_over.dds",
            descriptor = name,
            categoryName = name,
            callback = OnCraftBagButtonClicked,
            CustomTooltipFunction = function(...) ZO_InventoryMenuBar:LayoutCraftBagTooltip(...) end,
            statusIcon = function()
				if SHARED_INVENTORY and SHARED_INVENTORY:AreAnyItemsNew(nil, nil, BAG_VIRTUAL) then
					return ZO_KEYBOARD_NEW_ICON
				end
				return nil
			end
        })
end

local function TryTransferToBank(slotControl)

	local iBagId, iSlotIndex = ZO_Inventory_GetBagAndIndex(slotControl)
	
	-- Don't transfer if you don't have enough free slots in the guild bank
	if GetNumBagFreeSlots(BAG_GUILDBANK) < 1 then
		ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_SPACE_LEFT)
		return
	end
	
	-- Transfers from the crafting bag need to get put in a real stack in the 
	-- backpack first to avoid "Item no longer exists" errors
	if iBagId == BAG_VIRTUAL then
		-- Don't transfer if you don't have a free proxy slot in your backpack
		if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then
			ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
			return
		end
		local iProxySlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
		local iStackSize, iMaxStackSize = GetSlotStackSize(iBagId, iSlotIndex)
		local iQuantity = math.min(iStackSize, iMaxStackSize)
		
		if IsProtectedFunction("RequestMoveItem") then
			CallSecureProtected("RequestMoveItem", iBagId, iSlotIndex, BAG_BACKPACK, iProxySlotIndex, iQuantity)
		else
			RequestMoveItem(iBagId, iSlotIndex, BAG_BACKPACK, iProxySlotIndex, iQuantity)
		end
		iBagId = BAG_BACKPACK
		iSlotIndex = iProxySlotIndex
	end
	
	TransferToGuildBank(iBagId, iSlotIndex)
end

local function OnAddonLoaded(event, name)
	if name ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
    
    -- Save the original anchors
    RegisterAnchors()

	-- Wire up guild bank scene open/close events to adjust craft bag anchors
	local guildBankScene = SCENE_MANAGER.scenes["guildBank"]
    guildBankScene:RegisterCallback("StateChange",  OnGuildBankSceneStateChange)
	
	-- Wire up original guild bank buttons for tab changed event, and add new craft bag button
	SetupButtons()
	
	local addSlotAction = ZO_InventorySlotActions.AddSlotAction

    local slotControl
    ZO_PreHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions) slotControl = inventorySlot end)
    ZO_InventorySlotActions.AddSlotAction = function(slotActions, stringId, callback, type, visible, options)
        if(stringId == SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG and GetInteractionType() == INTERACTION_GUILDBANK) then
			stringId = SI_ITEM_ACTION_BANK_DEPOSIT
			callback = function() TryTransferToBank(slotControl) end
            type = "primary"
        end
        addSlotAction(slotActions, stringId, callback, type, visible, options)
    end
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

CBE = addon
