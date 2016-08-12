local cbe        = CraftBagExtended
local util       = cbe.utility
local class      = cbe.classes
class.Controller = ZO_Object:Subclass()

function class.Controller:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end

local function SwapFragments(scene, removeFragment, addFragment, layoutFragment)
    scene:RemoveFragment(removeFragment)
    scene:RemoveFragment(layoutFragment)
    scene:AddFragment(addFragment)
    scene:AddFragment(layoutFragment)
end

--[[ Button click callback for toggling between backpack and craft bag. ]]
local function OnCraftBagMenuButtonClicked(buttonData, playerDriven)-- Do nothing on menu button clicks when not trading.
    local self = buttonData.menu.controller
    local scene = SCENE_MANAGER.scenes[self.sceneName]
    if scene.state ~= SCENE_SHOWN then
        return
    end
    if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
        if CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then return end
        SwapFragments(scene, INVENTORY_FRAGMENT, CRAFT_BAG_FRAGMENT, self.layoutFragment)
    elseif CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then
        SwapFragments(scene, CRAFT_BAG_FRAGMENT, INVENTORY_FRAGMENT, self.layoutFragment)
    end
end

function class.Controller:Initialize(name, sceneName, window, layoutFragment)

    self.name = name or cbe.name .. "Controller"
    self.sceneName = sceneName
    self.window = window
    self.layoutFragment = layoutFragment
    
    --[[ Create craft bag menu ]]
    self.menu = CreateControlFromVirtual(self.name.."Menu", self.window, "ZO_LabelButtonBar")
    self.menu.controller = self
    
    -- Items button
    util.AddItemsButton(self.menu, OnCraftBagMenuButtonClicked)
    
    -- Craft bag button
    util.AddCraftBagButton(self.menu, OnCraftBagMenuButtonClicked)
    
    -- Select items button
    ZO_MenuBar_SelectFirstVisibleButton(self.menu, true)
end