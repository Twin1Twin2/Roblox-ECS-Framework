--- World
--
--

local RunService = game:GetService("RunService")

local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsEntity = Utilities.IsEntity
local IsComponent = Utilities.IsComponent
local IsComponentDescription = Utilities.IsComponentDescription
local IsSystem = Utilities.IsSystem
local GetEntityInstancesFromInstance = Utilities.GetEntityInstancesFromInstance
local MergeComponentData = Utilities.MergeComponentData

local TableCopy = Table.Copy
local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable


local ECSWorld = {
    ClassName = "ECSWorld";
}

ECSWorld.__index = ECSWorld


--Entities

function ECSWorld:HasEntity(entity)
    assert(IsEntity(entity) == true)

    return TableContains(self._Entities, entity)
end


function ECSWorld:GetEntityFromInstance(instance)
    assert(typeof(instance) == "Instance")
    return self._Entities[instance]
end


function ECSWorld:GetEntityContainingInstance(instance) --need to redo
    assert(typeof(instance) == "Instance")

    local currentEntity = nil

    for _, entity in pairs(self._Entities) do
        if (entity:ContainsInstance(instance) == true) then
            if (currentEntity ~= nil) then
                if (currentEntity.Instance:IsAncestorOf(entity.Instance) == true) then
                    currentEntity = entity
                end
            else
                currentEntity = entity
            end
        end
    end

    return currentEntity
end


function ECSWorld:WaitForEntityWithInstance(instance, maxWaitTime)   --idk how to do this, but this will do
    assert(typeof(instance) == "Instance")
    assert(maxWaitTime == nil or (type(maxWaitTime) == "number" and maxWaitTime >= 0), "Invalid Arg [2]")

    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        return entity
    end

    --big old wait
    local startTime = tick()

    while (entity == nil and (maxWaitTime == nil or tick() - startTime < maxWaitTime)) do
        RunService.Heartbeat:Wait()
        entity = self:GetEntityFromInstance(instance) 
    end

    return entity
end


function ECSWorld:_AddEntity(entity)
    local instance = entity.Instance

    entity.World = self
    self._Entities[instance] = entity

    self:_UpdateEntity(entity)
end


function ECSWorld:_CreateEntity(instance, componentList)
    local entity = ECSEntity.new(instance)

    self:_AddComponentsToEntity(entity, componentList)

    return entity
end


function ECSWorld:_CreateEntityFromInstance(instance, componentList)
    local instanceComponentData = GetComponentsDataFromEntityInstance(instance, true)
    componentList = MergeComponentData(instanceComponentData, componentList)

    return self:_CreateEntity(instance, componentList)
end


