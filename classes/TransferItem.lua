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

    local itemLink = GetItemLink(queue.sourceBag, slotIndex)
    local itemId
    _, _, _, itemId = ZO_LinkHandler_ParseLink( itemLink )
    if not quantity then
        local stackSize, maxStackSize = GetSlotStackSize(queue.sourceBag, slotIndex)
        quantity = math.min(stackSize, maxStackSize)
    end
    
    self.queue = queue
    self.bag = queue.sourceBag
    self.slotIndex = slotIndex
    self.itemId = itemId
    self.itemLink = itemLink
    self.quantity = quantity
    self.targetBag = queue.targetBag
    self.callback = callback
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
    
    -- Raise the callback.  It should never be nil or a nonfunction, 
    -- but check just in case
    if type(callback) == "function" then
        util.Debug("calling callback on bag "..tostring(self.targetBag).." slot "..tostring(targetSlotIndex), self.debug)
        self.targetSlotIndex = targetSlotIndex
        callback(self, ...)
    else
        util.Debug("callback on bag "..tostring(self.targetBag).." slot "..tostring(targetSlotIndex).." was not a function. it was a "..type(callback), self.debug)
    end
end

--[[ Returns true if the current transfer item still has a callback configured. ]]
function class.TransferItem:HasCallback()
    return (type(self.callback) == "table" and self.callback[1])
           or type(self.callback) == "function"
end