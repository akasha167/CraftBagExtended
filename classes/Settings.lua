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
        primaryActionsUseDefault = true,
        useAccountSettings = true,
    }
    local legacyAccountSettings = ZO_SavedVars:NewAccountWide(cbe.name .. "_Data", 1)
    LibSavedVars:Init(self, cbe.name .. "_Account", cbe.name .. "_Character", 
                      self.defaults, nil, legacyAccountSettings, true)


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
        LibSavedVars:GetLibAddonMenuSetting(self, self.defaults.useAccountSettings),
        {
            type = "checkbox",
            name = GetString(SI_CBE_PRIMARY_ACTIONS_USE_DEFAULT),
            tooltip = GetString(SI_CBE_PRIMARY_ACTIONS_USE_DEFAULT_TOOLTIP),
            getFunc = function() return LibSavedVars:Get(self, "primaryActionsUseDefault") end,
            setFunc = function(value) LibSavedVars:Set(self, "primaryActionsUseDefault", value) end,
            default = self.defaults.primaryActionsUseDefault,
        },
    }
    LAM2:RegisterOptionControls(cbe.name .. "MenuPanel", optionsTable)
end

--[[ Retrieves a saved item transfer default quantity for a particular scope. ]]
function class.Settings:GetTransferDefault(scope, itemId, isDialog)
    if not LibSavedVars:Get(self, "primaryActionsUseDefault") and not isDialog then
        return
    end
    local default
    if LibSavedVars:Get(self, "transferDefaults")
       and LibSavedVars:Get(self, "transferDefaults")[scope] 
    then
        default = LibSavedVars:Get(self, "transferDefaults")[scope][itemId]
    end
    return default
end

--[[ Saves an item transfer default quantity for a particular scope. ]]
function class.Settings:SetTransferDefault(scope, itemId, default)
    -- Save default in saved var
    if type(default) == "number" then
        if not LibSavedVars:Get(self, "transferDefaults") then
            LibSavedVars:Set(self, "transferDefaults", {})
        end
        if not LibSavedVars:Get(self, "transferDefaults")[scope] then
            LibSavedVars:Get(self, "transferDefaults")[scope] = {}
        end
        LibSavedVars:Get(self, "transferDefaults")[scope][itemId] = default
        
    -- Clear nil defaults, if set
    elseif LibSavedVars:Get(self, "transferDefaults") 
       and LibSavedVars:Get(self, "transferDefaults")[scope] 
       and LibSavedVars:Get(self, "transferDefaults")[scope][itemId]
    then
        LibSavedVars:Get(self, "transferDefaults")[scope][itemId] = nil
    end
end