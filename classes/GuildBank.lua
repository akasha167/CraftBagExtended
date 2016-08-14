local cbe       = CraftBagExtended
local util      = cbe.utility
local class     = cbe.classes
local name      = cbe.name .. "GuildBank"
class.GuildBank = class.Controller:Subclass()

function class.GuildBank:New(...)        
    local instance = class.Controller.New(self, 
        name, "guildBank", 
        ZO_SharedRightPanelBackground, BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT,
        ZO_GuildBankMenuBar, SI_BANK_DEPOSIT,
        PLAYER_INVENTORY.guildBankDepositTabKeybindButtonGroup,
        "UI_SHORTCUT_SECONDARY")
    instance:Setup()
    return instance
end

function class.GuildBank:Setup()

    self.debug = false
    self.depositQueue = 
        class.TransferQueue:New(
            self.name .. "DepositQueue", 
            BAG_BACKPACK, 
            BAG_GUILDBANK
        )
    self.withdrawalQueue = 
        class.TransferQueue:New(
            self.name .. "WithdrawalQueue",
            BAG_GUILDBANK, 
            BAG_BACKPACK
        )
    self.menu:SetAnchor(TOPLEFT, ZO_SharedRightPanelBackground, TOPLEFT, 55, 0)
    
    --[[ When listening for a guild bank slot updated, handle any guild bank 
         transfer errors that get raised by stopping the transfer. ]]
    local function OnBankTransferFailed(eventCode, reason)
        if not self.depositQueue:HasItems() then return end
        
        for i,transferItem in ipairs(self.depositQueue.items) do
            
            local itemLink = GetItemLink(transferItem.bag, transferItem.slotIndex)
            util.Debug("Moving "..itemLink.." back to craft bag due to bank transfer error "..tostring(reason), self.debug)
            cbe:TransferToCraftBag(transferItem.bag, transferItem.slotIndex)
        end
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_BANK_TRANSFER_ERROR, OnBankTransferFailed)
    
    
    
    --[[ FEATURE: DISABLE GUILD BANK AUTO-STASH TO CRAFT BAG ON WITHDRAWAL ]]--
    
    
    --[[ Listen for new guild bank craft material withdrawals and add them to 
         the pending withdrawal queue ]]
    local function OnGuildBankWithdrawal(slotId)
    
        local isVirtual = CanItemBeVirtual(BAG_GUILDBANK, slotId)
        util.Debug("Slot id "..tostring(slotId).." is virtual: "..tostring(isVirtual), self.debug)
        util.Debug("guildBankAutoStashOff: "..tostring(cbe.settings.db.guildBankAutoStashOff), self.debug)
        
        -- When auto-stash is off, watch for craft item withdrawals from the guild bank
        if cbe.settings.db.guildBankAutoStashOff 
           and isVirtual and not (Roomba and Roomba.WorkInProgress()) 
        then 
            self.withdrawalQueue:Enqueue(slotId)
        end
    end
    ZO_PreHook("TransferFromGuildBank", OnGuildBankWithdrawal)
    
    --[[ Process new craft bag slot updates that match stacks in the withdrawal
         queue by sending them back to the backpack. ]]
    local function OnInventorySlotUpdated(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
    
        if not cbe.settings.db.guildBankAutoStashOff then return end
        
        -- Make a craft bag item slot was just updated, and that we have guild
        -- bank crafting items in the guild bank withdrawal queue.
        if bagId ~= BAG_VIRTUAL or not self.withdrawalQueue:HasItems() then return end
        
        -- Try to find this specific craft bag item in the withdrawal queue
        local transferItem = self.withdrawalQueue:Dequeue(bagId, slotId)
        if not transferItem then return end
        
        -- Find the first free slot in the backpack
        local backpackSlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
        if not backpackSlotIndex then
            ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
            return
        end
        
        -- Refresh the tooltip counts once the stack makes it's way to the backpack
        cbe.backpackTransferQueue:StartWaitingForTransfer(slotId, 
            function() util.RefreshActiveTooltip() end, transferItem.quantity)
        
        -- Initiate the stack move to the backpack
        if IsProtectedFunction("RequestMoveItem") then
            CallSecureProtected("RequestMoveItem", bagId, slotId, BAG_BACKPACK, backpackSlotIndex, transferItem.quantity)
        else
            RequestMoveItem(bagId, slotId, BAG_BACKPACK, backpackSlotIndex, transferItem.quantity)
        end
        
        util.Debug("Transferring "..tostring(transferItem.quantity).." of "..transferItem.itemLink.." in craft bag slotId "..tostring(slotId).." back to backpack slot "..tostring(backpackSlotIndex)..", isNewItem: "..tostring(isNewItem)..", updateReason: "..updateReason, self.debug)
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdated)
    
    --[[ END FEATURE ]]--
    
    

    --[[ Handles bank item slot update events thrown from a "Deposit" action. ]]
    local function OnBankSlotUpdated(eventCode, slotId)

        util.Debug("bank transfer dequeue: "..tostring(eventCode)..", "..tostring(slotId), self.debug)
        local transferItem = self.depositQueue:Dequeue(slotId)
        
        if not transferItem then 
            util.Debug("Not waiting for any bank transfers for guild bank slot "..tostring(slotId), self.debug)
            return 
        end
        
        -- Update the craft bag tooltip
        util.RefreshActiveTooltip()
    end
    
    -- Listen for bank slot updates
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_BANK_ITEM_ADDED, OnBankSlotUpdated)
end

