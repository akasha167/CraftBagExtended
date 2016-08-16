local cbe    = CraftBagExtended
local util   = cbe.utility
local class  = cbe.classes
class.Module = ZO_Object:Subclass()

function class.Module:New(...)
    local instance = ZO_Object.New(self)
    instance:Initialize(...)
    return instance
end

local function IsShown(self)
    if self.tabMenuBar and self.tabName then
        return self.tabMenuBar.m_object:GetSelectedDescriptor() == self.tabName
    else
        return self:IsSceneShown()
    end
end

local function ReplaceKeybind(self)
    if not self.keybindButtonGroup or not self.keybindButtonToRemove then 
        return 
    end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindButtonGroup)
    table.insert(self.keybindButtonGroup, self.keybindButtonToRemove)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindButtonGroup)
end

local function RemoveKeybind(self)
    if not self.keybindButtonGroup or not self.keybindButtonToRemove then 
        return 
    end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindButtonGroup)
    for i=#self.keybindButtonGroup,1,-1 do
        local keybindButton = self.keybindButtonGroup[i]
        if keybindButton == self.keybindButtonToRemove then
            table.remove(self.keybindButtonGroup, i)
            break;
        end
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindButtonGroup)
end

local function SwapFragments(self, removeFragment, addFragment, layoutFragment)
    local scene = SCENE_MANAGER.scenes[self.sceneName]
    if self.fragmentGroup then
        SCENE_MANAGER:RemoveFragmentGroup(self.fragmentGroup)
        for i=1,#self.fragmentGroup do
            if self.fragmentGroup[i] == removeFragment then
                self.fragmentGroup[i] = addFragment
            end
        end
        SCENE_MANAGER:AddFragmentGroup(self.fragmentGroup)
    else
        scene:RemoveFragment(removeFragment)
        scene:RemoveFragment(layoutFragment)
        scene:AddFragment(addFragment)
        scene:AddFragment(layoutFragment)
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
        RemoveKeybind(self)
        SwapFragments(self, INVENTORY_FRAGMENT, CRAFT_BAG_FRAGMENT, self.layoutFragment)
    elseif CRAFT_BAG_FRAGMENT.state == SCENE_FRAGMENT_SHOWN then
        SwapFragments(self, CRAFT_BAG_FRAGMENT, INVENTORY_FRAGMENT, self.layoutFragment)
        ReplaceKeybind(self)
    end
end

local function PreTabButtonClicked(buttonData, playerDriven)
    local self = buttonData.craftBagExtendedModule
    if buttonData.descriptor == self.tabName then
        self.menu:SetHidden(false)
    else
        self.menu:SetHidden(true)
    end
end

function class.Module:Initialize(name, sceneName, window, layoutFragment, tabMenuBar, tabName, keybindButtonGroup, keybindToRemove)

    self.name = name or cbe.name .. "Module"
    self.sceneName = sceneName
    
    if not window then return end
    
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
    SCENE_MANAGER.scenes[self.sceneName]:RegisterCallback("StateChange", 
        function (oldState, newState)
            if newState == SCENE_HIDING then
                self.menu:SetHidden(true)
            elseif newState == SCENE_SHOWING then
                if self.tabMenuBar and self.tabName and self.tabMenuBar.m_object:GetSelectedDescriptor() ~= self.tabName then
                    return
                end
                self.menu:SetHidden(false)
            end
        end)
    
    if not tabMenuBar or not tabName then
        return
    end
    self.tabMenuBar = tabMenuBar
    self.tabName = tabName
    if keybindButtonGroup and keybindToRemove then
        self.keybindButtonGroup = keybindButtonGroup
        for i, keybindButton in ipairs(keybindButtonGroup) do
            if keybindButton.keybind == keybindToRemove then
                self.keybindButtonToRemove = keybindButton
                break
            end
        end
    end
    for i,tabButtonInfo in ipairs(self.tabMenuBar.m_object.m_buttons) do
        local control = tabButtonInfo[1]
        local tabButtonData = control.m_object.m_buttonData
        tabButtonData.craftBagExtendedModule = self
        util.PreHookCallback(tabButtonData, "callback", PreTabButtonClicked)
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
    local scene = SCENE_MANAGER.scenes[self.sceneName]
    return scene.state == SCENE_SHOWN
end