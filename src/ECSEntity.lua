--- Entity
--

local Table = require(script.Parent.Table)

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable


local ECSEntity = {
    ClassName = "ECSEntity";
}

ECSEntity.__index = ECSEntity


function ECSEntity:ContainsInstance(instance)
    local selfInstance = self.Instance
    return selfInstance ~= nil and (selfInstance == instance or selfInstance:IsAncestorOf(instance))
end


function ECSEntity:CopyData()
    local data = {}

    for componentName, component in pairs(self._Components) do
        if (component ~= nil) then
            local componentData = component:CopyData()
            data[componentName] = componentData
        end
    end

    return data
end


-- Component

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


function ECSEntity:GetComponent(componentName)
    return self._Components[componentName] or self._RemovedComponents[componentName]
end


function ECSEntity:_InitializeComponent(component)
    component:Initialize(self, self.World)
end


function ECSEntity:_AddComponent(componentName, component)
    self._Components[componentName] = component
    self._AddedComponents[componentName] = component
end


function ECSEntity:_RemoveComponent(componentName, component)
    self._Components[componentName] = nil
    self._RemovedComponents[componentName] = component
end


function ECSEntity:AddComponentToEntity(componentName, component)
    local otherComponent = self:GetComponent(componentName)

    if (otherComponent ~= nil) then
        self:_RemoveComponent(componentName, comp)
        otherComponent = nil
    end

    self:_AddComponent(componentName, component)
end


function ECSEntity:RemoveComponentFromEntity(componentName)
    local component = self:GetComponent(componentName)

    if (component ~= nil) then
        self:_RemoveComponent(componentName, component)
    end
end


function ECSEntity:AddComponents(componentList)
    self.World:AddComponentsToEntity(self, componentList)
end


function ECSEntity:RemoveComponents(...)
    local componentList = {...}

    if (type(componentList[1]) == "table") then
        componentList = componentList[1]
    end

    self.World:RemoveComponentsFromEntity(self, componentList)
end


--System

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


-- Update

function ECSEntity:UpdateAddedComponents()
    for componentName, component in pairs(self._AddedComponents) do
        self:_InitializeComponent(component)
    end

    self._AddedComponents = {}
end


function ECSEntity:UpdateRemovedComponents()
    for componentName, component in pairs(self._RemovedComponents) do
        component:Destroy()
    end
    
    self._RemovedComponents = {}
end


function ECSEntity:Update()
    self:UpdateAddedComponents()
    self:UpdateRemovedComponents()
end


-- Constructor/Destructor

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

    for componentName, _ in pairs(self._Components) do
        self:_RemoveComponent(componentName, nil)
    end

    self:Update()

    if (self.Instance ~= nil) then
        self.Instance:Destroy()
        self.Instance = nil
    end

    self.World = nil
    self._Components = nil
    self._AddedComponents = nil
    self._RemovedComponents = nil
    self._RegisteredSystems = nil
    

    setmetatable(self, nil)
end


function ECSEntity.new(instance)
    if (instance == nil) then
        instance = Instance.new("Model")
    end

    assert(typeof(instance) == "Instance")


    local self = setmetatable({}, ECSEntity)

    self.Instance = instance

    self.World = nil

    self._Components = {}
    self._AddedComponents = {}
    self._RemovedComponents = {}
    self._RegisteredSystems = {}

    self._IsServerSide = nil
    
    self._IsBeingRemoved = false
    self._IsBeingDestroyed = false
    self._IsBeingUpdated = false

    self._IsEntity = true


    return self
end


return ECSEntity