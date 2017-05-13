local cbe   = CraftBagExtended
local util  = cbe.utility
local class = cbe.classes
local name  = cbe.name .. "Bank"
local debug = false
class.Bank  = class.Module:Subclass()

function class.Bank:New(...)        
    local instance = class.Module.New(self, 
        name, "bank", 
        ZO_SharedRightPanelBackground, BACKPACK_BANK_LAYOUT_FRAGMENT, true)
    instance:Setup()
    return instance
end
    
--[[ When listening for a player bank slot updated, handle any player bank 
     transfer errors that get raised by stopping the transfer. ]]
local function OnBankIsFull(eventCode)
    
    local depositQueue = util.GetTransferQueue( BAG_BACKPACK, BAG_BANK )

    if not depositQueue:HasItems() then 
        if BAG_SUBSCRIBER_BANK then
            depositQueue = util.GetTransferQueue( BAG_BACKPACK, BAG_SUBSCRIBER_BANK )
            if not depositQueue:HasItems() then return end
        else
            return
        end
    end
    
    for i,transferItem in ipairs(depositQueue.items) do
        
        util.Debug("Moving "..transferItem.itemLink.." back to craft bag due to bank full error", debug)
        cbe:Stow(transferItem.slotIndex)
    end
end

function class.Bank:Setup()
    
    self.menu:SetAnchor(TOPLEFT, ZO_SharedRightPanelBackground, TOPLEFT, 55, 0)
    
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_BANK_TRANSFER_ERROR, OnBankIsFull)
    
    self.RegisterTabCallbacks(self.scene, BANK_FRAGMENT)
end

local function OnBankFragmentStateChange(oldState, newState)
    if newState == SCENE_FRAGMENT_SHOWN then
        cbe.currentModule.menu:SetHidden(true)
        if not cbe.fragmentGroup then
            SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
        end
    end
end

--[[ Called when the requested stack arrives in the backpack and is ready for
     deposit to the player bank.  Automatically deposits the stack. ]]
local function RetrieveCallback(transferItem)
    
    util.Debug("Transferring "..tostring(transferItem.targetBag)
               ..", "..tostring(transferItem.targetSlotIndex)..", x"
               ..tostring(transferItem.quantity).." to bank", debug)
               
    -- Perform the deposit
    local depositBagId
    if GetNumBagFreeSlots(BAG_BANK) < 1 and BAG_SUBSCRIBER_BANK and GetBagUseableSize(BAG_SUBSCRIBER_BANK) > 0 then
        depositBagId = BAG_SUBSCRIBER_BANK
    else
        depositBagId = BAG_BANK
    end
    util.TransferItemToBag( transferItem.targetBag, transferItem.targetSlotIndex, 
        depositBagId, transferItem.quantity, transferItem.callback)
end

--[[ Called when a previously deposited craft bag stack is withdrawn from the 
     bank and arrives in the backpack again.  Automatically stows the stack. ]]
local function WithdrawCallback(transferItem)
    
    util.Debug("Transferring "..tostring(transferItem.targetBag)
               ..", "..tostring(transferItem.targetSlotIndex)..", x"
               ..tostring(transferItem.quantity).." to craft bag", debug)
               
    -- Stow the withdrawn stack in the craft bag
    cbe:Stow(transferItem.targetSlotIndex, transferItem.quantity, transferItem.callback)
end

--[[ Checks to ensure that there is a free inventory slot available in both the
     backpack and in the player bank, and that there is a selected guild with
     a player bank and deposit permissions. If there is, returns true.  If not, an 
     alert is raised and returns false. ]]
local function ValidateCanDeposit(bag, slotIndex)
    if bag ~= BAG_VIRTUAL then return false end
    
    -- Don't transfer if you don't have enough free slots in the player or subscriber banks
    if GetNumBagFreeSlots(BAG_BANK) < 1 
       and (not BAG_SUBSCRIBER_BANK or GetBagUseableSize(BAG_SUBSCRIBER_BANK) < 1)
    then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_BANK_FULL)
        return false
    end
    
    -- Don't transfer if you don't have a free proxy slot in your backpack
    if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then
        ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
        return false
    end

    -- Don't transfer stolen items.  Shouldn't come up from this addon, since
    -- the craft bag filters stolen items out when in the player bank. However,
    -- good to check anyways in case some other addon uses this class.
    if(IsItemStolen(bag, slotIndex)) then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE)
        return false
    end
    
    return true
