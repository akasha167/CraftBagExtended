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

local function IsShown(self)
    if self.tabMenuBar and self.tabName then
        return self.tabMenuBar.m_object.m_clickedButton.m_buttonData.categoryName == self.tabName
    else
        return self:IsSceneShown()
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
    if self.fragmentGroup then
        SCENE_MANAGER:RemoveFragmentGroup(self.fragmentGroup)
        for i=1,#self.fragmentGroup do
            if self.fragmentGroup[i] == removeFragment then
                self.fragmentGroup[i] = addFragment
            end
        end
        SCENE_MANAGER:AddFragmentGroup(self.fragmentGroup)
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
    if not IsShown(self) then
        return
    end
    if buttonData.descriptor == SI_INVENTORY_MODE_CRAFT_BAG then
        if CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then return end
        SwapFragments(self, INVENTORY_FRAGMENT, CRAFT_BAG_FRAGMENT, self.layoutFragment)
    elseif CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then
        SwapFragments(self, CRAFT_BAG_FRAGMENT, INVENTORY_FRAGMENT, self.layoutFragment)
    end
end

function class.Module:Initialize(name, sceneName, window, layoutFragment, tabMenuBar, tabName)

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
    
    -- Select items button
    ZO_MenuBar_SelectFirstVisibleButton(self.menu, true)
    
    -- Hide menu by default
    self.menu:SetHidden(true)
    
    --[[ Handle scene open close events ]]
    self.scene:RegisterCallback("StateChange", 
        function (oldState, newState)
            if newState == SCENE_HIDING then
                self.menu:SetHidden(true)
            elseif newState == SCENE_SHOWING then
                local hide = self.tabMenuBar and self.tabName 
                             and self.tabMenuBar.m_object.m_clickedButton.m_buttonData.categoryName ~= self.tabName
                self.menu:SetHidden(hide)
                if hide and not self.fragmentGroup then
                    SCENE_MANAGER:RemoveFragment(CRAFT_BAG_FRAGMENT)
                end
            end
        end)
    
    if not tabMenuBar or not tabName then
        return
    end
    self.tabMenuBar = tabMenuBar
    self.tabName = tabName
    
    for i,tabButtonInfo in ipairs(self.tabMenuBar.m_object.m_buttons) do
        local control = tabButtonInfo[1]
        local tabButtonData = control.m_object.m_buttonData
        tabButtonData.craftBagExtendedModule = self
        util.PreHookCallback(tabButtonData, "callback", self.PreTabButtonClicked)
    end
    self.sceneManagerAddFragmentGroup = SCENE_MANAGER.AddFragmentGroup
    ZO_PreHook(SCENE_MANAGER, "AddFragmentGroup", 
        function(sceneManager, fragmentGroup)
            if not self.menu:IsHidden() then
                self.fragmentGroup = fragmentGroup
                sceneManager.AddFragmentGroup = self.sceneManagerAddFragmentGroup
                self.sceneManagerAddFragmentGroup = nil
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