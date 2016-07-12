local addon = {
    name = "CraftBagExtended",
    title = GetString(SI_CBE),
    author = "|c99CCEFsilvereyes|r",
    version = "1.0.0",
    guildBankFragments = {
        [SI_BANK_WITHDRAW] = { GUILD_BANK_FRAGMENT },
        [SI_BANK_DEPOSIT]  = { INVENTORY_FRAGMENT, BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT },
        [SI_INVENTORY_MODE_CRAFT_BAG] = { CRAFT_BAG_FRAGMENT },
    },
    anchors = { }
}

-- Output formatted message to chat window, if configured
local function pOutput(input)
    local output = zo_strformat("<<1>>|cFFFFFF: <<2>>|r", addon.title, input)
    d(output)
end

local function SwitchScene(oldScene, newScene) 
    local removeFragments = addon.guildBankFragments[oldScene]
    for i,removeFragment in pairs(removeFragments) do
        SCENE_MANAGER:RemoveFragment(removeFragment)
    end
    
    if newScene == SI_INVENTORY_MODE_CRAFT_BAG then
        ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
    elseif oldScene == SI_INVENTORY_MODE_CRAFT_BAG then
        ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
    end
    
    local addFragments = addon.guildBankFragments[newScene]
    for i,addFragment in pairs(addFragments) do
        SCENE_MANAGER:AddFragment(addFragment)
    end
end

local function OnGuildBankTabChanged(buttonData, playerDriven)

    -- If the scene is in the process of showing still, no switch is needed
    local guildBankSceneState = SCENE_MANAGER.scenes["guildBank"].state
    if guildBankSceneState == SCENE_SHOWING then 
        addon.lastButtonName = buttonData.descriptor
        return 
    end
    
    if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG or addon.lastButtonName == SI_INVENTORY_MODE_CRAFT_BAG then
        SwitchScene(addon.lastButtonName, buttonData.descriptor)
    end
    
    addon.lastButtonName = buttonData.descriptor
end

local function OnGuildBankSceneStateChange(oldState, newState)
    local anchorTemplate
    if(newState == SCENE_SHOWING) then
        anchorTemplate = ZO_GuildBank:GetName()
    elseif(newState == SCENE_HIDDEN) then
        anchorTemplate = ZO_CraftBag:GetName()
    else
        return
    end
    ZO_CraftBag:ClearAnchors()
    for i=0,1 do
        local anchor = addon.anchors[anchorTemplate][i]
        ZO_CraftBag:SetAnchor(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
    end
end

local function RegisterAnchors() 
    local windowAnchorsToSave = { ZO_GuildBank, ZO_CraftBag }
    for i,window in pairs(windowAnchorsToSave) do
        local anchors = {}
        for j=0,1 do
            local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = window:GetAnchor(j)
            anchors[j] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX,
                offsetY = offsetY,    
            }
            addon.anchors[window:GetName()] = anchors
        end
    end
end

local function OnCraftBagButtonClicked(buttonData, playerDriven)
    ZO_GuildBankMenuBarLabel:SetText(GetString(SI_INVENTORY_MODE_CRAFT_BAG))
    OnGuildBankTabChanged(buttonData, playerDriven)
    
    -- Remove Deposit/withdraw keybind button when on craft bag tab
    local keybindDescriptor = KEYBIND_STRIP.keybinds["UI_SHORTCUT_SECONDARY"].keybindButtonDescriptor
    KEYBIND_STRIP:RemoveKeybindButton(keybindDescriptor)
end

local function AddCraftBagButton(menuBar, callback)
    local name = SI_INVENTORY_MODE_CRAFT_BAG
    return ZO_MenuBar_AddButton(
        menuBar, 
        {
            normal = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_up.dds",
            pressed = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_down.dds",
            highlight = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_over.dds",
            descriptor = name,
            categoryName = name,
            callback = callback,
            --alwaysShowTooltip = true,
            CustomTooltipFunction = function(...) ZO_InventoryMenuBar:LayoutCraftBagTooltip(...) end,
            statusIcon = function()
                if SHARED_INVENTORY and SHARED_INVENTORY:AreAnyItemsNew(nil, nil, BAG_VIRTUAL) then
                    return ZO_KEYBOARD_NEW_ICON
                end
                return nil
            end
        })
end

