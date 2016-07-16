CBE_TransferQueue = ZO_Object:Subclass()
CBE_QUANTITY_UNSPECIFIED = -1

function CBE_TransferQueue:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

function CBE_TransferQueue:Initialize(name)

    self.name = name or "CBE_TransferQueue"
    self:Clear()
end

function CBE_TransferQueue:Clear()
    self.itemCount = 0
    self.items = {}
end

function CBE_TransferQueue:GetKey(itemId, quantity, bag)

    -- Craft bag doesn't have proper stacks, so don't bother matching by quantity
    if bag == BAG_VIRTUAL then
        return tostring(itemId)
    end
    
    -- Everything else, match by id and quantity
    return tostring(itemId).."-"..tostring(quantity)
end

function CBE_TransferQueue:SetQuantity(transferItem, quantity)
    local oldKey = self:GetKey(transferItem.itemId, transferItem.quantity)
    
    if not self.items[oldKey] or #(self.items[oldKey]) == 0 then
        CBE:Debug(self.name..": failed to find entry with key "..oldKey.." when setting quantity to "..tostring(quantity))
        return
    end
    
    local newKey = self:GetKey(transferItem.itemId, quantity)
    if not self.items[newKey] then
        self.items[newKey] = {}
    end
    transferItem.quantity = quantity
    return table.insert(self.items[newKey], table.remove(self.items[oldKey]))
end

function CBE_TransferQueue:Dequeue(bag, slotIndex, quantity)

    local itemLink = GetItemLink(bag, slotIndex)
    local itemId
    _, _, _, itemId = ZO_LinkHandler_ParseLink( itemLink )
    
    if not quantity and bag ~= BAG_VIRTUAL then
        local stackSize, maxStackSize = GetSlotStackSize(bag, slotIndex)
        quantity = math.min(stackSize, maxStackSize)
    end
    
    local key = self:GetKey(itemId, quantity, bag)
    if not self.items[key] then
        CBE:Debug(self.name..": dequeue failed for "..itemLink.." id "..tostring(itemId).." bag "..tostring(bag).." slot "..tostring(slotIndex).." qty "..tostring(quantity))
        return nil
    end
    
    CBE:Debug(self.name..": dequeue succeeded for "..itemLink.." id "..tostring(itemId).." bag "..tostring(bag).." slot "..tostring(slotIndex).." qty "..tostring(quantity))
    self.itemCount = self.itemCount - 1
    return table.remove(self.items[key])
end

function CBE_TransferQueue:Enqueue(bag, slotIndex, quantity, targetBag, callback)
    local itemLink = GetItemLink(bag, slotIndex)
    local itemId
    _, _, _, itemId = ZO_LinkHandler_ParseLink( itemLink )
    if not quantity then
        local stackSize, maxStackSize = GetSlotStackSize(bag, slotIndex)
        quantity = math.min(stackSize, maxStackSize)
    end
    
    local item = { 
        bag       = bag,
        slotIndex = slotIndex,
        itemId    = itemId,
        itemLink  = itemLink,
        quantity  = quantity,
        targetBag = targetBag,
        callback  = callback
    }
    if not item.callback and bag==BAG_VIRTUAL then
        CBE:Debug(self.name..": null callback passed to enqueue for bag "..tostring(bag).." slot "..tostring(slotIndex).." qty "..tostring(quantity))
    end
    
    local key = self:GetKey(itemId, quantity, targetBag)
    if not self.items[key] then
        self.items[key] = {}
    end
    
    table.insert(self.items[key], item)
    self.itemCount = self.itemCount + 1
    
    CBE:Debug(self.name..": enqueue succeeded for "..itemLink.." id "..tostring(itemId).." bag "..tostring(bag).." slot "..tostring(slotIndex).." qty "..tostring(quantity))
    return item
end
function CBE_TransferQueue:HasItems()
    return self.itemCount > 0
end