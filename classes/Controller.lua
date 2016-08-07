CBE_Controller = ZO_Object:Subclass()

function CBE_Controller:New(...)
    local controller = ZO_Object.New(self)
    controller:Initialize(...)
    return controller
end
function CBE_Controller:Initialize(name, sceneName, window, layoutFragment)

    self.name = name
    self.sceneName = sceneName
    self.window = window
    self.layoutFragment = layoutFragment
    
    --[[ Create craft bag menu ]]
    self.menu = CreateControlFromVirtual(self.name.."Menu", self.window, "ZO_LabelButtonBar")
    self.menu.controller = self
    CBE:AddItemsButton(self.menu, CBE_Controller_OnCraftBagMenuButtonClicked)
    CBE:AddCraftBagButton(self.menu, CBE_Controller_OnCraftBagMenuButtonClicked)
    ZO_MenuBar_SelectFirstVisibleButton(self.menu, true)
end

local function SwapFragments(scene, removeFragment, addFragment, layoutFragment)
    scene:RemoveFragment(removeFragment)
    scene:RemoveFragment(layoutFragment)
    scene:AddFragment(addFragment)
    scene:AddFragment(layoutFragment)
end

--[[ Button click callback for toggling between backpack and craft bag. ]]
function CBE_Controller_OnCraftBagMenuButtonClicked(buttonData, playerDriven)-- Do nothing on menu button clicks when not trading.
    local self = buttonData.menu.controller
    local scene = SCENE_MANAGER.scenes[self.sceneName]
    if scene.state ~= SCENE_SHOWN then
        return
    end
    if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
        if CRAFT_BAG_FRAGMENT.state == "shown" then return end
        SwapFragments(scene, INVENTORY_FRAGMENT, CRAFT_BAG_FRAGMENT, self.layoutFragment)
    elseif CRAFT_BAG_FRAGMENT.state == "shown" then
        SwapFragments(scene, CRAFT_BAG_FRAGMENT, INVENTORY_FRAGMENT, self.layoutFragment)
    end
end