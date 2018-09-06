--- Entity
--

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


function ECSEntity:AddComponent(componentName, component)
    local otherComponent = self:GetComponent(componentName)

    if (otherComponent ~= nil) then
        self:_RemoveComponent(componentName, comp)
        otherComponent = nil
    end

    self:_AddComponent(componentName, component)
end


function ECSEntity:RemoveComponent(componentName)
    local component = self:GetComponent(componentName)

    if (component ~= nil) then
        self:_RemoveComponent(componentName, component)
    end
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

function ECSEntity:Update()
    for componentName, component in pairs(self._AddedComponents) do
        self:_InitializeComponent(component)
    end

    for componentName, component in pairs(self._RemovedComponents) do
        component:Destroy()
    end

    self._AddedComponents = {}
    self._RemovedComponents = {}
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
        self:RemoveComponent(componentName)
    end

    self:Update()

    if (self.Instance ~= nil) then
        self.Instance:Destroy()
        self.Instance = nil
    end

    self.World = nil
    self._Components = nil
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


    return self
end


return ECSEntity