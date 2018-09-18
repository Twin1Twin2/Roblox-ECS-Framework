--- World
--
--

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ECSEntity = require(script.Parent.ECSEntity)
local ECSComponent = require(script.Parent.ECSComponent)

local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsEntity = Utilities.IsEntity
local IsComponentDescription = Utilities.IsComponentDescription
local IsSystem = Utilities.IsSystem
local IsResource = Utilities.IsResource
local GetComponentsDataFromEntityInstance = Utilities.GetComponentsDataFromEntityInstance
local GetEntityInstancesFromInstance = Utilities.GetEntityInstancesFromInstance
local MergeComponentData = Utilities.MergeComponentData
local AddSystemToListByPriority = Utilities.AddSystemToListByPriority

local TableCopy = Table.Copy
local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable

local COMPONENT_DESC_CLASSNAME = Utilities.COMPONENT_DESC_CLASSNAME
local SYSTEM_CLASSNAME = Utilities.SYSTEM_CLASSNAME

local ENTITY_TAG_NAME_POSTFIX = "_ENTITY"


local ECSWorld = {
    ClassName = "ECSWorld";
}

ECSWorld.__index = ECSWorld


-- Entities

function ECSWorld:HasEntity(entity)
    assert(IsEntity(entity), "Object is not an entity!")

    return TableContains(self._Entities, entity)
end


function ECSWorld:GetEntityFromInstance(instance)
    assert(typeof(instance) == "Instance")
    return self._Entities[instance]
end


function ECSWorld:GetEntityContainingInstance(instance) -- need to redo(?)
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