--[[ Checks to ensure that there is a free inventory slot available in both the
     backpack and in the guild bank, and that there is a selected guild with
     a guild bank and deposit permissions. If there is, returns true.  If not, an 
     alert is raised and returns false. ]]
local function ValidateCanDeposit(bag, slotIndex)
    if bag ~= BAG_VIRTUAL then return false end
        
    local guildId = GetSelectedGuildBankId()
    if not guildId then return false end
    
    -- Don't transfer if you don't have enough free slots in the guild bank
    if GetNumBagFreeSlots(BAG_GUILDBANK) < 1 then
        ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_SPACE_LEFT)
        return false
    end
    
    -- Don't transfer if you don't have a free proxy slot in your backpack
    if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then
        ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
        return false
    end
    
    -- Don't transfer if the guild member doesn't have deposit permissions
    if(not DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT)) then
        ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_DEPOSIT_PERMISSION)
        return false
    end

    -- Don't transfer if the guild doesn't have 10 members
    if(not DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT)) then
        ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_GUILD_TOO_SMALL)
        return false
    end

    -- Don't transfer stolen items.  Shouldn't come up from this addon, since
    -- the craft bag filters stolen items out when in the guild bank. However,
    -- good to check anyways in case some other addon uses this class.
    if(IsItemStolen(sourceBag, sourceSlot)) then
        ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_DEPOSIT_STOLEN_ITEM)
        return false
    end
    
    return true
end           

--[[ Adds guildbank-specific inventory slot crafting bag actions ]]
function class.GuildBank:AddSlotActions(slotInfo)

    -- Only add these actions when the guild bank screen is open on the craft bag tab
    if GetInteractionType() ~= INTERACTION_GUILDBANK 
       or not GetSelectedGuildBankId() 
       or slotInfo.slotType ~= SLOT_TYPE_CRAFT_BAG_ITEM then 
        return 
    end
    local inventorySlot = slotInfo.inventorySlot
    local bag = slotInfo.bag
    local slotIndex = slotInfo.slotIndex
    
    --[[ Deposit ]]--
    slotInfo.slotActions:AddSlotAction(
        SI_BANK_DEPOSIT,  
        function() 
            if not ValidateCanDeposit(bag, slotIndex) then 
                util.Debug("free slot validation failed for bag "..tostring(bag).." index "..tostring(slotIndex), self.debug)
                return
            end
    
            local backpackSlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
            local stackSize, maxStackSize = GetSlotStackSize(bag, slotIndex)
            local quantity = math.min(stackSize, maxStackSize)
            
            -- Register the callback that will run after the stack makes its
            -- way to the backpack.
            if not cbe.backpackTransferQueue:StartWaitingForTransfer(slotIndex, 
                function(transferItem)
                                    
                    if not transferItem then
                        util.Debug(self.name..":OnBackpackTransferComplete did not receive its transferItem parameter", self.debug)
                    end

                    -- Listen for guild bank slot updates
                    util.Debug("bank transfer enqueue: "..tostring(transferItem.targetBag)..", "..tostring(transferItem.targetSlotIndex)..", "..tostring(transferItem.quantity)..", "..BAG_GUILDBANK, self.debug)
                    self.depositQueue:Enqueue(transferItem.targetSlotIndex, transferItem.quantity)
                    
                    TransferToGuildBank(transferItem.targetBag, transferItem.targetSlotIndex)
                end, quantity) then 
                util.Debug("enqueue failed for bag "..tostring(bag).." index "..tostring(slotIndex), self.debug)
                return 
            end
            
            -- Initiate the stack move to the backpack
            if IsProtectedFunction("RequestMoveItem") then
                CallSecureProtected("RequestMoveItem", bag, slotIndex, BAG_BACKPACK, backpackSlotIndex, quantity)
            else
                RequestMoveItem(bag, slotIndex, BAG_BACKPACK, backpackSlotIndex, quantity)
            end
        end,
        "primary"
    )
    
    --[[ Deposit quantity ]]--
    local actionName = SI_CBE_CRAFTBAG_BANK_DEPOSIT
    slotInfo.slotActions:AddSlotAction(
        actionName,  
        function()
            if not ValidateCanDeposit(bag, slotIndex) then return end
            cbe:RetrieveDialog(slotIndex, actionName, SI_ITEM_ACTION_BANK_DEPOSIT,
                function(transferItem)
                                    
                    if not transferItem then
                        util.Debug(self.name..":OnBackpackTransferComplete did not receive its transferItem parameter", self.debug)
                    end

                    -- Listen for guild bank slot updates
                    util.Debug("bank transfer enqueue: "..tostring(transferItem.targetBag)..", "..tostring(transferItem.targetSlotIndex)..", "..tostring(transferItem.quantity)..", "..BAG_GUILDBANK, self.debug)
                    self.depositQueue:Enqueue(transferItem.targetSlotIndex, transferItem.quantity)
                    
                    TransferToGuildBank(transferItem.targetBag, transferItem.targetSlotIndex)
                end)
        end,
        "keybind1"
    )
end

function class.GuildBank:FilterSlot(inventoryManager, inventory, slot)
    if GetInteractionType() ~= INTERACTION_GUILDBANK 
       or not GetSelectedGuildBankId() 
    then
        return
    end
    
    -- Exclude protected slots
    if util.IsSlotProtected(slot) then 
        return true 
    end
end
