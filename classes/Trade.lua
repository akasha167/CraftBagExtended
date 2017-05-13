local cbe   = CraftBagExtended
local util  = cbe.utility
local class = cbe.classes
class.Trade = class.Module:Subclass()

local name = cbe.name .. "Trade"
local debug = false

function class.Trade:New(...)
    local instance = class.Module.New(self, 
        name, "trade", ZO_Trade, BACKPACK_PLAYER_TRADE_LAYOUT_FRAGMENT)
    instance:Setup(...)
    return instance
end

local function OnTradeCanceled(eventCode)
    for tradeIndex = 1, TRADE_NUM_SLOTS do
        local slotIndex = cbe.tradeSlotMap[tradeIndex]
        if slotIndex then
            cbe.tradeSlotMap[tradeIndex] = nil
            -- Transfer mats back to craft bag
            cbe:Stow(slotIndex)
        end
    end
end

local function OnTradeItemAdded(eventCode, who, tradeIndex, itemSoundCategory)
    if who ~= TRADE_ME then return end
    
    local _, slotIndex = GetTradeItemBagAndSlot(TRADE_ME, tradeIndex)
    if cbe.isAddingToTrade then 
        cbe.tradeSlotMap[tradeIndex] = slotIndex
        cbe.isAddingToTrade = nil
    else
        return 
    end
    local retrieveQueue = util.GetTransferQueue( BAG_VIRTUAL, BAG_BACKPACK )
    local transferItem = retrieveQueue:Dequeue(BAG_BACKPACK, slotIndex)
    
    if transferItem then
        transferItem:ExecuteCallback(slotIndex, tradeIndex)
    end
end

local function OnTradeItemRemoved(eventCode, who, tradeIndex, itemSoundCategory)
    if who ~= TRADE_ME then return end
    local transferItem = cbe.tradeSlotRemovalQueue[tradeIndex]
    local slotIndex = cbe.tradeSlotMap[tradeIndex]
    local callback
    if transferItem then
        callback = transferItem.callback
    elseif not slotIndex then
        return
    end
    
    cbe.tradeSlotRemovalQueue[tradeIndex] = nil
    cbe.tradeSlotMap[tradeIndex] = nil

    -- Clear the keybind strip command
    local inventorySlot = util.GetInventorySlot(BAG_BACKPACK, slotIndex)
    if inventorySlot then
        ZO_InventorySlot_OnMouseExit(inventorySlot)
    end
    
    if transferItem then
        transferItem:ExecuteCallback(tradeIndex, tradeIndex)
    end
    
    -- Transfer mats back to craft bag
    cbe:Stow(slotIndex, nil, callback)
end

function class.Trade:Setup()
    cbe.tradeSlotRemovalQueue = {}
    cbe.tradeSlotMap = {}
    self.menu:SetAnchor(BOTTOMRIGHT, ZO_TradeMyControls, TOPRIGHT, 0, -12)
    -- Listen for bag slot update events so that we can process the callbacks
    EVENT_MANAGER:RegisterForEvent(cbe.name, EVENT_TRADE_CANCELED, OnTradeCanceled)
    EVENT_MANAGER:RegisterForEvent(cbe.name, EVENT_TRADE_FAILED, OnTradeCanceled)
    EVENT_MANAGER:RegisterForEvent(cbe.name, EVENT_TRADE_ITEM_ADDED, OnTradeItemAdded)
    EVENT_MANAGER:RegisterForEvent(cbe.name, EVENT_TRADE_ITEM_REMOVED, OnTradeItemRemoved)
end