end           

--[[ Adds guildbank-specific inventory slot crafting bag actions ]]
function class.Bank:AddSlotActions(slotInfo)

    -- Only add these actions when the player bank screen is open on the craft bag tab
    if not PLAYER_INVENTORY:IsBanking() then return end
    
    if slotInfo.slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
    
        --[[ Deposit ]]--
        table.insert(slotInfo.slotActions, {
            SI_BANK_DEPOSIT,  
            function() cbe:BankDeposit(slotInfo.slotIndex) end,
            "primary" 
        })
        --[[ Deposit quantity ]]--
        table.insert(slotInfo.slotActions, {
            SI_CBE_CRAFTBAG_BANK_DEPOSIT,  
            function() cbe:BankDepositDialog(slotInfo.slotIndex) end,
            "keybind3"
        })
    end
end

--[[ Retrieves a given quantity of mats from a given craft bag slot index, 
     and then automatically deposits them in the player bank.
     If quantity is nil, then the max stack is deposited.
     If the bank or backpack don't each have at least one slot available, 
     an alert is raised and no mats leave the craft bag.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they arrive in the player bank. ]]
function class.Bank:Deposit(slotIndex, quantity, backpackCallback, bankCallback)
    if not ValidateCanDeposit(BAG_VIRTUAL, slotIndex) then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, bankCallback)
    return cbe:Retrieve(slotIndex, quantity, callback)
end

--[[ Opens a retrieve dialog for a given craft bag slot index, 
     and then automatically deposits the selected quantity into the player bank.
     If quantity is nil, then the max stack is deposited.
     If the bank or backpack don't each have at least one slot available, 
     an alert is raised and no dialog is shown.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they arrive in the player bank. ]]
function class.Bank:DepositDialog(slotIndex, backpackCallback, bankCallback)
    if not ValidateCanDeposit(BAG_VIRTUAL, slotIndex) then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, bankCallback)
    return cbe:RetrieveDialog(slotIndex, SI_CBE_CRAFTBAG_BANK_DEPOSIT, SI_ITEM_ACTION_BANK_DEPOSIT, callback)
end   

function class.Bank:FilterSlot(inventoryManager, inventory, slot)
    if not PLAYER_INVENTORY:IsBanking() then
        return
    end
    
    -- Exclude protected slots
    if IsItemStolen(slot.bag, slot.slotIndex) then 
        return true 
    end
end

function class.Bank.RegisterTabCallbacks(scene, bankFragment)
    --[[ Handle scene open close events ]]
    scene:RegisterCallback("StateChange", 
        function (oldState, newState)
            if newState == SCENE_SHOWING then
                bankFragment:RegisterCallback("StateChange", OnBankFragmentStateChange)
            elseif newState == SCENE_HIDING then
                bankFragment:UnregisterCallback("StateChange", OnBankFragmentStateChange)
            end
        end)
end

--[[ Withdraws a given stack of mats from the player or subscriber bank
     and then automatically stows them in the craft bag.
     If bagId is not specified, then BAG_BANK is assumed.
     If the backpack doesn't have at least one slot available, 
     an alert is raised and no mats are transferred.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they arrive in the craft bag. ]]
function class.Bank:Withdraw(bagId, slotIndex, backpackCallback, craftbagCallback)
    if type(slotIndex) == "function" or slotIndex == nil then
         craftbagCallback = backpackCallback
         backpackCallback = slotIndex
         slotIndex = bagId
         bagId = BAG_BANK
    end
    if not bagId then
        bagId = BAG_BANK
    end
    if bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK then
        return
    end
    local callback = { util.WrapFunctions(backpackCallback, WithdrawCallback) }
    table.insert(callback, craftbagCallback)
    return util.TransferItemToBag(bagId, slotIndex, BAG_BACKPACK, nil, callback)
end