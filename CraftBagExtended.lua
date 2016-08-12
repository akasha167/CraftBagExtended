CraftBagExtended = {
    name      = "CraftBagExtended",
    title     = GetString(SI_CBE),
    author    = "|c99CCEFsilvereyes|r",
    version   = "2.0.0 (alpha)",
    debug     = false,
    constants = {
        QUANTITY_UNSPECIFIED = -1,
    },
    classes = {}
}

local function OnAddonLoaded(event, name)
    local self = CraftBagExtended
    if name ~= self.name then return end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    
    local class = self.classes
    
    self.backpackTransferQueue = 
        class.TransferQueue:New(
            self.name .. "BackpackQueue", 
            BAG_VIRTUAL, 
            BAG_BACKPACK
        )
    
    self.settings  = class.Settings:New()
    
    self.modules = {
        guildBank = class.GuildBank:New(),
        mail      = class.Mail:New(),
        trade     = class.Trade:New(),
    }
    
    self:InitializeHooks()
    
end
EVENT_MANAGER:RegisterForEvent(CraftBagExtended.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


--[[ Opens the "Retrieve" from craft bag dialog with a custom action name for
     the transfer button.  Automatically runs a given callback once the transfer
     is complete. ]]
function CraftBagExtended:RetrieveDialog(craftBagIndex, dialogTitle, buttonText, callback)
    
    -- Start listening for backpack slot update events
    local transferItem = 
        self.backpackTransferQueue:StartWaitingForTransfer(
            craftBagIndex, 
            callback, 
            self.constants.QUANTITY_UNSPECIFIED
        )
    if not transferItem then return end
    
    -- Override the text of the transfer dialog's title and/or button
    local transferDialogInfo = self.utility.GetRetrieveDialogInfo()
    
    self.transferDialogItem = transferItem
    
    if dialogTitle then
        transferDialogInfo.title.text = dialogTitle
    end
    if buttonText then
        transferDialogInfo.buttons[1].text = buttonText
    end
    
    -- Open the transfer dialog
    local transferDialog = SYSTEMS:GetObject("ItemTransferDialog")
    transferDialog:StartTransfer(BAG_VIRTUAL, craftBagIndex, BAG_BACKPACK)
end

--[[ Moves an item at the given bag and slot index into the craft bag. ]]
function CraftBagExtended:TransferToCraftBag(bag, slotIndex)
    
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
    
    self.utility.Debug("Transferring "..tostring(quantity).." "..inventoryLink.." to craft bag slot "..tostring(targetSlotIndex))
    
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", bag, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    else
        RequestMoveItem(bag, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    end
end