function ECSWorld:_CreateEntitiesFromInstanceList(instances, data, rootInstance)
    local newEntities = {}
    local rootEntity = nil

    for _, entityInstance in pairs(instances) do
        local entityInstanceName = entityInstance.Name

        local componentData
        local isRootInstance = entityInstance == rootInstance

        if (isRootInstance == true and type(data.RootInstance) == "table") then
            componentData = data.RootInstance
        else
            componentData = data[entityInstanceName] or {}
        end
        
        local newEntity = self:_CreateEntityFromInstance(entityInstance, componentData)
        table.insert(newEntities, newEntity)

        if (isRootInstance == true) then
            rootEntity = newEntity
        end
    end

    if (rootInstance ~= nil and rootEntity == nil) then     --if root is not an entity
        rootInstance.ChildRemoved:Connect(function(child)   --remove automatically if it has no children
            if (#rootInstance:GetChildren() == 0) then
                rootInstance:Destroy()
            end
        end)
    end

    return newEntities, rootEntity
end


function ECSWorld:_CreateEntitiesFromInstance(instance, data)
    local entityInstances = GetEntityInstancesFromInstance(instance)

    local newEntities, rootEntity = self:_CreateEntitiesFromInstanceList(entityInstances, data, instance)

    return newEntities, rootEntity
end


function ECSWorld:_AddComponentToEntity(entity, componentName, componentData)
    local newComponent = self:_CreateComponent(componentName, componentData)

    if (newComponent ~= nil) then
        entity:AddComponent(componentName, newComponent)
    end
end


function ECSWorld:_RemoveComponentFromEntity(entity, componentName)
    entity:RemoveComponent(componentName)
end


function ECSWorld:_AddComponentsToEntity(entity, componentList)
    for componentName, componentData in pairs(componentList) do
        if (type(componentData) == "string") then
            componentName = componentData
            componentData = {}
        end
        
        self:_AddComponentToEntity(entity, componentName, componentData)
    end
end


function ECSWorld:_RemoveComponentsFromEntity(entity, componentList)
    for _, componentName in pairs(componentList) do
        self:_RemoveComponentFromEntity(entity, componentName)
    end
end


function ECSWorld:_RemoveEntity(entity)
    if (entity._IsBeingRemoved == true) then
        return
    end

    entity._IsBeingRemoved = true   --set flag to true

    local registeredSystems = entity._RegisteredSystems

    if (#registeredSystems > 0) then
        registeredSystems = TableCopy(registeredSystems)

        for _, systemName in pairs(registeredSystems) do
            local system = self:GetSystem(systemName)
            if (system ~= nil) then
                system:RemoveEntity(entity)
            end
        end
    else
        self:ForceRemoveEntity(entity)
    end
end


function ECSWorld:CreateEntity(instance, componentList)
    componentList = componentList or {}

    local entity = self:_CreateEntityFromInstance(instance, componentList)

    self:_AddEntity(entity)

    return entity
end


function ECSWorld:CreateEntitiesFromInstance(instance, data)
    local newEntities, rootEntity = self:_CreateEntitiesFromInstance(instance, data)

    for _, entity in pairs(newEntities) do
        self:_AddEntity(entity)
    end

    return newEntities, rootEntity
end


function ECSWorld:AddComponentsToEntity(entity, componentList)
    assert(self:HasEntity(entity) == true)

    self:_AddComponentsToEntity(entity, componentList)

    self:_UpdateEntity(entity)
end


function ECSWorld:RemoveComponentsFromEntity(entity, componentList)
    assert(self:HasEntity(entity) == true)

    self:_RemoveComponentsFromEntity(entity, componentList)

    self:_UpdateEntity(entity)
end


function ECSWorld:AddAndRemoveComponentsFromEntity(entity, componentsToAdd, componentsToRemove)
    assert(self:HasEntity(entity) == true)

    self:_AddComponentsToEntity(entity, componentsToAdd)
    self:_RemoveComponentsFromEntity(entity, componentsToRemove)

    self:_UpdateEntity(entity)
end


function ECSWorld:RemoveEntity(entity)
    assert(IsEntity(entity) == true)

    if (TableContains(self._Entities, entity) == false) then
        return
    end

    self:_RemoveEntity(entity)
end


function ECSWorld:ForceRemoveEntity(entity)
    local instance = entity.Instance

    if (instance == nil) then
        for index, otherEntity in pairs(self._Entities) do
            if (entity == otherEntity) then
                self._Entities[index] = nil
                break
            end
        end
    else
        self._Entities[instance] = nil
    end

    pcall(function()
        entity:Destroy()
    end)
end


function ECSWorld:_UpdateEntity(entity)
    if (entity._IsBeingRemoved == true) then
        return
    end

    local registeredSystems = TableCopy(entity._RegisteredSystems)

    for _, systemName in pairs(registeredSystems) do
        local system = self:GetSystem(systemName)
        
        if (system ~= nil and system:EntityBelongs(entity) == false) then
            system:RemoveEntity(entity)
        end
    end

    for _, system in pairs(self._EntitySystems) do
        if (system:EntityBelongs(entity) == true) then
            system:AddEntity(entity)
        end
    end

    entity:Update()
end


--Components

function ECSWorld:GetComponent(componentName)
    return self._RegisteredComponents[componentName]
end


function ECSWorld:CreateComponent(componentName, componentData)
    local componentDescription = self:GetComponent(componentName)

    if (componentDescription == nil) then
        return
    end

    local newComponent = ECSComponent.new(componentDescription, componentData)

    return newComponent
end


function ECSWorld:RegisterComponent(componentDesc)
    assert(IsComponentDescription(componentDesc), "ECSWorld :: RegisterComponent() Argument [1] is not a \"" .. COMPONENT_DESC_CLASSNAME .. "\"! ClassName = " .. tostring(componentDesc.ClassName))

    local componentName = componentDesc.ComponentName

    if (self:GetComponent(componentName) ~= nil) then
        warn("ECS World " .. self.Name .. " - Component already registered with the name " .. componentName)
    end

    self._RegisteredComponents[componentName] = componentDesc
end


function ECSWorld:UnregisterComponent(componentDesc)
    local componentName
    
    if (type(componentDesc) == "string") then
        componentName = componentDesc
        componentDesc = self:GetComponent(componentDesc)

        if (componentDesc == nil) then
            return
        end
    else
        assert(IsComponentDescription(componentDesc))

        if (TableContains(self._RegisteredComponents, componentDesc) == false) then
            return
        end

        componentName = componentDesc.ComponentName
    end

    for _, entity in pairs(self._Entities) do
        self:_RemoveComponentsFromEntity(entity, {componentName})
    end
    
    self._RegisteredComponents[componentName] = nil
end


--Systems

function ECSWorld:GetSystem(name)
    for _, system in pairs(self._Systems) do
        if (system.Name == systemName) then
            return system
        end
    end

    return nil
end


function ECSWorld:_InitializeSystem(system)
    --check all components if they are registered with this world(?) so that they can be added through
    local componentList = system:GetComponentList()

    for _, componentName in pairs(componentList) do
        if (self:GetComponent(componentName) == nil) then
            warn("ECS World \"" .. self.Name .. "\" :: _InitializeSystem() - [" .. system.SystemName .. "] Component \"" .. componentName .. "\" is not registered!")
        end
    end

    system:Initialize()
    system._IsInitialized = true

    --check if system operates on entities by checking the components it needs
    if (#componentList > 0) then
        table.insert(self._EntitySystems, system)
        
        for _, entity in pairs(self._Entities) do
            if (system:EntityBelongs(entity) == true) then
                system:AddEntity(entity)
            end
        end
    end
end


function ECSWorld:RegisterSystem(system, initializeSystem)
    assert(IsSystem(system) == true)

    local systemName = system.Name
    
    self:UnregisterSystem(systemName)

    system.World = self
    table.insert(self._Systems, system)

    if (initializeSystem ~= false) then
        self:_InitializeSystem(system)
    end
end


function ECSWorld:UnregisterSystem(system)
    if (type(system) == "string") then
        system = self:GetSystem(system)

        if (system == nil) then
            return
        end
    else
        assert(IsSystem(system) == true)

        if (TableContains(self._Systems, system) == false) then
            return
        end
    end

    AttemptRemovalFromTable(self._EntitySystems, system)

    --remove registered entities from system
    local entities = TableCopy(system.Entities)

    for _, entity in pairs(entities) do
        system:RemoveEntity(entity)
    end

    system.World = nil
    AttemptRemovalFromTable(self._Systems, system)
end


--Resources and Prefabs

function ECSWorld:GetResource(name)
    return self._RegisteredResources[name]
end


function ECSWorld:GetResourceFromObject(resource)
    if (IsResource(resource) == true) then
        return resource
    elseif (type(resource) == "string") then
        return self:GetResource(resource)
    end

    return nil
end


function ECSWorld:_CreateEntitiesFromResource(resource, parent, data)
    resource = self:GetResourceFromObject(resourceObject)

    if (resource == nil) then
        return nil, "Unable to load resource!"
    end

    local rootInstance, entityInstances = resource:Create()

    local newEntities, rootEntity = self:_CreateEntitiesFromInstanceList(entityInstances, data, rootInstance)

    rootInstance.Parent = parent

    return rootInstance, newEntities, rootEntity
end


function ECSWorld:CreateEntitiesFromResource(resource, parent, data)
    local rootInstance, newEntities, rootEntity = self:_CreateEntitiesFromResource(resource, parent, data)

    assert(rootInstance ~= nil, "Unable to load resource!" .. tostring(newEntities))

    for _, entity in pairs(newEntities) do
        self:_AddEntity(entity)
    end

    return rootInstance, newEntities, rootEntity
end


--Constructors and Destructors

function ECSWorld:Destroy()
    setmetatable(self, nil)
end


function ECSWorld.new(name)
    local self = setmetatable({}, ECSWorld)

    self.Name = name or "WORLD"

    self._Entities = {}

    self._RegisteredComponents = {}
    self._RegisteredResources = {}

    self._Systems = {}
    self._EntitySystems = {}


    return self
end


return ECSWorld