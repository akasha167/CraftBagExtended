CBE_SettingsController = ZO_Object:Subclass()

function CBE_SettingsController:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

local me

function CBE_SettingsController:Initialize()

    me = self
    me.name = "CBE_SettingsController"
	me.defaults = {
		disableGuildBankWithdrawalAutoStash = false
	}
	me.settings = ZO_SavedVars:NewAccountWide("CraftBagExtended_Data", 1, nil, me.defaults)

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
			getFunc = function() return me.settings.disableGuildBankWithdrawalAutoStash end,
			setFunc = function(value) me.settings.disableGuildBankWithdrawalAutoStash = value end,
			default = me.defaults.disableGuildBankWithdrawalAutoStash,
		},
	}
	LAM2:RegisterOptionControls(CBE.name, optionsTable)
end
