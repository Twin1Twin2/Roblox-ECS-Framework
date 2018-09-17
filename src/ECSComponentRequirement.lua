--- ComponentRequirement
-- To Do: Include ComponentGroup

local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsComponentDescription = Utilities.IsComponentDescription
local IsComponentGroup = Utilities.IsComponentGroup

local TableContains = Table.Contains
local AltMerge = Table.AltMerge


local function AddNameToListIfNotInOther(instanceName, name, list, listName, otherLists)
    -- make sure it isn't already in the other list
    for otherListName, otherList in pairs(otherLists) do
        if (TableContains(otherList, name) == true) then
            warn("ComponentRequirement - " .. instanceName .. "Unable to add \"" .. name .. "\" to list \"" .. listName .. "\"! Already in list \"" .. otherListName .. "\"!")
            return
        end
    end

    if (TableContains(list, name) == false) then
        table.insert(list, name)
    end
end


local function AddComponentNamesToList(instanceName, componentNames, list, listName, otherLists)
    for index, component in pairs(componentNames) do
        if (IsComponentGroup(component) == true) then
            AddComponentNamesToList(instanceName, component:GetComponentList(), list, listName, otherLists)
        end

        local componentName = nil

        if (IsComponentDescription(component) == true) then
            componentName = component.ComponentName
        elseif (component == true) then
            componentName = index
        elseif (type(component) == "string") then
            componentName = component
        end

        if (componentName ~= nil) then
            AddNameToListIfNotInOther(instanceName, componentName, list, listName, otherLists)
        end
    end
end


local ECSComponentRequirement = {
    ClassName = "ECSComponentRequirement";
}

ECSComponentRequirement.__index = ECSComponentRequirement


function ECSComponentRequirement:GetComponentList()
    local componentList = {}

    AltMerge(componentList, self.AllList)
    AltMerge(componentList, self.OneList)
    AltMerge(componentList, self.ExcludeList)


    return componentList
end


function ECSComponentRequirement:EntityBelongs(entity)
    local hasChecked = false

    if (#self.ExcludeList > 0) then
        for _, componentName in pairs(self.ExcludeList) do
            if (entity:HasComponent(componentName) == true) then
                return false
            end
        end

        hasChecked = true
    end

    if (#self.AllList > 0) then
        for _, componentName in pairs(self.AllList) do
            if (entity:HasComponent(componentName) == false) then
                return false
            end
        end

        hasChecked = true
    end

    if (#self.OneList > 0) then
        for _, componentName in pairs(self.OneList) do
            if (entity:HasComponent(componentName) == true) then
                return true
            end
        end
    end

    return hasChecked
end


-- Adding/Setting Components


function ECSComponentRequirement:All(...)
    return self:AllFromList({...})
end


function ECSComponentRequirement:AllFromList(list)
    if (type(list) == "table") then
        AddComponentNamesToList(self.Name, list, self.AllList, "All", { Exclude = self.ExcludeList })
    end

    return self     -- for chaining
end


function ECSComponentRequirement:One(...)
    return self:OneFromList({...})
end


function ECSComponentRequirement:OneFromList(list)
    if (type(list) == "table") then
        AddComponentNamesToList(self.Name, list, self.OneList, "One", { Exclude = self.ExcludeList })
    end

    return self     -- for chaining
end


function ECSComponentRequirement:Exclude(...)
    return self:ExcludeFromList({...})
end


function ECSComponentRequirement:ExcludeFromList(list)
    if (type(list) == "table") then
        AddComponentNamesToList(self.Name, list, self.ExcludeList, "Exclude", { All = self.AllList; One = self.OneList; })
    end

    return self     -- for chaining
end


function ECSComponentRequirement:Set(allList, oneList, excludeList)
    self:AllFromList(allList):OneFromList(oneList):ExcludeFromList(excludeList)
end


-- Constructor/Deconstructor

function ECSComponentRequirement:Destroy()
    self.AllList = nil
    self.OneList = nil
    self.ExcludeList = nil

    setmetatable(self, nil)
end


function ECSComponentRequirement.new(name)
    local self = setmetatable({}, ECSComponentRequirement)

    self.Name = name or "COMPONENT_LIST"

    self.AllList = {}
    self.OneList = {}
    self.ExcludeList = {}

    self._IsComponentRequirement = true


    return self
end


return ECSComponentRequirement