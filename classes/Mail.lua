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
local function OnBackpackTransferComplete(transferItem)

    if not IsSendingMail() then return end
    
    if not transferItem then
        util.Debug(name..":OnBackpackTransferComplete did not receive its transferItem parameter", debug)
    end
    
    local errorStringId = nil
    
    -- Find the first empty attachment slot
    local emptyAttachmentSlotIndex = 0
    for i = 1, MAIL_MAX_ATTACHED_ITEMS do
        local queuedFromBag = GetQueuedItemAttachmentInfo(i)
        if queuedFromBag == 0 then
            emptyAttachmentSlotIndex = i
            break
        end
    end
    
    -- There were no empty attachment slots left
    if emptyAttachmentSlotIndex == 0 then
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
        cbe:TransferToCraftBag(transferItem.targetBag, transferItem.targetSlotIndex)
    end
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
                function() 
                    local attachmentSlotIndex = 
                        GetAttachmentSlotIndex(slotInfo.bag, slotInfo.slotIndex)
                    RemoveQueuedItemAttachment(attachmentSlotIndex)
                    -- Update the keybind strip command
                    ZO_InventorySlot_OnMouseEnter(slotInfo.inventorySlot)
                    -- Transfer mats back to craft bag
                    cbe:TransferToCraftBag(slotInfo.bag, slotInfo.slotIndex)
                end, 
                "primary")
        end
        
    --[[ Retrieve and Add to Mail ]]
    elseif slotInfo.slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
        local actionName = SI_ITEM_ACTION_MAIL_ATTACH
        slotInfo.slotActions:AddSlotAction(
            actionName, 
            function() 
                cbe:RetrieveDialog(
					slotInfo.slotIndex, 
                    actionName, SI_ITEM_ACTION_MAIL_ATTACH, 
                    OnBackpackTransferComplete) 
            end, 
            "primary")
    end
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