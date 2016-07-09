local addon = {
	name = "CraftBagExtended",
	title = GetString(SI_CBE),
	author = "|c99CCEFsilvereyes|r",
	version = "1.0.0"
}

-- Output formatted message to chat window, if configured
local function pOutput(input)
	local output = zo_strformat("<<1>>|cFFFFFF: <<2>>|r", addon.title, input)
	d(output)
end

local function OnAddonLoaded(event, name)
	if name ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

CBE = addon
