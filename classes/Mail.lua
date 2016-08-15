local cbe   = CraftBagExtended
local util  = cbe.utility
local class = cbe.classes
class.Mail  = class.Controller:Subclass()

local name = cbe.name .. "Mail"
local debug = false

function class.Mail:New(...)
    local instance = class.Controller.New(self, 
        name, "mailSend", ZO_MailSend, BACKPACK_MAIL_LAYOUT_FRAGMENT)
    instance.menu:SetAnchor(TOPRIGHT, ZO_MailSend, TOPLEFT, ZO_MailSendTo:GetWidth(), 22)
    util.RemapKeybind(MAIL_SEND.staticKeybindStripDescriptor, 
        "UI_SHORTCUT_SECONDARY", "UI_SHORTCUT_TERTIARY")
    return instance
end

--[[ Returns true if the mail send interface is currently open. Otherwise returns false. ]]
local function IsSendingMail()
    if MAIL_SEND and not MAIL_SEND:IsHidden() then
        return true
    elseif MAIL_MANAGER_GAMEPAD and MAIL_MANAGER_GAMEPAD:GetSend():IsAttachingItems() then
        return true
    end
    return false
end

--[[ Returns the index of the attachment slot that's bound to a given inventory slot, 
     or nil if it's not attached. ]]
local function GetAttachmentSlotIndex(bag, slotIndex)
    if (bag) then
        for i = 1, MAIL_MAX_ATTACHED_ITEMS do
            local bagId, attachmentIndex = GetQueuedItemAttachmentInfo(i)
            if bagId == bag and attachmentIndex == slotIndex then
                return i
            end
        end
    end
end

local function GetNextEmptyMailAttachmentIndex()
    for i = 1, MAIL_MAX_ATTACHED_ITEMS do
        local queuedFromBag = GetQueuedItemAttachmentInfo(i)
        if queuedFromBag == 0 then
            return i
        end
    end
end

--[[ Returns true if a given inventory slot is attached to the sending mail. 
     Otherwise, returns false. ]]
local function IsAttached(bag, slotIndex)
    local attachmentSlotIndex = GetAttachmentSlotIndex(bag, slotIndex)
    if attachmentSlotIndex then
        return GetQueuedItemAttachmentInfo(attachmentSlotIndex) ~= 0
    end
end

--[[ Called after a Retrieve and Add to Mail operation successfully retrieves a craft bag item 
     to the backpack. Responsible for executing the "Add to Mail" part of the operation. ]]
local function RetrieveCallback(transferItem)

    if not IsSendingMail() then return end
    
    if not transferItem then
        util.Debug(name..":RetrieveCallback did not receive its transferItem parameter", debug)
    end
    
    local errorStringId = nil
    
    -- Find the first empty attachment slot
    local emptyAttachmentSlotIndex = GetNextEmptyMailAttachmentIndex()
    
    -- There were no empty attachment slots left
    if not emptyAttachmentSlotIndex then
        errorStringId = SI_MAIL_ATTACHMENTS_FULL
    
    -- Empty attachment slot found.
    else
        -- Attempt the attachment
        local result = QueueItemAttachment(transferItem.targetBag, transferItem.targetSlotIndex, emptyAttachmentSlotIndex)

        -- Assign error messages to different results
        if(result == MAIL_ATTACHMENT_RESULT_ALREADY_ATTACHED) then
            errorStringId = SI_MAIL_ALREADY_ATTACHED
        elseif(result == MAIL_ATTACHMENT_RESULT_BOUND) then
            errorStringId = SI_MAIL_BOUND
        elseif(result == MAIL_ATTACHMENT_RESULT_ITEM_NOT_FOUND) then
            errorStringId = SI_MAIL_ITEM_NOT_FOUND
        elseif(result == MAIL_ATTACHMENT_RESULT_LOCKED) then
            errorStringId = SI_MAIL_LOCKED
        elseif(result == MAIL_ATTACHMENT_RESULT_STOLEN) then
            errorStringId = SI_STOLEN_ITEM_CANNOT_MAIL_MESSAGE
        end
    end
    
    -- If there is an error adding the attachment, output it as an alert and return the mats
    -- back to the craft bag.
    if errorStringId then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(errorStringId))
        cbe:Stow(transferItem.targetSlotIndex)
        return
    end
    
    -- Perform any configured callbacks after attachments are added
    transferItem:ExecuteCallback(transferItem.targetSlotIndex, emptyAttachmentSlotIndex)
end

local function ValidateCanAttach()
    -- Find the first empty attachment slot
    local emptyAttachmentSlotIndex = GetNextEmptyMailAttachmentIndex()
    
    -- There were no empty attachment slots left
    if emptyAttachmentSlotIndex then
        return true
    end
    
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_MAIL_ATTACHMENTS_FULL))
end

