local cbe      = CraftBagExtended
local class    = cbe.classes
class.Settings = ZO_Object:Subclass()

local LibSavedVars = LibStub("LibSavedVars")

function class.Settings:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

function class.Settings:Initialize()

    self.name = cbe.name .. "Settings"
    self.defaults = {
        guildBankAutoStashOff = false,
        primaryActionsUseDefault = true
    }
    self.db = LibSavedVars:New(cbe.name .. "_Account", cbe.name .. "_Character", self.defaults, true)
    local legacyAccountSettings = ZO_SavedVars:NewAccountWide(cbe.name .. "_Data", 1)
    self.db:Migrate(legacyAccountSettings)


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
        registerForRefresh = true,
        registerForDefaults = true,
    }
    self.menuPanel = LAM2:RegisterAddonPanel(cbe.name .. "MenuPanel", panelData)

    local optionsTable = {
        
        -- Account wide settings checkbox
        self.db:GetLibAddonMenuAccountCheckbox(),
        
        -- Primary actions use default
        {
            type = "checkbox",
            name = GetString(SI_CBE_PRIMARY_ACTIONS_USE_DEFAULT),
            tooltip = GetString(SI_CBE_PRIMARY_ACTIONS_USE_DEFAULT_TOOLTIP),
            getFunc = function() return self.db.primaryActionsUseDefault end,
            setFunc = function(value) self.db.primaryActionsUseDefault = value end,
            default = self.defaults.primaryActionsUseDefault,
        },
    }
    LAM2:RegisterOptionControls(cbe.name .. "MenuPanel", optionsTable)
end

--[[ Retrieves a saved item transfer default quantity for a particular scope. ]]
function class.Settings:GetTransferDefault(scope, itemId, isDialog)
    if not self.db.primaryActionsUseDefault and not isDialog then
        return
    end
    local default
    if self.db.transferDefaults 
       and self.db.transferDefaults[scope] 
    then
        default = self.db.transferDefaults[scope][itemId]
    end
    return default
end

--[[ Saves an item transfer default quantity for a particular scope. ]]
function class.Settings:SetTransferDefault(scope, itemId, default)
    -- Save default in saved var
    if type(default) == "number" then
        if not self.db.transferDefaults then
            self.db.transferDefaults = {}
        end
        if not self.db.transferDefaults[scope] then
            self.db.transferDefaults[scope] = {}
        end
        self.db.transferDefaults[scope][itemId] = default
        
    -- Clear nil defaults, if set
    elseif self.db.transferDefaults 
       and self.db.transferDefaults[scope] 
       and self.db.transferDefaults[scope][itemId]
    then
        self.db.transferDefaults[scope][itemId] = nil
    end
end