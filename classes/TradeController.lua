CBE_TradeController = CBE_Controller:Subclass()

local name = "CBE_TradeController"
local debug = false

function CBE_TradeController:New(...)
    local controller = CBE_Controller.New(self, 
        name, "trade", ZO_Trade, BACKPACK_PLAYER_TRADE_LAYOUT_FRAGMENT)
    controller.menu:SetAnchor(BOTTOMRIGHT, ZO_TradeMyControls, TOPRIGHT, 0, -12)
    return controller
end

--[[ Returns the index of the trade item slot that's bound to a given inventory slot, 
     or nil if it's not in the current trade offer. ]]
local function GetTradeSlotIndex(slotInfo)
    if slotInfo.slotType == SLOT_TYPE_MY_TRADE then
        return ZO_Inventory_GetSlotIndex(slotInfo.inventorySlot)
    end
     
    local bag, index = ZO_Inventory_GetBagAndIndex(slotInfo.inventorySlot)
    for i = 1, TRADE_NUM_SLOTS do
        local bagId, slotIndex = GetTradeItemBagAndSlot(TRADE_ME, i)
        if bagId and slotIndex and bagId == bag and slotIndex == index then
            return i
        end
    end
end

--[[ Called after a Retrieve and Add to Offer operation successfully retrieves a craft bag item 
     to the backpack. Responsible for executing the "Add to Offer" part of the operation. ]]
local function OnBackpackTransferComplete(transferItem)

    if not TRADE_WINDOW:IsTrading() then return end
    
    if not transferItem then
        CBE:Debug(name..":OnBackpackTransferComplete did not receive its transferItem parameter", debug)
    end
    
    -- Add the stack to my trade items list
    TRADE_WINDOW:AddItemToTrade(transferItem.targetBag, transferItem.targetSlotIndex)
end

--[[ Adds mail-specific inventory slot crafting bag actions ]]
function CBE_TradeController:AddSlotActions(slotInfo)
    
    if not TRADE_WINDOW:IsTrading() then return end
    
    --[[ For my trade slots, check the actual entry slot for the fromCraftBag flag]]
    if slotInfo.slotType == SLOT_TYPE_MY_TRADE then
        local inventoryType = PLAYER_INVENTORY.bagToInventoryType[slotInfo.bag]
        local slot = PLAYER_INVENTORY.inventories[inventoryType].slots[slotInfo.slotIndex]
        slotInfo.fromCraftBag = slot.fromCraftBag
    end
    
    --[[ Remove and Stow ]]
    if ZO_IsItemCurrentlyOfferedForTrade(slotInfo.bag, slotInfo.slotIndex) then
        if slotInfo.fromCraftBag then
            slotInfo.slotActions:AddSlotAction(
                SI_ITEM_ACTION_TRADE_REMOVE, 
                function() 
                    
                    local tradeIndex = GetTradeSlotIndex(slotInfo)
                    local bagId, slotId = GetTradeItemBagAndSlot(TRADE_ME, tradeIndex)
                    local soundCategory = GetItemSoundCategory(bagId, slotId)
                    PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
                    TradeRemoveItem(tradeIndex)
                
                    -- Update the keybind strip command
                    ZO_InventorySlot_OnMouseEnter(slotInfo.inventorySlot)
                    -- Transfer mats back to craft bag
                    CBE.Inventory:TransferToCraftBag(bagId, slotId)
                end, 
                "primary")
        end
        
    --[[ Retrieve and Add to Offer ]]
    elseif ZO_SharedTradeWindow.FindMyNextAvailableSlot(ZO_Trade) and slotInfo.slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
        local actionName = SI_ITEM_ACTION_TRADE_ADD
        slotInfo.slotActions:AddSlotAction(
            actionName, 
            function() 
                CBE.Inventory:StartTransfer(
                    slotInfo.inventorySlot, 
                    actionName, SI_ITEM_ACTION_TRADE_ADD, 
                    OnBackpackTransferComplete) 
            end, 
            "primary")
    end
end