--[[ Adds mail-specific inventory slot crafting bag actions ]]
function class.Mail:AddSlotActions(slotInfo)
    
    if not IsSendingMail() then return end
    
    -- For attachment slots, check the actual entry slot for the fromCraftBag flag
    if slotInfo.slotType == SLOT_TYPE_MAIL_QUEUED_ATTACHMENT then
        local inventoryType = PLAYER_INVENTORY.bagToInventoryType[slotInfo.bag]
        local slot = PLAYER_INVENTORY.inventories[inventoryType].slots[slotInfo.slotIndex]
        slotInfo.fromCraftBag = slot.fromCraftBag
    end
    
    --[[ Detach and Stow ]]
    if IsAttached(slotInfo.bag, slotInfo.slotIndex) then
        if slotInfo.fromCraftBag then
            slotInfo.slotActions:AddSlotAction(
                SI_ITEM_ACTION_MAIL_DETACH, 
                function() cbe:MailDetach(slotInfo.slotIndex) end, 
                "primary")
        end
        
    elseif slotInfo.slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
        --[[ Add to Mail ]]
        slotInfo.slotActions:AddSlotAction(
            SI_ITEM_ACTION_MAIL_ATTACH, 
            function() cbe:MailAttach(slotInfo.slotIndex) end, 
            "primary")
        --[[ Add to Mail quantity ]]
        slotInfo.slotActions:AddSlotAction(
            SI_CBE_CRAFTBAG_MAIL_ATTACH, 
            function() cbe:MailAttachDialog(slotInfo.slotIndex) end, 
            "keybind1")
    end
end

--[[ Retrieves a given quantity of mats from a given craft bag slot index, 
     and then automatically attaches the stack onto the pending mail.
     If quantity is nil, then the max stack is deposited.
     If no attachment slots remain an alert is raised and no mats leave the craft bag.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they have been attached. ]]
function class.Mail:Attach(slotIndex, quantity, backpackCallback, attachedCallback)
    if not ValidateCanAttach() then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, attachedCallback)
    return cbe:Retrieve(slotIndex, quantity, callback)
end

--[[ Opens a retrieve dialog for a given craft bag slot index, 
     and then automatically attaches the selected quantity onto pending mail.
     If no attachment slots remain an alert is raised and no dialog is shown.
     An optional callback can be raised both when the mats arrive in the backpack
     and/or when they have been attached. ]]
function class.Mail:AttachDialog(slotIndex, backpackCallback, attachedCallback)
    if not ValidateCanAttach() then return false end
    local callback = { util.WrapFunctions(backpackCallback, RetrieveCallback) }
    table.insert(callback, attachedCallback)
    return cbe:RetrieveDialog(slotIndex, SI_CBE_CRAFTBAG_MAIL_ATTACH, SI_ITEM_ACTION_MAIL_ATTACH, callback)
end

--[[ Detaches the stack at the given backpack slot index and returns it to the
     craft bag.  If the stack is not attached, returns false.  Optionally
     raises a callback after the stack is detached and/or after the stack is
     returned to the craft bag. ]]
function class.Mail:Detach(slotIndex, detachedCallback, stowedCallback)

    local attachmentSlotIndex = 
        GetAttachmentSlotIndex(BAG_BACKPACK, slotIndex)
    if not attachmentSlotIndex then
        return false
    end
    
    RemoveQueuedItemAttachment(attachmentSlotIndex)
    
    -- Update the keybind strip command
    local inventorySlot = util.GetInventorySlot(BAG_BACKPACK, slotIndex)
    if inventorySlot then
        ZO_InventorySlot_OnMouseEnter(inventorySlot)
    end
    
    -- Callback that the detachment succeeded
    if type(detachedCallback) == "function" then
        local stowQueue = util.GetTransferQueue(BAG_BACKPACK, BAG_VIRTUAL)
        local transferItem = class.TransferItem:New(stowQueue, slotIndex)
        detachedCallback(transferItem, attachmentSlotIndex)
    end
    
    -- Transfer mats back to craft bag
    return cbe:Stow(slotIndex, nil, stowedCallback)
end

function class.Mail:FilterSlot(inventoryManager, inventory, slot)
    if not IsSendingMail() then 
        return 
    end
    
    -- Exclude protected slots
    if util.IsSlotProtected(slot) then 
        return true 
    end
end