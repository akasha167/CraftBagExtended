local cbe       = CraftBagExtended
local util      = cbe.utility
local class     = cbe.classes
local name      = cbe.name .. "Inventory"
class.Inventory = class.Module:Subclass()

function class.Inventory:New(...)        
    local instance = class.Module.New(self, name, "inventory")
    instance:Setup()
    return instance
end

function class.Inventory:Setup()
    self.debug = false
    self.retrieveQueue = util.GetTransferQueue( BAG_VIRTUAL, BAG_BACKPACK )
    self.stowQueue = util.GetTransferQueue( BAG_BACKPACK, BAG_VIRTUAL )
end

--[[ Adds normal inventory screen crafting bag slot actions ]]
function class.Inventory:AddSlotActions(slotInfo)
    local slotIndex = slotInfo.slotIndex
    local isShown = self:IsSceneShown()
    if slotInfo.bag == BAG_BACKPACK and HasCraftBagAccess() 
       and CanItemBeVirtual(slotInfo.bag, slotIndex) 
       and not IsItemStolen(slotInfo.bag, slotIndex)
       and not slotInfo.slotData.locked
       and slotInfo.slotType == SLOT_TYPE_ITEM
    then
        
        --[[ Stow ]]--
        table.insert(slotInfo.slotActions, {
            SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG,  
            function() cbe:Stow(slotIndex) end,
            (isShown and "primary") or "secondary"
        })
        --[[ Stow quantity ]]--
        table.insert(slotInfo.slotActions, {
            SI_CBE_CRAFTBAG_STOW_QUANTITY,  
            function() cbe:StowDialog(slotIndex) end,
            (isShown and "keybind1") or "secondary"
        })
        
    elseif slotInfo.bag == BAG_VIRTUAL then
        
        --[[ Retrieve ]]--
        table.insert(slotInfo.slotActions, {
            SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG,  
            function()
                cbe.noAutoReturn = true
                cbe:Retrieve(slotIndex) 
            end,
            (isShown and "primary") or "secondary"
        })
        --[[ Retrieve quantity ]]--
        table.insert(slotInfo.slotActions, {
            SI_CBE_CRAFTBAG_RETRIEVE_QUANTITY,  
            function() 
                cbe.noAutoReturn = true
                cbe:RetrieveDialog(slotIndex)
            end,
            (isShown and "keybind1") or "secondary"
        })

    end
end

--[[ Moves a given quantity from the given craft bag inventory slot index into 
     the backpack without a dialog prompt.  
     If quantity is nil, then the max stack is moved. If a callback function 
     is specified, it will be called when the mats arrive in the backpack. ]]
function class.Inventory:Retrieve(slotIndex, quantity, callback)
    return util.TransferItemToBag(BAG_VIRTUAL, slotIndex, BAG_BACKPACK, quantity, callback)
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