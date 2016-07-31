CBE_TradeController = ZO_Object:Subclass()

function CBE_TradeController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

local name = "CBE_TradeController"
local debug = false

function CBE_TradeController:Initialize()

    self.name = name

    --[[ Button click callback for toggling between backpack and craft bag. ]]
    local function OnCraftBagMenuButtonClicked(buttonData, playerDriven)
        if not TRADE_WINDOW:IsTrading() then
            return
        end
        if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
            ZO_PlayerInventory:SetHidden(true)
            ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
            SCENE_MANAGER:AddFragment(CRAFT_BAG_FRAGMENT)
        else
            SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
            ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
            PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK, true)
            ZO_PlayerInventory:SetHidden(false)
        end
    end
    
    --[[ Handle mail send scene open/close events ]]
    local function OnTradeSceneStateChange(oldState, newState)
    
        -- On exit, remove additional craft bag filtering, and stop listening for any transfers
        if newState == SCENE_HIDDEN then 
            PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG].additionalFilter = nil
            CBE.Inventory.backpackTransferQueue:Clear()    
            return 
            
        -- On enter, add filtering for the craft bag to exclude bound, stolen, and locked items
        elseif newState == SCENE_SHOWING then
            PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG].additionalFilter =  
                function(slot)
                    -- Workaround for IsItemBound() not working on craft bag slots
                    local itemLink = GetItemLink(slot.bagId, slot.slotIndex)
                    local bindType = GetItemLinkBindType(itemLink)
                    local isBound = (bindType == BIND_TYPE_ON_PICKUP or bindType == BIND_TYPE_ON_PICKUP_BACKPACK)
                    local isValid = (not isBound) 
                                    and (not slot.stolen) 
                                    and (not slot.isPlayerLocked)
                    return isValid
                end
            return
        
        -- Since reopening the mail send scene causes the inventory list to show regardless of 
        -- whether the craft bag was open when it last closed, we need to initialize the craft bag.
        elseif newState == SCENE_SHOWN then
            local button = CBE_TradeMenu.m_object.m_clickedButton
            if not button then return end
            OnCraftBagMenuButtonClicked(button.m_buttonData, false)
        end
    end
    
    SCENE_MANAGER.scenes["trade"]:RegisterCallback("StateChange",  OnTradeSceneStateChange)
    
    --[[ Create craft bag menu ]]
    local menuBar = CreateControlFromVirtual("CBE_TradeMenu", ZO_Trade, "ZO_LabelButtonBar")
    menuBar:SetAnchor(BOTTOMRIGHT, ZO_TradeMyControls, TOPRIGHT, 0, -12)
    CBE:AddItemsButton(menuBar, OnCraftBagMenuButtonClicked)
    CBE:AddCraftBagButton(menuBar, OnCraftBagMenuButtonClicked)
    ZO_MenuBar_SelectFirstVisibleButton(menuBar, true)
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
                SI_CBE_CRAFTBAG_TRADE_REMOVE, 
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
        local actionName = SI_CBE_CRAFTBAG_TRADE_ADD
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