CBE_SettingsController = ZO_Object:Subclass()

function CBE_SettingsController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

function CBE_SettingsController:Initialize()

    self.name = "CBE_SettingsController"
    self.defaults = {
        disableGuildBankWithdrawalAutoStash = false
    }
    self.settings = ZO_SavedVars:NewAccountWide("CraftBagExtended_Data", 1, nil, self.defaults)

    local LAM2 = LibStub("LibAddonMenu-2.0")
    if not LAM2 then return end

    local panelData = {
        type = "panel",
        name = CBE.title,
        displayName = CBE.title,
        author = CBE.author,
        version = CBE.version,
        slashCommand = "/craftbag",
        -- registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM2:RegisterAddonPanel(CBE.name, panelData)

    local optionsTable = {
        {
            type = "checkbox",
            name = GetString(SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH),
            tooltip = GetString(SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP),
            getFunc = function() return self.settings.disableGuildBankWithdrawalAutoStash end,
            setFunc = function(value) self.settings.disableGuildBankWithdrawalAutoStash = value end,
            default = self.defaults.disableGuildBankWithdrawalAutoStash,
        },
    }
    LAM2:RegisterOptionControls(CBE.name, optionsTable)
end
