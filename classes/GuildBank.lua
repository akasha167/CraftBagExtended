local cbe       = CraftBagExtended
local util      = cbe.utility
local class     = cbe.classes
local name      = cbe.name .. "GuildBank"
local debug     = false
class.GuildBank = class.Module:Subclass()

function class.GuildBank:New(...)        
    local instance = class.Module.New(self, 
        name, "guildBank", 
        ZO_SharedRightPanelBackground, BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT,
        ZO_GuildBankMenuBar, SI_BANK_DEPOSIT)
    instance:Setup()
    return instance
end

--[[ Handles bank item slot update events thrown from a "Deposit" action. ]]
local function OnGuildBankSlotUpdated(eventCode, slotId)

    util.Debug("bank transfer dequeue: "..tostring(eventCode)..", "..tostring(slotId), debug)
    local depositQueue = util.GetTransferQueue( BAG_BACKPACK, BAG_GUILDBANK )
    local transferItem = depositQueue:Dequeue(slotId)
    
    if not transferItem then 
        util.Debug("Not waiting for any bank transfers for guild bank slot "..tostring(slotId), debug)
        return 
    end
    
    -- Perform any configured callbacks
    transferItem:ExecuteCallback(slotId)
    
    -- Update the craft bag tooltip
    util.RefreshActiveTooltip()
end
    
--[[ When listening for a guild bank slot updated, handle any guild bank 
     transfer errors that get raised by stopping the transfer. ]]
local function OnGuildBankTransferFailed(eventCode, reason)
    
    local depositQueue = util.GetTransferQueue( BAG_BACKPACK, BAG_GUILDBANK )

    if not depositQueue:HasItems() then return end
    
    for i,transferItem in ipairs(depositQueue.items) do
        
        util.Debug("Moving "..transferItem.itemLink.." back to craft bag due to bank transfer error "..tostring(reason), debug)
        cbe:Stow(transferItem.slotIndex)
    end
end

--[[ Process withdrawn craft bag mats by sending them back to the backpack,
     if the auto-stash disable feature is configured. ]]
local function PostGuildBankWithdrawal(transferItem)
    if cbe.settings.db.guildBankAutoStashOff then
        cbe:Retrieve(transferItem.targetSlotIndex, transferItem.quantity)
    end
end
    
--[[ Listen for new guild bank craft material withdrawals and add them to 
     the pending withdrawal queue ]]
local function OnGuildBankWithdrawal(slotId)
    local isVirtual = CanItemBeVirtual(BAG_GUILDBANK, slotId)
    
    -- When auto-stash is off, watch for craft item withdrawals from the guild bank
    if cbe.settings.db.guildBankAutoStashOff 
       and isVirtual and not (Roomba and Roomba.WorkInProgress()) 
       and HasCraftBagAccess()
    then
        local withdrawalQueue = util.GetTransferQueue( BAG_GUILDBANK, BAG_VIRTUAL )
        withdrawalQueue:Enqueue(slotId, nil, PostGuildBankWithdrawal)
    end
end

function class.GuildBank:Setup()
    
    self.menu:SetAnchor(TOPLEFT, ZO_SharedRightPanelBackground, TOPLEFT, 55, 0)
    
    -- Hook guild bank withdrawals so that we can listen for the withdrawals
    -- in the craft bag and move them back to the backpack if configured.
    ZO_PreHook("TransferFromGuildBank", OnGuildBankWithdrawal)
    
    -- Listen for bank slot updates
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_BANK_ITEM_ADDED, OnGuildBankSlotUpdated)
    
    -- Listen for deposit failures
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_BANK_TRANSFER_ERROR, OnGuildBankTransferFailed)
end

--[[ Called when the requested stack arrives in the backpack and is ready for
     deposit to the guild bank.  Automatically deposits the stack. ]]
local function RetrieveCallback(transferItem)
    
    -- If multiple callbacks were specified, then listen for guild bank slot 
    -- updates that will raise the next callback
    if type(transferItem.callback) == "table" then
        transferItem:Requeue(BAG_GUILDBANK)
    end
    
    util.Debug("Transferring "..tostring(transferItem.targetBag)
               ..", "..tostring(transferItem.targetSlotIndex)..", x"
               ..tostring(transferItem.quantity).." to guild bank", debug)
               
    -- Perform the deposit
    TransferToGuildBank(transferItem.targetBag, transferItem.targetSlotIndex)
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
    if(IsItemStolen(bag, slotIndex)) then
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
    local slotIndex = slotInfo.slotIndex
    
    --[[ Deposit ]]--
    table.insert(slotInfo.slotActions, {
        SI_BANK_DEPOSIT,  
        function() cbe:GuildBankDeposit(slotIndex) end,
        "primary"
    })
    
    --[[ Deposit quantity ]]--
    table.insert(slotInfo.slotActions, {
        SI_CBE_CRAFTBAG_BANK_DEPOSIT,  
        function() cbe:GuildBankDepositDialog(slotIndex) end,
        "keybind3"
    })
end

--[[ Retrieves a given quantity of mats from a given craft bag slot index, 
     and then automatically deposits them in the currently-selected guild bank.
     If quantity is nil, then the max stack is deposited.
     If no guild bank is selected, or if the current guild or user doesn't have
     bank privileges, an alert is raised and no mats leave the craft bag.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they arrive in the guild bank. ]]
function class.GuildBank:Deposit(slotIndex, quantity, backpackCallback, guildBankCallback)
    if not ValidateCanDeposit(BAG_VIRTUAL, slotIndex) then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, guildBankCallback)
    return cbe:Retrieve(slotIndex, quantity, callback)
end

--[[ Opens a retrieve dialog for a given craft bag slot index, 
     and then automatically deposits the selected quantity into the 
     currently-selected guild bank.
     If quantity is nil, then the max stack is deposited.
     If no guild bank is selected, or if the current guild or user doesn't have
     bank privileges, an alert is raised and no dialog is shown.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they arrive in the guild bank. ]]
function class.GuildBank:DepositDialog(slotIndex, backpackCallback, guildBankCallback)
    if not ValidateCanDeposit(BAG_VIRTUAL, slotIndex) then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, guildBankCallback)
    return cbe:RetrieveDialog(slotIndex, SI_CBE_CRAFTBAG_BANK_DEPOSIT, SI_ITEM_ACTION_BANK_DEPOSIT, callback)
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