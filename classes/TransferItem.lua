local cbe   = CraftBagExtended
local util  = cbe.utility
local class = cbe.classes
class.TransferItem = ZO_Object:Subclass()

local name = cbe.name .. "TransferItem"
local debug = false

function class.TransferItem:New(...)
    local instance = ZO_Object.New(self)
    instance:Initialize(...)
    return instance
end

function class.TransferItem:Initialize(queue, slotIndex, quantity, callback)

    local itemLink, itemId = util.GetItemLinkAndId(queue.sourceBag, slotIndex)
    if not quantity then
        local stackSize, maxStackSize = GetSlotStackSize(queue.sourceBag, slotIndex)
        quantity = math.min(stackSize, maxStackSize)
        local scope = util.GetTransferItemScope(queue.targetBag)
        local default = cbe.settings:GetTransferDefault(scope, itemId)
        if default then
            quantity = math.min(quantity, default)
        end
    end
    
    self.queue = queue
    self.bag = queue.sourceBag
    self.slotIndex = slotIndex
    self.itemId = itemId
    self.itemLink = itemLink
    self.quantity = quantity
    self.targetBag = queue.targetBag
    self.callback = callback
    if cbe.noAutoReturn then
        self.noAutoReturn = cbe.noAutoReturn
        cbe.noAutoReturn = nil
    end
end

--[[ Performs the next configured callback, and clears it so that it doesn't
     run again, setting the targetSlotIndex and passing any additional params.
     If self.callback is a table with multiple entries, the first entry is popped
     and executed. ]]
function class.TransferItem:ExecuteCallback(targetSlotIndex, ...)
    if not self.callback then return end
    
    -- If multiple callbacks are specified, pop the first one off
    local callback
    if type(self.callback) == "table"  then
        if self.callback[1] then
            callback = table.remove(self.callback, 1)
        else
            callback = nil
        end
    -- Only one callback. Clear it.
    else
        callback = self.callback
        self.callback = nil
    end
    
    -- Raise the callback, if it's a function. Otherwise, ignore.
    if type(callback) == "function" then
        util.Debug("calling callback on bag "..tostring(self.targetBag).." slot "..tostring(targetSlotIndex), debug)
        self.targetSlotIndex = targetSlotIndex
        callback(self, ...)
    else
        util.Debug("callback on bag "..tostring(self.targetBag).." slot "..tostring(targetSlotIndex).." was not a function. it was a "..type(callback), debug)
    end
end

--[[ Returns true if the current transfer item still has a callback configured. ]]
function class.TransferItem:HasCallback()
    return (type(self.callback) == "table" and self.callback[1])
           or type(self.callback) == "function"
end

--[[ Undoes a previous enqueue operation for this item ]]
function class.TransferItem:Dequeue()
    local key = self:GetKey(self.itemId, self.quantity, self.bag)
    self:RemoveKey(key)
end

--[[ Queues the same transfer item up again to be handled by another server 
     event. If targetBag is supplied, then the item is queued for transfer to 
     the new bag.  Otherwise, the item is added to its original queue. ]]
function class.TransferItem:Requeue(targetBag)
    -- If queuing a transfer to a new bag, get the new transfer queue and queue
    -- up a new transfer item.
    if targetBag and targetBag ~= self.targetBag then
        local transferQueue = util.GetTransferQueue(self.targetBag, targetBag)
        transferQueue:Enqueue(self.targetSlotIndex, self.quantity, self.callback)
        
    -- If queuing a non-transfer for temporary data storage between events, just
    -- add this item back to the queue.
    else
        self.queue:AddItem(self)
    end
    
end