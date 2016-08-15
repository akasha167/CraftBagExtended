for stringId, value in pairs(CRAFTBAGEXTENDED_STRINGS) do
    local stringValue
    if type(value) == "table" then
        for i=2,#value do
            if type(value[i]) == "string" then
                value[i] = _G[value[i]]
            end
            value[i] = GetString(value[i])
        end
        stringValue = zo_strformat(unpack(value))
    else
        stringValue = value
    end
    ZO_CreateStringId(stringId, stringValue)
end
CRAFTBAGEXTENDED_STRINGS = nil

-- Addon title
ZO_CreateStringId("SI_CBE", "|c99CCEFCraft Bag Extended|r")

-- Combine the built-in "Deposit" and "Quantity" terms,
ZO_CreateStringId("SI_CBE_CRAFTBAG_BANK_DEPOSIT", 
    GetString(SI_ITEM_ACTION_BANK_DEPOSIT)
    ..GetString(SI_CBE_WORD_BREAK)
    ..GetString(SI_TRADING_HOUSE_POSTING_QUANTITY))
    
-- Combine the built-in "Add" and "Quantity" terms
ZO_CreateStringId("SI_CBE_CRAFTBAG_MAIL_ATTACH", 
    GetString(SI_GAMEPAD_MAIL_SEND_ATTACH_ITEM)
    ..GetString(SI_CBE_WORD_BREAK)
    ..GetString(SI_TRADING_HOUSE_POSTING_QUANTITY))
    
-- Combine the built-in "Add" and "Quantity" terms
ZO_CreateStringId("SI_CBE_CRAFTBAG_TRADE_ADD", 
    GetString(SI_GAMEPAD_TRADE_ADD)
    ..GetString(SI_CBE_WORD_BREAK)
    ..GetString(SI_TRADING_HOUSE_POSTING_QUANTITY))