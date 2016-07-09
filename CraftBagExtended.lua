local addon = {
	name = "CraftBagExtended",
	title = GetString(SI_CBE),
	author = "|c99CCEFsilvereyes|r",
	version = "1.0.0",
	defaults =
	{
		disableConfirmationDialog = true
	}
}

-- TODO
-- ZO_CraftBagAutoTransferProvider
-- 
-- Output formatted message to chat window, if configured
local function pOutput(input)
	local output = zo_strformat("<<1>>|cFFFFFF: <<2>>|r", addon.title, input)
	d(output)
end

function addon.RetrieveAll()
	pOutput("RetrieveAll")
	local data = ZO_CraftBagList1Row1.dataEntry.data
	while data and data.bagId and data.slotIndex do
		local emptySlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
		if(emptySlotIndex == nil) then
			ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
			return
		end
		local stackSize, maxStackSize = GetSlotStackSize(data.bagId, data.slotIndex)
        if stackSize >= maxStackSize then
            stackSize = maxStackSize
        end
        if not CallSecureProtected("PickupInventoryItem", data.bagId, data.slotIndex, stackSize) then
			pOutput("ERROR: cannot call secure method PickupInventoryItem")
			break
        end
        if not CallSecureProtected("TryPlaceInventoryItemInEmptySlot", BAG_BACKPACK) then
			pOutput("ERROR: cannot call secure method TryPlaceInventoryItemInEmptySlot")
			break
        end
        --local dialog = SYSTEMS:GetObject("ItemTransferDialog")
        --dialog.bag = data.bagId
        --dialog.slotIndex = data.slotIndex
        --dialog:Refresh()
        --dialog:Transfer(stackSize)
    end
end

function addon:AddKeyBind()
	self.retrieveAllKeybindButtonGroup = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{
			name = "Retrieve All From Craft Bag",
			keybind = "CRAFT_BAG_RETRIEVE_ALL",
			enabled = function() return addon.running ~= true end,
			visible = function() return true end,
			order = 100,
			callback = addon.RetrieveAll,
		},
	}
	CRAFT_BAG_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWN then
			KEYBIND_STRIP:AddKeybindButtonGroup(addon.retrieveAllKeybindButtonGroup)
		elseif newState == SCENE_HIDING then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(addon.retrieveAllKeybindButtonGroup)
		end
	end )
end



----------------- Settings -----------------------
function addon:SetupSettings()
	local LAM2 = LibStub("LibAddonMenu-2.0")
	if not LAM2 then return end

	local panelData = {
		type = "panel",
		name = addon.title,
		displayName = addon.title,
		author = addon.author,
		version = addon.version,
		slashCommand = "/craftbag",
		-- registerForRefresh = true,
		registerForDefaults = true,
	}
	LAM2:RegisterAddonPanel(addon.name, panelData)

	local optionsTable = {
		{
			type = "checkbox",
			name = GetString(SI_CBE_DISABLE_CONFIRMATION),
			tooltip = GetString(SI_CBE_DISABLE_CONFIRMATION_TOOLTIP),
			getFunc = function() return addon.settings.disableConfirmationDialog end,
			setFunc = function(value) addon.settings.disableConfirmationDialog = value end,
			default = self.defaults.disableConfirmationDialog,
		},
	}
	LAM2:RegisterOptionControls(addon.name, optionsTable)
end

--------------- End Settings ---------------------


local function OnAddonLoaded(event, name)
	if name ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.settings = ZO_SavedVars:NewAccountWide("CraftBagExtended_Data", 1, nil, addon.defaults)

	addon:AddKeyBind()
	addon:SetupSettings()
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

CBE = addon
