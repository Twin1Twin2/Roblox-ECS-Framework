--- Need to rename
-- To Do: Include ComponentGroup

local Table = require(script.Parent.Table)

local AltMerge = Table.AltMerge


local ECSComponentList = {
    ClassName = "ECSComponentList";
}

ECSComponentList.__index = ECSComponentList


function ECSComponentList:GetComponentList()
    local componentList = {}

    AltMerge(componentList, self.AllList)
    AltMerge(componentList, self.OneList)
    AltMerge(componentList, self.ExcludeList)


    return componentList
end


function ECSComponentList:EntityBelongs(entity)
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

function ECSComponentList:Add(...)


    return self
end


function ECSComponentList:One(...)


    return self
end


function ECSComponentList:Exclude(...)
    

    return self
end


-- Constructor/Deconstructor

function ECSComponentList:Destroy()
    self.AllList = nil
    self.OneList = nil
    self.ExcludeList = nil

    setmetatable(self, nil)
end


function ECSComponentList.new(name)
    local self = setmetatable({}, ECSComponentList)

    self.ListName = name or "COMPONENT_LIST"

    self.AllList = {}
    self.OneList = {}
    self.ExcludeList = {}


    return self
end


return ECSComponentList