local function AddItemsButton(menuBar, callback)
    local name = SI_INVENTORY_MODE_ITEMS
    return ZO_MenuBar_AddButton(
        menuBar, 
        {
            normal = "EsoUI/Art/Inventory/inventory_tabIcon_items_up.dds",
            pressed = "EsoUI/Art/Inventory/inventory_tabIcon_items_down.dds",
            highlight = "EsoUI/Art/Inventory/inventory_tabIcon_items_over.dds",
            descriptor = name,
            categoryName = name,
            --alwaysShowTooltip = true,
            callback = callback
        })
end

local function SetupButtons()
    local buttons = ZO_GuildBankMenuBar.m_object.m_buttons
    
    -- Wire up original guild bank buttons for tab changed event
    for i, button in ipairs(buttons) do
        local buttonData = button[1].m_object.m_buttonData
        local callback = buttonData.callback
        buttonData.callback = function(...)
            OnGuildBankTabChanged(...)
            callback(...)
        end
    end
    
    -- Create craft bag button
    AddCraftBagButton(ZO_GuildBankMenuBar, OnCraftBagButtonClicked)
end

local function TryTransferToBank(slotControl)

    local iBagId, iSlotIndex = ZO_Inventory_GetBagAndIndex(slotControl)
    
    -- Don't transfer if you don't have enough free slots in the guild bank
    if GetNumBagFreeSlots(BAG_GUILDBANK) < 1 then
        ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_SPACE_LEFT)
        return
    end
    
    -- Transfers from the crafting bag need to get put in a real stack in the 
    -- backpack first to avoid "Item no longer exists" errors
    if iBagId == BAG_VIRTUAL then
        -- Don't transfer if you don't have a free proxy slot in your backpack
        if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then
            ZO_AlertEvent(EVENT_INVENTORY_IS_FULL, 1, 0)
            return
        end
        local iProxySlotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
        local iStackSize, iMaxStackSize = GetSlotStackSize(iBagId, iSlotIndex)
        local iQuantity = math.min(iStackSize, iMaxStackSize)
        
        if IsProtectedFunction("RequestMoveItem") then
            CallSecureProtected("RequestMoveItem", iBagId, iSlotIndex, BAG_BACKPACK, iProxySlotIndex, iQuantity)
        else
            RequestMoveItem(iBagId, iSlotIndex, BAG_BACKPACK, iProxySlotIndex, iQuantity)
        end
        iBagId = BAG_BACKPACK
        iSlotIndex = iProxySlotIndex
    end
    
    TransferToGuildBank(iBagId, iSlotIndex)
end

local function MailToggle(buttonData, playerDriven)

    if MAIL_SEND_SCENE.state ~= SCENE_SHOWN then
        return
    end
    
    if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
        ZO_PlayerInventory:SetHidden(true)
        ZO_PlayerInventoryInfoBar:SetParent(ZO_CraftBag)
        SCENE_MANAGER:AddFragment(CRAFT_BAG_FRAGMENT)
        
    else
        SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
        ZO_PlayerInventoryInfoBar:SetParent(ZO_PlayerInventory)
        ZO_PlayerInventory:SetHidden(false)
    end
end

local function OnMailSendSceneStateChange(oldState, newState)
    if(newState ~= SCENE_SHOWN) then return end
    local button = CBE_MailSendMenu.m_object.m_clickedButton
    if not button then return end
    MailToggle(button.m_buttonData, false)
end
local function IsSendingMail()
    if MAIL_SEND and not MAIL_SEND:IsHidden() then
        return true
    elseif MAIL_MANAGER_GAMEPAD and MAIL_MANAGER_GAMEPAD:GetSend():IsAttachingItems() then
        return true
    end
    return false
end

-- If called on an item inventory slot, returns the index of the attachment slot that's holding it, or nil if it's not attached.
local function GetQueuedItemAttachmentSlotIndex(inventorySlot)
    local bag, attachmentIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if (bag) then
        for i = 1, MAIL_MAX_ATTACHED_ITEMS do
            local bagId, slotIndex = GetQueuedItemAttachmentInfo(i)
            if bagId == bag and attachmentIndex == slotIndex then
                return i
            end
        end
    end
end

local function IsItemAlreadyAttachedToMail(inventorySlot)
    local index = GetQueuedItemAttachmentSlotIndex(inventorySlot)
    if index then
        return GetQueuedItemAttachmentInfo(index) ~= 0
    end