function ECSWorld:WaitForEntityWithInstance(instance, maxWaitTime)   -- idk how to do this, but this will do
    assert(typeof(instance) == "Instance")
    assert(maxWaitTime == nil or (type(maxWaitTime) == "number" and maxWaitTime >= 0), "Invalid Arg [2]")

    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        return entity
    end

    -- big old wait
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

    CollectionService:AddTag(entity.Instance, self._ENTITY_TAG_NAME)
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
        newEntities[entityInstance] = newEntity

        if (isRootInstance == true) then
            rootEntity = newEntity
        end
    end

    if (rootInstance ~= nil and rootEntity == nil) then     -- if root is not an entity (should this be rewritten?)
        rootInstance.ChildRemoved:Connect(function(child)   -- remove automatically if it has no children
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
    local newComponent = self:_CreateComponentFromName(componentName, componentData)

    if (newComponent ~= nil) then
        entity:AddComponentToEntity(componentName, newComponent)
    end
end


function ECSWorld:_RemoveComponentFromEntity(entity, componentName)
    entity:RemoveComponentFromEntity(componentName)
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
    entity._IsBeingUpdated = false

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
    assert(instance == nil or typeof(instance) == "Instance")

    componentList = componentList or {}

    local entity = self:_CreateEntityFromInstance(instance, componentList)

    self:_AddEntity(entity)

    return entity
end


function ECSWorld:CreateEntitiesFromInstance(instance, data)
    assert(instance == nil or typeof(instance) == "Instance")

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


function ECSWorld:RemoveEntities(entities)
    assert(type(entities) == "table")

    for _, entity in pairs(entities) do
        self:RemoveEntity(entity)
    end
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

    if (type(entity.Destroy) == "function") then
        entity:Destroy()
    end
end


function ECSWorld:_UpdateEntity(entity)
    if (entity._IsBeingRemoved == true) then
        return
    end

    entity._IsBeingUpdated = true
    entity:UpdateAddedComponents()

    local registeredSystems = TableCopy(entity._RegisteredSystems)

    for _, systemName in pairs(registeredSystems) do
        local system = self:GetSystem(systemName)

        if (system ~= nil and system:EntityBelongs(entity) == false) then
            system:RemoveEntity(entity)

            -- don't continue if components have changed or entity is removed
            if (entity == nil or entity._IsBeingUpdated == false) then
                return
            end
        end
    end

    for _, system in pairs(self._EntitySystems) do
        if (system:EntityBelongs(entity) == true) then
            system:AddEntity(entity)

            -- don't continue if components have changed or entity is removed
            if (entity == nil or entity._IsBeingUpdated == false) then
                return
            end
        end
    end

    entity:UpdateRemovedComponents()
    entity._IsBeingUpdated = false
end


function ECSWorld:_EntityInstanceDestroyed(instance)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveEntity(entity)
    end
end


-- Components

function ECSWorld:GetComponent(componentName)
    return self._RegisteredComponents[componentName]
end


function ECSWorld:_CreateComponent(componentDescription, componentData)
    local newComponent = ECSComponent.new(componentDescription, componentData)

    return newComponent
end


function ECSWorld:_CreateComponentFromName(componentName, componentData)
    local componentDescription = self:GetComponent(componentName)

    if (componentDescription == nil) then
        return
    end

    return self:_CreateComponent(componentDescription, componentData)
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


-- Systems

function ECSWorld:GetSystem(name)
    for _, system in pairs(self._Systems) do
        if (system.Name == name) then
            return system
        end
    end

    return nil
end


function ECSWorld:_InitializeSystem(system)
    -- check all components if they are registered with this world(?) so that they can be added through
    local componentList = system:GetComponentList()

    for _, componentName in pairs(componentList) do
        if (self:GetComponent(componentName) == nil) then
            warn("ECS World \"" .. self.Name .. "\" :: _InitializeSystem() - [" .. system.SystemName .. "] Component \"" .. componentName .. "\" is not registered!")
        end
    end

    system:Initialize()
    system._IsInitialized = true

    -- check if system operates on entities by checking the components it needs
    if (#componentList > 0) then
        AddSystemToListByPriority(system, self._EntitySystems)

        for _, entity in pairs(self._Entities) do
            if (system:EntityBelongs(entity) == true) then
                system:AddEntity(entity)
            end
        end
    end
end


function ECSWorld:RegisterSystem(system, initializeSystem)
    assert(IsSystem(system) == true, "ECSWorld :: RegisterSystem() Argument [1] is not a \"" .. SYSTEM_CLASSNAME .. "\"! ClassName = " .. tostring(system.ClassName))

    local systemName = system.Name

    self:UnregisterSystem(systemName)

    system.World = self
    AddSystemToListByPriority(system, self._Systems)
    system:RegisteredToWorld(self)

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
        assert(IsSystem(system))

        if (TableContains(self._Systems, system) == false) then
            return
        end
    end

    AttemptRemovalFromTable(self._EntitySystems, system)

    -- remove registered entities from system
    local entities = TableCopy(system.Entities)

    for _, entity in pairs(entities) do
        system:RemoveEntity(entity)
    end

    system:UnregisteredFromWorld(self)
    system.World = nil
    AttemptRemovalFromTable(self._Systems, system)
end


function ECSWorld:PrintRegisteredSystems()
    print(self.Name .. " - Number of Systems = " .. tostring(#self._Systems))
    for index, system in pairs(self._Systems) do
        local name = system.Name
        print("    " .. tostring(index) .. "    " .. name)
    end
end


-- Resources and Prefabs

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


function ECSWorld:RegisterResource(resource, resourceName)
    assert(IsResource(resource) == true)

    resourceName = resourceName or resource.ResourceName
    assert(type(resourceName) == "string")

    self:UnregisterResource(resourceName)

    self._RegisteredResources[resourceName] = resource
end


function ECSWorld:UnregisterResource(resource)
    local resourceName

    if (type(resource) == "string") then
        resourceName = resource
        resource = self:GetResource(resourceName)

        if (resource == nil) then
            return
        end
    else
        assert(IsResource(resource))
        resourceName = resource.ResourceName

        if (resource ~= self._RegisteredResources[resourceName]) then
            return
        end
    end

    self._RegisteredResources[resourceName] = nil
end


function ECSWorld:_CreateEntitiesFromResource(resource, parent, data)
    resource = self:GetResourceFromObject(resource)

    if (resource == nil) then
        return nil, "Unable to load resource!"
    end

    assert(parent == nil or typeof(parent) == "Instance")

    data = data or {}
    assert(type(data) == "table")

    local rootInstance, entityInstances = resource:Create()
    rootInstance.Parent = parent

    local newEntities, rootEntity = self:_CreateEntitiesFromInstanceList(entityInstances, data, rootInstance)

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


-- Constructors and Destructors

function ECSWorld:Destroy()
    for _, resource in pairs(self._RegisteredResources) do
        self:UnregisterResource(resource)
    end

    for _, component in pairs(self._RegisteredComponents) do
        self:UnregisterComponent(component)
    end

    for _, system in pairs(self._Systems) do
        self:UnregisterSystem(system)
    end

    for _, entity in pairs(self._Entities) do
        self:ForceRemoveEntity(entity)
    end

    self._Entities = nil

    self._RegisteredComponents = nil
    self._RegisteredResources = nil

    self._Systems = nil
    self._EntitySystems = nil

    self._EntityInstanceRemovedConnection:Disconnect()

    setmetatable(self, nil)
end


function ECSWorld.new(name)
    assert(type(name) == "string")

    local self = setmetatable({}, ECSWorld)

    self.Name = name

    self._Entities = {}

    self._RegisteredComponents = {}
    self._RegisteredResources = {}

    self._Systems = {}
    self._EntitySystems = {}

    self._IsWorld = true

    -- kinda hacky way to detect when an entity's instance is destroyed
    local entityTagName = name .. ENTITY_TAG_NAME_POSTFIX   -- should this be made more unique? maybe tostring(tick())?

    self._ENTITY_TAG_NAME = entityTagName
    self._EntityInstanceRemovedConnection = CollectionService:GetInstanceRemovedSignal(entityTagName):Connect(function(instance)
        self:_EntityInstanceDestroyed(instance)
    end)


    return self
end


return ECSWorld