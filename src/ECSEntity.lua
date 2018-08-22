
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


function ECSEntity:ContainsInstance(instance)
    if (self.Instance ~= nil) then
        return self.Instance == instance or self.Instance:IsAncestorOf(instance)
    end

    return false
end


function ECSEntity:GetRegisteredSystems()
    return self._RegisteredSystems
end


function ECSEntity:GetComponent(componentName)
    return self._Components[componentName] or self._RemovedComponents[componentName]
end


function ECSEntity:_InitializeComponent(component)
    component:Initialize(self, self.World)
end


function ECSEntity:InitializeComponents()
    for _, component in pairs(self._Components) do
        if (component._IsInitialized == false) then
            self:_InitializeComponent(component)
        end
    end
end


function ECSEntity:_AddComponent(componentName, component)
    self._Components[componentName] = component
end


function ECSEntity:AddComponent(componentName, component, initializeComponent)
    assert(type(componentName) == "string")
    assert(type(component) == "table" and component._IsComponent == true)

    local comp = self:GetComponent(componentName)

    if (comp ~= nil) then
        self:_RemoveComponent(componentName, comp)
        comp = nil
    end

    self:_AddComponent(componentName, component)

    if (initializeComponent ~= false) then
        self:_InitializeComponent(component)
    end
end


function ECSEntity:_RemoveComponent(componentName, component)
    self._Components[componentName] = nil
    self._RemovedComponents[componentName] = component
end


function ECSEntity:RemoveComponent(componentName)
    local component = self:GetComponent(componentName)

    if (component ~= nil) then
        self:_RemoveComponent(componentName, component)
    end
end


function ECSEntity:RegisterSystem(systemName)
    if (TableContains(self._RegisteredSystems, systemName) == false) then
        table.insert(self._RegisteredSystems, systemName)
    end
end


function ECSEntity:UnregisterSystem(systemName)
    AttemptRemovalFromTable(self._RegisteredSystems, systemName)

    if (self._IsBeingRemoved == true and #self._RegisteredSystems == 0) then
        if (self.World ~= nil) then
            self.World:ForceRemoveEntity(self)
        else
            pcall(function()
                self:Destroy()
            end)
        end
    end
end


--Tag System

function ECSEntity:GetTags()
    return self._Tags
end


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


function ECSEntity:Update()
    for componentName, component in pairs(self._RemovedComponents) do
        component:Destroy()
    end

    self._RemovedComponents = {}
end


function ECSEntity:RemoveSelf()
    if (self.World ~= nil) then
        self.World:RemoveEntity(self)
    end
end


function ECSEntity:Destroy()
    if (self._IsBeingDestroyed == true) then
        return
    end

    self._IsBeingDestroyed = true

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


function ECSEntity.new(world, instance, tags)
    if (instance == nil) then
        instance = Instance.new("Model")
    end

    assert(typeof(instance) == "Instance")
    assert(tags == nil or type(tags) == "table")

    local self = setmetatable({}, ECSEntity)

    self.Instance = instance

    self.World = world
    --self.ParentEntity = nil
    --self.ChildrenEntities = {}

    self._Components = {}
    self._RemovedComponents = {}
    self._RegisteredSystems = {}

    self._Tags = {}

    self._IsServerSide = false
    
    self._IsBeingRemoved = false    --flag
    self._IsBeingDestroyed = false

    if (tags ~= nil) then
        self:AddTagsFromList(tags)
    end


    return self
end


return ECSEntity