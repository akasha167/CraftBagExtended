local cbe      = CraftBagExtended
local class    = cbe.classes
class.Settings = ZO_Object:Subclass()

function class.Settings:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

function class.Settings:Initialize()

    self.name = cbe.name .. "Settings"
    self.defaults = {
        guildBankAutoStashOff = false
    }
    self.db = ZO_SavedVars:NewAccountWide("CraftBagExtended_Data", 1, nil, self.defaults)

    local LAM2 = LibStub("LibAddonMenu-2.0")
    if not LAM2 then return end

    local panelData = {
        type = "panel",
        name = cbe.title,
        displayName = cbe.title,
        author = cbe.author,
        version = cbe.version,
        website = "http://www.esoui.com/downloads/info1419-CraftBagExtended.htm",
        slashCommand = "/craftbag",
        -- registerForRefresh = true,
        registerForDefaults = true,
    }
    self.menuPanel = LAM2:RegisterAddonPanel(cbe.name .. "MenuPanel", panelData)

    local optionsTable = {
        {
            type = "checkbox",
            name = GetString(SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH),
            tooltip = GetString(SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP),
            getFunc = function() return self.db.guildBankAutoStashOff end,
            setFunc = function(value) self.db.guildBankAutoStashOff = value end,
            default = self.defaults.guildBankAutoStashOff,
        },
    }
    LAM2:RegisterOptionControls(cbe.name .. "MenuPanel", optionsTable)
end

--[[ Retrieves a saved item transfer dialog default quantity for a particular scope. ]]
function class.Settings:GetDialogDefault(scope, itemId)
    local default
    if self.db.dialogDefaults 
       and self.db.dialogDefaults[scope] 
    then
        default = self.db.dialogDefaults[scope][itemId]
    end
    return default
end

--[[ Saves an item transfer dialog default quantity for a particular scope. ]]
function class.Settings:SetDialogDefault(scope, itemId, default)
    -- Save default in saved var
    if type(default) == "number" then
        if not self.db.dialogDefaults then
            self.db.dialogDefaults = {}
        end
        if not self.db.dialogDefaults[scope] then
            self.db.dialogDefaults[scope] = {}
        end
        self.db.dialogDefaults[scope][itemId] = default
        
    -- Clear nil defaults, if set
    elseif self.db.dialogDefaults 
       and self.db.dialogDefaults[scope] 
       and self.db.dialogDefaults[scope][itemId]
    then
        self.db.dialogDefaults[scope][itemId] = nil
    end
end