end
local function RemoveQueuedAttachment(inventorySlot)
    local index = GetQueuedItemAttachmentSlotIndex(inventorySlot)
    RemoveQueuedItemAttachment(index)

    -- Update the keybind strip command
    ZO_InventorySlot_OnMouseEnter(inventorySlot)
end

local function TryMailItem(inventorySlot)
    if(IsSendingMail()) then
        for i = 1, MAIL_MAX_ATTACHED_ITEMS do
            local queuedFromBag = GetQueuedItemAttachmentInfo(i)

            if(queuedFromBag == 0) then
                local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
                local result = QueueItemAttachment(bag, index, i)

                if(result == MAIL_ATTACHMENT_RESULT_ALREADY_ATTACHED) then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_MAIL_ALREADY_ATTACHED))
                elseif(result == MAIL_ATTACHMENT_RESULT_BOUND) then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_MAIL_BOUND))
                elseif(result == MAIL_ATTACHMENT_RESULT_ITEM_NOT_FOUND) then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_MAIL_ITEM_NOT_FOUND))
                elseif(result == MAIL_ATTACHMENT_RESULT_LOCKED) then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_MAIL_LOCKED))
                elseif(result == MAIL_ATTACHMENT_RESULT_STOLEN) then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_STOLEN_ITEM_CANNOT_MAIL_MESSAGE))
                else
                    -- Update the keybind strip command
                    ZO_InventorySlot_OnMouseEnter(inventorySlot)
                end

                return true
            end
        end

        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_MAIL_ATTACHMENTS_FULL))
        return true
    end
end

local actionHandlers =
{
    ["mail_attach"]       = function(inventorySlot, slotActions)
                                    if IsSendingMail() and not IsItemAlreadyAttachedToMail(inventorySlot) then
                                        slotActions:AddSlotAction(SI_ITEM_ACTION_MAIL_ATTACH, function() TryMailItem(inventorySlot) end, "primary")
                                    end
                                end,

    ["mail_detach"]        = function(inventorySlot, slotActions)
                                    if IsSendingMail() and IsItemAlreadyAttachedToMail(inventorySlot) then
                                        slotActions:AddSlotAction(SI_ITEM_ACTION_MAIL_DETACH, function() RemoveQueuedAttachment(inventorySlot) end, "primary")
                                    end
                                end,
    ["guild_bank_deposit"] = function(inventorySlot, slotActions)
                                    if(GetInteractionType() == INTERACTION_GUILDBANK and GetSelectedGuildBankId()) then
                                        slotActions:AddSlotAction(SI_ITEM_ACTION_BANK_DEPOSIT,  function()
                                                                                                    TryTransferToBank(inventorySlot)
                                                                                                end, "primary")
                                    end
                                end
}

local function SetupSlotActions()
    
    ZO_PreHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", 
        function(inventorySlot, slotActions) 
            local slotType = ZO_InventorySlot_GetType(inventorySlot)
            if slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
                for _, actionHandler in pairs(actionHandlers) do
                    actionHandler(inventorySlot, slotActions)
                end
            end
        end
    )
end

local function OnAddonLoaded(event, name)
    if name ~= addon.name then return end
    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
    
    -- Save the original anchors
    RegisterAnchors()

    -- Wire up guild bank scene open/close events to adjust craft bag anchors
    local guildBankScene = SCENE_MANAGER.scenes["guildBank"]
    guildBankScene:RegisterCallback("StateChange",  OnGuildBankSceneStateChange)
    MAIL_SEND_SCENE:RegisterCallback("StateChange",  OnMailSendSceneStateChange)
    
    -- Wire up original guild bank buttons for tab changed event, and add new craft bag button
    SetupButtons()
    
    SetupSlotActions()
    
    local menuBar = CreateControlFromVirtual("CBE_MailSendMenu", ZO_MailSend, "ZO_LabelButtonBar")
    menuBar:SetAnchor(BOTTOMLEFT, ZO_MailSend, TOPLEFT, ZO_MailSend:GetWidth() - ZO_PlayerInventory:GetWidth() + 50, -12)
    AddItemsButton(menuBar, MailToggle)
    AddCraftBagButton(menuBar, MailToggle)
    ZO_MenuBar_SelectFirstVisibleButton(menuBar,true)
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

CBE = addon
