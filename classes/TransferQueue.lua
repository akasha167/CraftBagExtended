local cbe           = CraftBagExtended
local util          = cbe.utility
local class         = cbe.classes
class.TransferQueue = ZO_Object:Subclass()

function class.TransferQueue:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

function class.TransferQueue:Initialize(name, sourceBag, targetBag)

    self.name      = name or cbe.name .. "TransferQueue"
    self.sourceBag = sourceBag or BAG_VIRTUAL
    self.targetBag = targetBag or BAG_BACKPACK
    self:Clear()
end

function class.TransferQueue:Clear()
    self.itemCount = 0
    self.items = {}
end

function class.TransferQueue:GetKey(itemId, quantity, bag)

    -- Craft bag doesn't have proper stacks, so don't bother matching by quantity
    if bag == BAG_VIRTUAL then
        return tostring(itemId)
    end
    
    -- Everything else, match by id and quantity
    return tostring(itemId).."-"..tostring(quantity)
end

function class.TransferQueue:SetQuantity(transferItem, quantity)
    local oldKey = self:GetKey(transferItem.itemId, transferItem.quantity)
    
    if not self.items[oldKey] or #(self.items[oldKey]) == 0 then
        util.Debug(self.name..": failed to find entry with key "..oldKey.." when setting quantity to "..tostring(quantity))
        return
    end
    
    local newKey = self:GetKey(transferItem.itemId, quantity)
    if not self.items[newKey] then
        self.items[newKey] = {}
    end
    transferItem.quantity = quantity
    local item = table.insert(self.items[newKey], table.remove(self.items[oldKey]))
    if #self.items[oldKey] == 0 then
        self.items[oldKey] = nil
    end
    return item
end

function class.TransferQueue:Dequeue(bag, slotIndex, quantity)

    if quantity == nil then
        if slotIndex == nil 
           or slotIndex == cbe.constants.QUANTITY_UNSPECIFIED 
        then
            quantity = slotIndex
            slotIndex = bag
            bag = self.targetBag
        end
    end
    
    if self.trade then
        local _
        bag, slotIndex = GetTradeItemBagAndSlot(bag, slotIndex)
    end
    
    local itemLink = GetItemLink(bag, slotIndex)
    local itemId
    _, _, _, itemId = ZO_LinkHandler_ParseLink( itemLink )
    
    if not quantity and bag ~= BAG_VIRTUAL then
        local stackSize, maxStackSize = GetSlotStackSize(bag, slotIndex)
        quantity = math.min(stackSize, maxStackSize)
    end
    
    local key = self:GetKey(itemId, quantity, bag)
    if not self.items[key] then
        util.Debug(self.name..": dequeue failed for "..itemLink.." id "..tostring(itemId).." bag "..tostring(bag).." slot "..tostring(slotIndex).." qty "..tostring(quantity))
        return nil
    end
    
    util.Debug(self.name..": dequeue succeeded for "..itemLink.." id "..tostring(itemId).." bag "..tostring(bag).." slot "..tostring(slotIndex).." qty "..tostring(quantity))
    self.itemCount = self.itemCount - 1
    local item = table.remove(self.items[key])
    if #self.items[key] == 0 then
        self.items[key] = nil
    end
    return item
end

function class.TransferQueue:Enqueue(slotIndex, quantity, callback)
    
    local item = class.TransferItem:New(self, slotIndex, quantity, callback)
    
    local key = self:GetKey(item.itemId, item.quantity, self.targetBag)
    if not self.items[key] then
        self.items[key] = {}
    end
    
    table.insert(self.items[key], item)
    self.itemCount = self.itemCount + 1
    
    if not self.name then
        d("self.name is nil")
    elseif not item.itemLink then
        d("item.itemLink is nil")
    end
    util.Debug(self.name..": enqueue succeeded for "..item.itemLink.." id "..tostring(item.itemId).." bag "..tostring(self.sourceBag).." slot "..tostring(slotIndex).." qty "..tostring(item.quantity))
    return item
end

function class.TransferQueue:HasItems()
    return self.itemCount > 0
end

--[[ Registers a new transfer item and callback for slot updates for the 
     item originating at the given index in the source bag. ]]
function class.TransferQueue:StartWaitingForTransfer(index, callback, quantity)
    
    -- Validate that there is a free slot in the backpack to receive the stack
    if GetNumBagFreeSlots(self.targetBag) < 1 then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
        return
    end
    -- Register callback information
    if not callback then
        util.Debug("null callback encountered for bag "..tostring(self.sourceBag).." slot "..tostring(index).." qty "..tostring(quantity))
    end
    local transferItem = self:Enqueue(index, quantity, callback)
    
    return transferItem
end