--[[ Returns the index of the trade item slot that's bound to a given backpack slot, 
     or nil if it's not in the current trade offer. ]]
local function GetTradeSlotIndex(slotIndex)
    for i = 1, TRADE_NUM_SLOTS do
        local _, tradeItemSlotIndex = GetTradeItemBagAndSlot(TRADE_ME, i)
        if tradeItemSlotIndex and slotIndex == tradeItemSlotIndex then
            return i
        end
    end
end

--[[ Called after an Add to Offer operation successfully retrieves a craft bag item 
     to the backpack. Responsible for executing the "Add to Offer" part of the operation. ]]
local function RetrieveCallback(transferItem)

    if not TRADE_WINDOW:IsTrading() then return end
    
    -- Add the stack to my trade items list
    cbe.isAddingToTrade = true
    TRADE_WINDOW:AddItemToTrade(BAG_BACKPACK, transferItem.targetSlotIndex)
    
    -- If we're still waiting for the item to be added to the trade offer, then
    -- start waiting for it again.
    if transferItem:HasCallback() then
        transferItem.queue:Enqueue(transferItem.slotIndex, transferItem.quantity, transferItem.callback)
    end
end

local function ValidateCanAddToOffer()
    return TRADE_WINDOW:IsTrading() 
           and ZO_SharedTradeWindow.FindMyNextAvailableSlot(ZO_Trade)
end

--[[ Adds mail-specific inventory slot crafting bag actions ]]
function class.Trade:AddSlotActions(slotInfo)
    
    if not TRADE_WINDOW:IsTrading() then return end
    
    --[[ For my trade slots, check the actual entry slot for the fromCraftBag flag]]
    if slotInfo.slotType == SLOT_TYPE_MY_TRADE then
        local inventoryType = PLAYER_INVENTORY.bagToInventoryType[slotInfo.bag]
        local slots = PLAYER_INVENTORY.inventories[inventoryType].slots
        if GetAPIVersion() >= 100019 then
            slots = slots[slotInfo.bag]
        end
        local slot = slots[slotInfo.slotIndex]
        slotInfo.fromCraftBag = slot.fromCraftBag
    end
    
    if ZO_IsItemCurrentlyOfferedForTrade(slotInfo.bag, slotInfo.slotIndex) then
        if slotInfo.fromCraftBag then
            --[[ Remove from Offer ]]
            table.insert(slotInfo.slotActions, {
                SI_ITEM_ACTION_TRADE_REMOVE, 
                function() cbe:TradeRemoveFromOffer(slotInfo.slotIndex) end, 
                "primary"
            })
        end
        
    elseif slotInfo.slotType == SLOT_TYPE_CRAFT_BAG_ITEM
           and ZO_SharedTradeWindow.FindMyNextAvailableSlot(ZO_Trade) 
    then
        --[[ Add to Offer ]]
        table.insert(slotInfo.slotActions, {
            SI_ITEM_ACTION_TRADE_ADD, 
            function() cbe:TradeAddToOffer(slotInfo.slotIndex) end, 
            "primary"
        })
        --[[ Add to Quantity ]]
        table.insert(slotInfo.slotActions, {
            SI_CBE_CRAFTBAG_TRADE_ADD, 
            function() cbe:TradeAddToOfferDialog(slotInfo.slotIndex) end, 
            "keybind3"
        })
    end
end

--[[ Moves a given quantity of a craft bag slot to the backpack and then adds it
     to the current trade offer.
     If quantity is nil, then the max stack is moved.
     Optionally raises callbacks after the stack arrives in the backpack and/or
     after it is added to the trade offer.
     Returns true if the backpack and the trade offer both have slots available.
     Otherwise, returns false. ]]
function class.Trade:AddToOffer(slotIndex, quantity, backpackCallback, addedCallback)
    if not ValidateCanAddToOffer() then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, addedCallback)
    return cbe:Retrieve(slotIndex, quantity, callback)
end

--[[ Opens a retrieve dialog for a given craft bag slot index, 
     and then automatically adds it to the current trade offer.
     Optionally raises callbacks after the stack arrives in the backpack and/or
     after it is added to the trade offer.
     Returns true if the backpack and the trade offer both have slots available.
     Otherwise, returns false. ]]
function class.Trade:AddToOfferDialog(slotIndex, backpackCallback, addedCallback)
    if not ValidateCanAddToOffer() then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, addedCallback)
    cbe:RetrieveDialog(slotIndex, SI_CBE_CRAFTBAG_TRADE_ADD, 
        SI_ITEM_ACTION_TRADE_ADD, callback) 
end

function class.Trade:FilterSlot(inventoryManager, inventory, slot)
    if not TRADE_WINDOW:IsTrading() then 
        return 
    end
    
    -- Exclude untradable slots
    if not TRADE_WINDOW:CanTradeItem(slot) then
        return true
    end
end

--[[ Removes the stack at the given backpack index from the player's trade offer
     and returns the stack to the craft bag.  Optionally raise callbacks after
     the stack is removed from the offer and/or after it is returned to the craft
     bag. Returns true if the slot exists in the trade offer and can be moved
     to the craft bag. Otherwise, returns false. ]]
function class.Trade:RemoveFromOffer(slotIndex, removedCallback, stowedCallback)
    if not TRADE_WINDOW:IsTrading() then return false end
    
    local tradeIndex = GetTradeSlotIndex(slotIndex)
    
    if not tradeIndex then
        return false
    end
    
    local stowQueue = util.GetTransferQueue(BAG_BACKPACK, BAG_VIRTUAL)
    local callback = {}
    table.insert(callback, removedCallback)
    table.insert(callback, stowedCallback)
    cbe.tradeSlotRemovalQueue[tradeIndex] = class.TransferItem:New(stowQueue, slotIndex, nil, callback)
    
    local soundCategory = GetItemSoundCategory(BAG_BACKPACK, slotIndex)
    PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
    TradeRemoveItem(tradeIndex)
    
    return CanItemBeVirtual(BAG_BACKPACK, slotIndex)
end