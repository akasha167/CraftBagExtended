local cbe       = CraftBagExtended
local util      = cbe.utility
local class     = cbe.classes
local name      = cbe.name .. "Inventory"
class.Inventory = ZO_Object:Subclass()

function class.Inventory:New(...)        
    local instance = ZO_Object.New(self)
    instance:Initialize()
    return instance
end

function class.Inventory:Initialize()

    self.name = name
    self.debug = false
    self.retrieveQueue = util.GetTransferQueue( BAG_VIRTUAL, BAG_BACKPACK )
    self.stowQueue = util.GetTransferQueue( BAG_BACKPACK, BAG_VIRTUAL )
end

local function ValidateSlotAvailable()
    local backpackSlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
    if backpackSlotIndex then
        return backpackSlotIndex
    else
        ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
    end
end

--[[ Adds normal inventory screen crafting bag slot actions ]]
function class.Inventory:AddSlotActions(slotInfo)
    
end

--[[ Moves a given quantity from the given craft bag inventory slot index into 
     the backpack without a dialog prompt.  
     If quantity is nil, then the max stack is moved. If a callback function 
     is specified, it will be called when the mats arrive in the backpack. ]]
function class.Inventory:Retrieve(slotIndex, quantity, callback)
    
    -- Find the first free slot in the backpack
    local backpackSlotIndex = ValidateSlotAvailable()
    if not backpackSlotIndex then
        return false
    end
    
    -- Queue up the transfer
    local transferItem = self.retrieveQueue:Enqueue(slotIndex, quantity, callback)
    if not quantity then
        quantity = transferItem.quantity
    end
    
    util.Debug("Retrieving "..tostring(quantity).." from craft bag slotId "..tostring(slotId).." back to backpack slot "..tostring(backpackSlotIndex), self.debug)
    
    -- Initiate the stack move to the backpack
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", BAG_VIRTUAL, slotIndex, BAG_BACKPACK, backpackSlotIndex, quantity)
    else
        RequestMoveItem(BAG_VIRTUAL, slotIndex, BAG_BACKPACK, backpackSlotIndex, quantity)
    end
    
    return true
end

--[[ Moves a given quantity from the given backpack inventory slot index into 
     the craft bag without a dialog prompt.  
     If quantity is nil, then the whole stack is moved. If a callback function 
     is specified, it will be called when the mats arrive in the craft bag. ]]
function class.Inventory:Stow(slotIndex, quantity, callback)
    
    -- Make sure this is a crafting mat
    if not CanItemBeVirtual(BAG_BACKPACK, slotIndex) then
        return false
    end
    
    -- Queue up the transfer
    local transferItem = self.stowQueue:Enqueue(slotIndex, quantity, callback)
    if not quantity then
        quantity = transferItem.quantity
    end
    
    -- Find any existing slots in the craft bag that have the given item already
    local targetSlotIndex = nil
    for currentSlotIndex,slotData in ipairs(PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG].slots) do
        local craftBagLink = GetItemLink(BAG_VIRTUAL, currentSlotIndex)
        if craftBagLink == transferItem.itemLink then
            targetSlotIndex = currentSlotIndex
            break
        end
    end
    
    -- The craft bag didn't have the item yet, so get a new empty slot
    if not targetSlotIndex then
        targetSlotIndex = FindFirstEmptySlotInBag(BAG_VIRTUAL)
    end
    
    util.Debug("Stowing "..tostring(quantity).." "..transferItem.itemLink.." to craft bag slot "..tostring(targetSlotIndex), self.debug)
    
    -- Initiate the stack move to the craft bag
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", BAG_BACKPACK, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    else
        RequestMoveItem(BAG_BACKPACK, slotIndex, BAG_VIRTUAL, targetSlotIndex, quantity)
    end
    
    return true
end

--[[ Opens the "Retrieve" or "Stow" transfer dialog with a custom action name for
     the transfer button.  Automatically runs a given callback once the transfer
     is complete, if specified. ]]
function class.Inventory:TransferDialog(bag, slotIndex, targetBag, dialogTitle, buttonText, callback)
    
    -- Validate that the transfer is legit
    if targetBag == BAG_BACKPACK then
        if not ValidateSlotAvailable() then
            return false
        end
    elseif bag == BAG_BACKPACK and targetBag == BAG_VIRTUAL then
        if not CanItemBeVirtual(BAG_BACKPACK, slotIndex) then
            return false
        end
    else
        return false
    end
    
    -- Override the text of the transfer dialog's title and/or button
    local transferDialogInfo = util.GetRetrieveDialogInfo()
    
    -- Wire up callback
    if type(callback) == "function" or type(callback) == "table" then
        local transferQueue = util.GetTransferQueue( bag, targetBag )
        local transferItem = 
            transferQueue:StartWaitingForTransfer(
                slotIndex, 
                callback, 
                cbe.constants.QUANTITY_UNSPECIFIED
            )
        if not transferItem then return end
        
        -- Do not remove. Used by the dialog finished hooks to properly set the
        -- stack quantity.
        cbe.transferDialogItem = transferItem
    end
    
    if dialogTitle then
        transferDialogInfo.title.text = dialogTitle
    end
    if buttonText then
        transferDialogInfo.buttons[1].text = buttonText
    end
    
    -- Open the transfer dialog
    local transferDialog = SYSTEMS:GetObject("ItemTransferDialog")
    transferDialog:StartTransfer(bag, slotIndex, targetBag)
    
    return true
end