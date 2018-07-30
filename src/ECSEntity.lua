
local Table = require(script.Parent.Table)

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable


local ECSEntity = {
    ClassName = "ECSEntity";
}

ECSEntity.__index = ECSEntity


function ECSEntity:HasComponent(componentName)
    return (self._Components[componentName] ~= nil)
end


function ECSEntity:HasComponents(...)
    local components = {...}
    local hasAllComponents = true

    if (type(components[1]) == "table") then
        components = components[1]
    end

    if (#components == 0) then
        return false
    end

    for _, componentName in pairs(components) do
        if (self:HasComponent(componentName) == false) then
            hasAllComponents = false
        end
    end

    return hasAllComponents
end


function ECSEntity:ContainsInstance(instance) --redo
    if (self.Instance ~= nil) then
        return self.Instance:IsAncestorOf(instance)
    end

    return false
end


function ECSEntity:GetRegisteredSystems()
    return self._RegisteredSystems
end


function ECSEntity:GetComponent(componentName)
    return self._Components[componentName]
end


function ECSEntity:_AddComponent(componentName, component)
    self._Components[componentName] = component
end


function ECSEntity:AddComponent(componentName, component)
    assert(type(componentName) == "string")
    assert(type(component) == "table" and component._IsComponent == true)

    local comp = self:GetComponent(componentName)

    if (comp ~= nil) then
        self:_RemoveComponent(componentName, comp)
        comp = nil
    end

    self:_AddComponent(componentName, component)
end


function ECSEntity:_RemoveComponent(componentName, component)
    self._Components[componentName] = nil

    component:Destroy()
end


function ECSEntity:RemoveComponent(componentName)
    local component = self:GetComponent(componentName)

    if (component ~= nil) then
        self:_RemoveComponent(componentName, component)
    end
end


function ECSEntity:RegisterSystem(system)
    local systemName = system.ClassName

    if (TableContains(self._RegisteredSystems, systemName) == false) then
        table.insert(self._RegisteredSystems, systemName)
    end
end


function ECSEntity:UnregisterSystem(system)
    AttemptRemovalFromTable(self._RegisteredSystems, system.ClassName)

    if (self._IsBeingRemoved == true) then
        if (#self._RegisteredSystems == 0) then
            if (self.World ~= nil) then
                self.World:ForceRemoveEntity(self)
            end
        end
    end
end


--Tag System

function ECSEntity:HasTag(tagName)
    return TableContains(self._Tags, tagName)
end


function ECSEntity:HasTags(...)
    local tags = {...}
    local hasAllTags = true

    if (type(tags[1]) == "table") then
        tags = tags[1]
    end

    if (#tags == 0) then
        return false
    end

    for _, tagName in pairs(tags) do
        if (self:HasTag(tagName) == false) then
            hasAllTags = false
        end
    end

    return hasAllTags
end


function ECSEntity:AddTag(tagName)
    assert(type(tagName) == "string")

    if (TableContains(self._Tags, tagName) == false) then
        table.insert(self._Tags, tagName)
    end
end


function ECSEntity:AddTags(...)
    local tags = {...}

    self:AddTagsFromList(tags)
end


function ECSEntity:AddTagsFromList(tags)
    assert(type(tags) == "table")

    for _, tagName in pairs(tags) do
        self:AddTag(tagName)
    end
end


function ECSEntity:RemoveTag(tagName)
    assert(type(tagName) == "string")

    AttemptRemovalFromTable(self._Tags, tagName)
end


function ECSEntity:RemoveTags(...)
    local tags = {...}

    self:RemoveTagsFromList(tags)
end


function ECSEntity:RemoveTagsFromList(tags)
    assert(type(tags) == "table")

    for _, tagName in pairs(tags) do
        self:RemoveTag(tagName)
    end
end


function ECSEntity:RemoveSelf()
    if (self.World ~= nil) then
        self.World:RemoveEntity(self)
    end
end


function ECSEntity:Destroy()
    for componentName, component in pairs(self._Components) do
        self:RemoveComponent(componentName, component)
    end

    if (self.Instance ~= nil) then
        self.Instance:Destroy()
    end

    self.World = nil
    self._Components = nil
    self._RegisteredSystems = nil
    

    setmetatable(self, nil)
end


function ECSEntity.new(instance, tags)
    if (instance == nil) then
        instance = Instance.new("Model")
    end

    assert(typeof(instance) == "Instance")
    assert(tags == nil or type(tags) == "table")

    local self = setmetatable({}, ECSEntity)

    self.Instance = instance

    self.World = nil

    self._Components = {}
    self._RegisteredSystems = {}

    self._Tags = {}

    self._IsBeingRemoved = false    --flag

    if (tags ~= nil) then
        self:AddTagsFromList(tags)
    end


    return self
end


return ECSEntity