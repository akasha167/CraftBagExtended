local cbe    = CraftBagExtended
local util   = cbe.utility
local class  = cbe.classes
class.Module = ZO_Object:Subclass()

function class.Module:New(...)
    local instance = ZO_Object.New(self)
    instance:Initialize(...)
    return instance
end

local function AddFragment(self, fragment)
    if not fragment then return end
    if self.isFragmentTemporary then
        SCENE_MANAGER:AddFragment(fragment)
    else
        self.scene:AddFragment(fragment)
    end
end

local function RemoveFragment(self, fragment)
    if not fragment then return end
    if self.isFragmentTemporary == nil then
        self.isFragmentTemporary = self.scene.temporaryFragments and self.scene.temporaryFragments[fragment]
    end
    if self.isFragmentTemporary then
        SCENE_MANAGER:RemoveFragment(fragment)
    else
        self.scene:RemoveFragment(fragment)
    end
end

local function SwapFragments(self, removeFragment, addFragment, layoutFragment)
    if cbe.fragmentGroup then
        SCENE_MANAGER:RemoveFragmentGroup(cbe.fragmentGroup)
        for i=1,#cbe.fragmentGroup do
            if cbe.fragmentGroup[i] == removeFragment then
                cbe.fragmentGroup[i] = addFragment
            end
        end
        SCENE_MANAGER:AddFragmentGroup(cbe.fragmentGroup)
    else
        RemoveFragment(self, layoutFragment)
        RemoveFragment(self, removeFragment)
        AddFragment(self, addFragment)
        AddFragment(self, layoutFragment)
    end
end

--[[ Button click callback for toggling between backpack and craft bag. ]]
local function OnCraftBagMenuButtonClicked(buttonData, playerDriven)-- Do nothing on menu button clicks when not trading.
    local self = buttonData.menu.craftBagExtendedModule
    if buttonData.menu:IsHidden() then
        return
    end
    if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
        if CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then return end
        SwapFragments(self, INVENTORY_FRAGMENT, CRAFT_BAG_FRAGMENT, self.layoutFragment)
    elseif CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then
        SwapFragments(self, CRAFT_BAG_FRAGMENT, INVENTORY_FRAGMENT, self.layoutFragment)
    end
end

local function OnCraftBagFragmentStateChange(oldState, newState)
    if newState ~= SCENE_FRAGMENT_SHOWN then return end
    
    local self = cbe.currentModule
    if not self then return end
    
    -- Show menu whenever the craft bag fragment is first shown
    self.menu:SetHidden(false)

    -- Select items button on the menu if not already selected
    if ZO_MenuBar_GetSelectedDescriptor(self.menu) ~= SI_INVENTORY_MODE_CRAFT_BAG then
        ZO_MenuBar_SelectDescriptor(self.menu, SI_INVENTORY_MODE_CRAFT_BAG)
    end
end
local function OnInventoryFragmentStateChange(oldState, newState)
    
    if newState ~= SCENE_FRAGMENT_SHOWN then return end
        
    local self = cbe.currentModule
    if not self then return end
    
    -- Show menu whenever the inventory fragment is first shown
    self.menu:SetHidden(false)

    -- Select items button on the menu if not already selected
    if ZO_MenuBar_GetSelectedDescriptor(self.menu) ~= SI_INVENTORY_MODE_ITEMS then
        ZO_MenuBar_SelectDescriptor(self.menu, SI_INVENTORY_MODE_ITEMS)
    end
    
    -- If the craft bag fragment is showing, hide it
    if not cbe.fragmentGroup then
        SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
    end
end

function class.Module:Initialize(name, sceneName, window, layoutFragment, hideMenuWhenSceneShown)

    self.name = name or cbe.name .. "Module"
    self.sceneName = sceneName
    self.scene = SCENE_MANAGER.scenes[sceneName]
    
    if not window or not self.scene then return end
    
    self.window = window
    self.layoutFragment = layoutFragment
    
    --[[ Create craft bag menu ]]
    self.menu = CreateControlFromVirtual(self.name.."Menu", self.window, "ZO_LabelButtonBar")
    self.menu.craftBagExtendedModule = self
    
    -- Items button
    util.AddItemsButton(self.menu, OnCraftBagMenuButtonClicked)
    
    -- Craft bag button
    util.AddCraftBagButton(self.menu, OnCraftBagMenuButtonClicked)
    
    -- Hide menu by default
    self.menu:SetHidden(true)
    
    --[[ Handle scene open close events ]]
    self.scene:RegisterCallback("StateChange", 
        function (oldState, newState)
            if newState == SCENE_HIDING then
                INVENTORY_FRAGMENT:UnregisterCallback("StateChange", OnInventoryFragmentStateChange)
                CRAFT_BAG_FRAGMENT:UnregisterCallback("StateChange", OnCraftBagFragmentStateChange)
                cbe.currentModule = nil
                cbe.fragmentGroup = nil
                self.menu:SetHidden(true)
            elseif newState == SCENE_SHOWING then
                INVENTORY_FRAGMENT:RegisterCallback("StateChange", OnInventoryFragmentStateChange)
                CRAFT_BAG_FRAGMENT:RegisterCallback("StateChange", OnCraftBagFragmentStateChange)
                cbe.currentModule = self
                self.menu:SetHidden(hideMenuWhenSceneShown)
            end
        end)
end

function class.Module:IsSceneShown()
    return self.scene and self.scene.state == SCENE_SHOWN
end

function class.Module.PreTabButtonClicked(buttonData, playerDriven)
    local self = buttonData.craftBagExtendedModule
    if buttonData.categoryName == self.tabName then
        self.menu:SetHidden(false)
    else
        self.menu:SetHidden(true)
        SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
    end
end