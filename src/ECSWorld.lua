
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ECSEntity = require(script.Parent.ECSEntity)
local ECSComponent = require(script.Parent.ECSComponent)
local ECSSystem = require(script.Parent.ECSSystem)

local Table = require(script.Parent.Table)
local Signal = require(script.Parent.Signal)
local Utilities = require(script.Parent.Utilities)

local TableContains = Table.Contains
local TableMerge = Table.Merge
local TableCopy = Table.Copy
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local TableContainsAnyIndex = Table.TableContainsAnyIndex

local GetComponentsDataFromEntityInstance = Utilities.GetComponentsDataFromEntityInstance
local MergeComponentData = Utilities.MergeComponentData
local GetEntityInstancesFromInstance = Utilities.GetEntityInstancesFromInstance

local COMPONENT_DESC_CLASSNAME = Utilities.COMPONENT_DESC_CLASSNAME
local SYSTEM_CLASSNAME = Utilities.SYSTEM_CLASSNAME
local ENTITY_INSTANCE_COMPONENT_DATA_NAME = Utilities.ENTITY_INSTANCE_COMPONENT_DATA_NAME

local REMOTE_EVENT_PLAYER_READY = 0
local REMOTE_EVENT_ENTITY_CREATE = 1
local REMOTE_EVENT_ENTITY_REMOVE = 2
local REMOTE_EVENT_ENTITY_ADD_COMPONENTS = 3
local REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS = 4
local REMOTE_EVENT_ENTITY_CREATE_FROM_INSTANCE = 5
local REMOTE_EVENT_RESOURCE_CREATE = 6


local function GetCFrameFromInstance(instance)
    if (instance:IsA("Model") == true) then
        if (instance.PrimaryPart ~= nil) then
            return instance:GetPrimaryPartCFrame()
        end
    elseif (instance:IsA("BasePart") == true) then
        return instance.CFrame
    end
end


local function IsValidParentForServerClientEntity(instance)
    return instance ~= ServerStorage and instance ~= ServerScriptStorage
end


local function IsInstanceVisibleByClient(instance)
    local instanceParent = instance.Parent

    return instanceParent ~= nil and IsValidParentForServerClientEntity(instanceParent)
end


local ECSWorld = {
    ClassName = "ECSWorld";
}

ECSWorld.__index = ECSWorld


function ECSWorld:GetEntityFromInstance(instance)
    for _, entity in pairs(self._Entities) do
        if (entity.Instance == instance) then
            return entity
        end
    end

    return nil
end


function ECSWorld:GetEntityContainingInstance(instance) --need to redo
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


function ECSWorld:GetSystem(systemName)
    for _, system in pairs(self._Systems) do
        if (system.SystemName == systemName) then
            return system
        end
    end

    return nil
end


function ECSWorld:_GetComponentDescription(componentName)
    return self._RegisteredComponents[componentName]
end


function ECSWorld:_CreateComponent(componentName, data, instance)
    local componentDesc = self:_GetComponentDescription(componentName)

    if (componentDesc == nil) then
        --warn("ECS World :: _CreateComponent() " .. self.Name .. " - Unable to find component with the name \"" .. componentName .. "\"")
        --removed until i can make either an ignorelist or whatever
        return nil
    end

    local newComponent = ECSComponent.new(componentDesc, data, instance)

    return newComponent
end


function ECSWorld:RegisterComponent(componentDesc)
    if (typeof(componentDesc) == "Instance" and componentDesc:IsA("ModuleScript") == true) then
        local success, message = pcall(function()
            componentDesc = require(componentDesc)
        end)

        assert(success == true, message)
    end

    assert(type(componentDesc) == "table", "")
    assert(componentDesc._IsComponentDescription == true, "ECSWorld :: RegisterComponent() Argument [1] is not a \"" .. COMPONENT_DESC_CLASSNAME .. "\"! ClassName = " .. tostring(componentDesc.ClassName))

    local componentName = componentDesc.ComponentName

    if (self:_GetComponentDescription(componentName) ~= nil) then
        warn("ECS World " .. self.Name .. " - Component already registered with the name " .. componentName)
    end

    local isComponentServerSide = componentDesc.IsServerSide

    if (isComponentServerSide ~= nil and isComponentServerSide ~= self._IsServer) then
        if (isComponentServerSide == true) then
            warn("ECS World " .. self.Name .. " - Component is Server-Side Only! " .. componentName)
        else
            warn("ECS World " .. self.Name .. " - Component is Client-Side Only! " .. componentName)
        end
        return
    end

    self._RegisteredComponents[componentName] = componentDesc
end


function ECSWorld:RegisterComponents(...)
    local componentDescs = {...}

    self:RegisterComponentsFromList(componentDescs)
end


function ECSWorld:RegisterComponentsFromList(componentDescs)
    assert(type(componentDescs) == "table", "")

    for _, componentDesc in pairs(componentDescs) do
        self:RegisterComponent(componentDesc)
    end
end


function ECSWorld:_InitializeSystem(system)
    for _, componentName in pairs(system.Components) do
        if (self:_GetComponentDescription(componentName) == nil) then
            warn("ECS World \"" .. self.Name .. "\" :: InitializeSystem() - [" .. system.SystemName .. "] Component \"" .. componentName .. "\" is not registered!")
        end
    end

    system:Initialize()
    system._IsInitialized = true

    if (#system.Components > 0) then
        table.insert(self._EntitySystems, system)
    end
end


function ECSWorld:InitializeSystems()
    for _, system in pairs(self._Systems) do
        if (system._IsInitialized == false) then
            self:_InitializeSystem(system)
        end
    end
end


function ECSWorld:RegisterSystem(system, initializeSystem)
    if (typeof(system) == "Instance" and system:IsA("ModuleScript") == true) then
        local success, message = pcall(function()
            system = require(system)
        end)

        assert(success == true, message)
    end

    assert(type(system) == "table", "")
    assert(system._IsSystem == true, "ECSWorld :: RegisterSystem() Argument [1] is not a \"" .. SYSTEM_CLASSNAME .. "\"! ClassName = " .. tostring(system.SystemName))

    local systemName = system.SystemName

    if (self:GetSystem(systemName) ~= nil) then
        error("ECS World " .. self.Name .. " - System already registered with the name \"" .. systemName .. "\"!")
    end

    local isSystemServerSide = system.IsServerSide

    if (isSystemServerSide ~= nil and isSystemServerSide ~= self._IsServer) then
        if (isSystemServerSide == true) then
            warn("ECS World " .. self.Name .. " - System is Server-Side Only! " .. systemName)
        else
            warn("ECS World " .. self.Name .. " - System is Client-Side Only! " .. systemName)
        end
        return
    end

    system.World = self
    table.insert(self._Systems, system)

    if (initializeSystem ~= false) then
        self:_InitializeSystem(system)
    end
end


function ECSWorld:RegisterSystems(...)
    local systemDescs = {...}

    self:RegisterSystemsFromList(systemDescs)
end


function ECSWorld:RegisterSystemsFromList(systemDescs, initializeSystems)
    assert(type(systemDescs) == "table", "")

    for _, systemDesc in pairs(systemDescs) do
        self:RegisterSystem(systemDesc, initializeSystems)
    end
end


function ECSWorld:EntityBelongsInSystem(system, entity)
    local systemComponents = system.Components

    return (#systemComponents > 0 and entity:HasComponents(systemComponents))
end


function ECSWorld:_CanUpdateEntityForClients(entity)
    return entity._IsServerSide ~= true and self._RemoteEvent ~= nil
end


function ECSWorld:_CheckIsServerSideValue(isServerSide)
    if (self._IsServer == false) then
        return false
    elseif (isServerSide == true) then
        return isServerSide
    end

    return self._RemoteEvent == nil --if nil, it can only e serverside
end


function ECSWorld:_SetEntitiesIsServerSide(entities, isServerSide)
    isServerSide = self:_CheckIsServerSideValue(isServerSide)

    for _, entity in pairs(entities) do
        entity.IsServerSide = isServerSide
    end

    return isServerSide
end


function ECSWorld:_CreateAndAddEntity(instance, componentList)
    local entity = ECSEntity.new(self, instance)

    table.insert(self._Entities, entity)
    self:_AddComponentsToEntity(entity, componentList, false, false)

    return entity
end


function ECSWorld:_CreateAndAddEntityWithData(instance, componentList)
    local instanceComponentData = GetComponentsDataFromEntityInstance(instance)
    instanceComponentData = MergeComponentData(instanceComponentData, componentList)

    local entity = self:_CreateAndAddEntity(instance, instanceComponentData)

    return entity
end


function ECSWorld:_CreateEntity()
    --nothing
end


function ECSWorld:CreateEntity(instance, componentList, isServerSideEntity)
    assert(instance == nil or typeof(instance) == "Instance")

    componentList = componentList or {}
    assert(type(componentList) == "table")

    return self:_CreateEntity(instance, componentList, isServerSideEntity)
end


function ECSWorld:_RemoveEntity(entity)
    if (entity._IsBeingRemoved ~= true) then
        entity._IsBeingRemoved = true   --set flag to true

        local registeredSystems = TableCopy(entity:GetRegisteredSystems())

        if (#registeredSystems > 0) then
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
end


function ECSWorld:ForceRemoveEntity(entity)
    AttemptRemovalFromTable(self._Entities, entity)

    pcall(function()
        entity:Destroy()
    end)
end


function ECSWorld:_InitializeEntity(entity)
    entity:InitializeComponents()
    self:_UpdateEntity(entity)
end


function ECSWorld:_InitializeEntitiesFromList(entities)
    for _, entity in pairs(entities) do
        entity:InitializeComponents()
    end

    for _, entity in pairs(entities) do
        self:_UpdateEntity(entity)
    end
end


local function CreateEntity_Server(self, instance, componentList, isServerSideEntity)
    componentList = componentList or {}

    if (isServerSideEntity == false and instance ~= nil) then
        assert(IsInstanceVisibleByClient(instance) == true, "Instance is not visible by the client. Consider parenting it in ReplicatedStorage")
    end

    local entity = self:_CreateAndAddEntityWithData(instance, componentList)

    entity._IsServerSide = self:_CheckIsServerSideValue(isServerSideEntity)

    self:_InitializeEntity(entity)

    --add entity to clients 
    if (isServerSideEntity == false) then
        if (instance == nil) then
            entity.Instance.Parent = ReplicatedStorage
        end

        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_CREATE, entity.Instance, componentList)
    end

    return entity
end


local function RemoveEntity_Server(self, entity)
    if (TableContains(self._Entities, entity) == false) then
        return
    end

    if (self:_CanUpdateEntityForClients(entity) == true) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_REMOVE, entity.Instance)
    end

    self:_RemoveEntity(entity)
end


function ECSWorld:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")
end


local function AddComponentsToEntity_Server(self, entity, componentList, updateEntity, initializeComponents)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)

    if (self:_CanUpdateEntityForClients(entity) == true) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_ADD_COMPONENTS, entity.Instance, componentList)
    end
end


local function RemoveComponentsFromEntity_Server(self, entity, componentList, updateEntity)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_RemoveComponentsFromEntity(REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS, componentList, updateEntity)

    if (self:_CanUpdateEntityForClients(entity) == true) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS, entity.Instance, componentList)
    end
end


local function CreateEntity_Client(self, instance, componentList)
    componentList = componentList or {}

    local entity = self:_CreateAndAddEntityWithData(instance, componentList)

    self:_InitializeEntity(entity)

    return entity
end


local function RemoveEntity_Client(self, entity)
    if (TableContains(self._Entities, entity) == false) then
        return
    end

    self:_RemoveEntity(entity)
end


local function AddComponentsToEntity_Client(self, entity, componentList, updateEntity, initializeComponents)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)
end


local function RemoveComponentsFromEntity_Client(self, entity, componentList, updateEntity)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_RemoveComponentsFromEntity(entity, componentList, updateEntity)
end


local function EntityCreatedFromServer_Client(self, instance, componentList)
    self:_CreateEntity(instance, componentList)
end


local function EntityRemovedFromServer_Client(self, instance)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveEntity(entity)
    end
end


local function EntityAddedComponentsFromServer_Client(self, instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_AddComponentsToEntity(entity, componentList)
    end
end


local function EntityRemovedComponentsFromServer_Client(self, instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveComponentsFromEntity(entity, componentList)
    end
end


function ECSWorld:_AddComponentToEntity(entity, componentName, componentData, initializeComponents)
    assert(type(componentName) == "string" and type(componentData) == "table")

    local newComponent = self:_CreateComponent(componentName, componentData)

    if (newComponent ~= nil) then
        entity:AddComponent(componentName, newComponent, initializeComponents)
    end
end


function ECSWorld:_AddComponentsToEntity(entity, componentList, initializeComponents, updateEntity)
    for componentName, componentData in pairs(componentList) do
        if (type(componentData) == "string") then
            componentName = componentData
            componentData = {}
        end
        
        self:_AddComponentToEntity(entity, componentName, componentData, false)
    end

    if (initializeComponents ~= false) then
        entity:InitializeComponents()
    end

    if (updateEntity ~= false) then
        self:_UpdateEntity(entity)
    end
end


function ECSWorld:_RemoveComponentFromEntity(entity, componentName)
    assert(type(componentName) == "string")

    entity:RemoveComponent(componentName)
end


function ECSWorld:_RemoveComponentsFromEntity(entity, componentList, updateEntity)
    for _, componentName in pairs(componentList) do
        self:_RemoveComponentFromEntity(entity, componentName)
    end

    if (updateEntity ~= false) then
        self:_UpdateEntity(entity)
    end
end


function ECSWorld:_UpdateEntity(entity)  --update after it's components have changed or it was just added
    if (entity._IsBeingRemoved == true) then
        return
    end

    local registeredSystems = TableCopy(entity:GetRegisteredSystems())

    for _, systemName in pairs(registeredSystems) do
        local system = self:GetSystem(systemName)
        
        if (system ~= nil and self:EntityBelongsInSystem(system, entity) == false) then
            system:RemoveEntity(entity)
        end
    end

    for _, system in pairs(self._EntitySystems) do
        if (self:EntityBelongsInSystem(system, entity) == true) then
            system:AddEntity(entity)
        end
    end

    entity:Update()
end


function ECSWorld:UpdateEntity(entity)
    assert(TableContains(self._Entities, entity) == true)

    self:_UpdateEntity(entity)
end


function ECSWorld:IsResource(resource)
    return (type(resource) == "table" and resource._IsResource == true)
end


function ECSWorld:GetResource(resourceName)
    return self._RegisteredResources[resourceName]
end


function ECSWorld:GetResourceFromObject(resource)
    if (self:IsResource(resource) == true) then
        return resource
    elseif (type(resource) == "string") then
        return self:GetResource(resource)
    end

    return nil
end


function ECSWorld:RegisterResource(resource, resourceName)    --register for prefabs resources
    assert(self:IsResource(resource) == true)
    
    if (TableContains(self._RegisteredResources, resource) == true) then
        return
    end

    resourceName = resourceName or resource.ResourceName

    local otherResource = self:GetResource(resourceName)

    if (otherResource ~= nil) then
        error("Resource already registered with the name " .. resourceName)
    end

    self._RegisteredResources[resourceName] = resource
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
        
        local newEntity = self:_CreateAndAddEntityWithData(entityInstance, componentData)
        table.insert(newEntities, newEntity)

        if (isRootInstance == true) then
            rootEntity = newEntity
        end
    end

    if (rootInstance ~= nil and rootEntity ~= nil) then
        rootInstance.ChildRemoved:Connect(function(child)   --remove automatically if it has no children
            if (#rootInstance:GetChildren() == 0) then
                rootInstance:Destroy()
            end
        end)
    end

    return newEntities, rootEntity
end


function ECSWorld:_CreateEntitiesFromInstance_Base(instance, data)
    local entityInstances = GetEntityInstancesFromInstance(instance)

    local newEntities, rootEntity = self:_CreateEntitiesFromInstanceList(entityInstances, data, instance)

    return newEntities, rootEntity
end


function ECSWorld:_CreateEntitiesFromInstance(instance, data)
    --
end


local function _CreateEntitiesFromInstance_Server(self, instance, data, isServerSide)
    isServerSide = self:_CheckIsServerSideValue(isServerSide)
    assert(isServerSide == true or IsInstanceVisibleByClient(instance) == true, "Instance cannot be seen by client!")

    local newEntities, rootEntity = self:_CreateEntitiesFromInstance_Base(instance, data)

    for _, entity in pairs(newEntities) do
        entity.IsServerSide = isServerSide
    end

    self:_InitializeEntitiesFromList(newEntities)

    if (isServerSide == false) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_CREATE_FROM_INSTANCE, instance, data)
    end

    return newEntities, rootEntity
end


local function _CreateEntitiesFromInstance_Client(self, instance, data)
    local newEntities, rootEntity = self:_CreateEntitiesFromInstance_Base(instance, data)

    self:_InitializeEntitiesFromList(newEntities)

    return newEntities, rootEntity
end


local function EntitiesCreatedFromInstanceFromServer_Client(self, instance, data)
    self:_CreateEntitiesFromInstance(instance, data)
end


function ECSWorld:CreateEntitiesFromInstance(instance, data, isServerSide)
    assert(typeof(instance) == "Instance")

    data = data or {}
    assert(type(data) == "table")

    local newEntities, rootEntity = self:_CreateEntitiesFromInstance(instance, data, isServerSide)

    return newEntities, rootEntity
end


function ECSWorld:_CreateEntitiesFromResource_Base(resourceObject, data, parent)
    resource = self:GetResourceFromObject(resourceObject)

    if (resource == nil) then
        return nil, "Unable to load resource!"
    end

    local rootInstance, entityInstances = resource:Create()

    local newEntities, rootEntity = self:_CreateEntitiesFromInstanceList(entityInstances, data, rootInstance)

    rootInstance.Parent = parent

    return rootInstance, newEntities, rootEntity
end


function ECSWorld:_CreateEntitiesFromResource()
    --
end


local function _CreateEntitiesFromResource_Server(self, resource, data, parent, isServerSide)
    isServerSide = self:_CheckIsServerSideValue(isServerSide)
    assert(isServerSide == true or IsInstanceVisibleByClient(parent) == true)
    
    local rootInstance, newEntities, rootEntity = self:_CreateEntitiesFromResource_Base(resource, data, parent)

    assert(rootInstance ~= nil, "Unable to load resource!" .. tostring(newEntities))

    for _, entity in pairs(newEntities) do
        entity.IsServerSide = isServerSide
    end

    self:_InitializeEntitiesFromList(newEntities)

    if (isServerSide == false) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_CREATE_FROM_INSTANCE, rootInstance, data)
    end

    return rootInstance, newEntities, rootEntity
end


local function _CreateEntitiesFromResource_Client(self, resource, data, parent)
    local rootInstance, newEntities, rootEntity = self:_CreateEntitiesFromResource_Base(resource, data, parent)

    assert(rootInstance ~= nil, "Unable to load resource!" .. tostring(newEntities))

    self:_InitializeEntitiesFromList(newEntities)

    return rootInstance, newEntities, rootEntity
end


function ECSWorld:CreateEntitiesFromResource(resource, data, parent, isServerSide)
    data = data or {}
    assert(type(data) == "table")

    assert(parent == nil or typeof(parent) == "Instance")

    local rootInstance, newEntities, rootEntity = self:_CreateEntitiesFromResource(resource, data, parent, isServerSide)

    return rootInstance, newEntities, rootEntity
end


local function ResourceCreatedFromServer_Client()

end


local function GetPlayerIdString(player)
    local playerId = player.UserId
    local idString = tostring(playerId)

    return idString
end


local function IsPlayerReady_Server(self, player)
    assert(typeof(player) == "Instance" and player:IsA("Player") == true)

    local idString = GetPlayerIdString(player)

    return self._PlayersReady[idString] == true
end


local function PlayerReady_Server(self, player)
    local idString = GetPlayerIdString(player)
    
    if (self._PlayersReady[idString] ~= true) then
        self._PlayersReady[idString] = true
        self.OnPlayerReady:Fire(player)
    end
end


local function PlayerLeft_Server(self, player)
    local idString = GetPlayerIdString(player)

    self._PlayersReady[idString] = false
end


function ECSWorld:Destroy() --to do, add
    setmetatable(self, nil)
end


function ECSWorld.new(name, isServer, remoteEvent)
    if (isServer ~= nil) then
        assert(type(isServer) == "boolean")
    else
        isServer = false
    end

    if (remoteEvent ~= nil) then
        assert(typeof(remoteEvent) == "Instance" and remoteEvent:IsA("RemoteEvent") == true)
    end

    local self = setmetatable({}, ECSWorld)

    self.Name = name or "ECS_WORLD"

    self._Entities = {}

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

    self._RegisteredComponents = {}

    self._Systems = {}
    self._EntitySystems = {}

    self._RegisteredResources = {}

    self._RemoteEvent = nil
    self._RemoteEventConnection = nil


    if (isServer == true) then
        self._IsServer = true

        self._CreateEntity = CreateEntity_Server
        self.RemoveEntity = RemoveEntity_Server

        self.AddComponentsToEntity = AddComponentsToEntity_Server
        self.RemoveComponentsFromEntity = RemoveComponentsFromEntity_Server

        self._CreateEntitiesFromInstance = _CreateEntitiesFromInstance_Server
        self._CreateEntitiesFromResource = _CreateEntitiesFromResource_Server

        self._PlayersReady = {}
        self.IsPlayerReady = IsPlayerReady_Server

        if (remoteEvent ~= nil) then
            self.OnPlayerReady = Signal.new()

            self._RemoteEvent = remoteEvent

            self._RemoteEventConnection = remoteEvent.OnServerEvent:Connect(function(player, eventType)
                if (eventType == REMOTE_EVENT_PLAYER_READY) then
                    PlayerReady_Server(self, player)
                end
            end)

            self._PlayerLeftConnection = Players.PlayerRemoving:Connect(function(player)
                PlayerLeft_Server(self, player)
            end)
        end
    else
        self._IsServer = false

        self._CreateEntity = CreateEntity_Client
        self.RemoveEntity = RemoveEntity_Client

        self.AddComponentsToEntity = AddComponentsToEntity_Client
        self.RemoveComponentsFromEntity = RemoveComponentsFromEntity_Client

        self._CreateEntitiesFromInstance = _CreateEntitiesFromInstance_Client
        self._CreateEntitiesFromResource = _CreateEntitiesFromResource_Client

        if (remoteEvent ~= nil) then
            self._RemoteEvent = remoteEvent

            function self:Ready()
                remoteEvent:FireServer(REMOTE_EVENT_PLAYER_READY)
            end

            self._RemoteEventConnection = remoteEvent.OnClientEvent:Connect(function(eventType, instance, componentList)
                if (eventType == REMOTE_EVENT_ENTITY_CREATE) then
                    EntityCreatedFromServer_Client(self, instance, componentList)
                elseif (eventType == REMOTE_EVENT_ENTITY_REMOVE) then
                    EntityRemovedFromServer_Client(self, instance)
                elseif (eventType == REMOTE_EVENT_ENTITY_ADD_COMPONENTS) then
                    EntityAddedComponentsFromServer_Client(self, instance, componentList)
                elseif (eventType == REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS) then
                    EntityRemovedComponentsFromServer_Client(self, instance, componentList)
                elseif (eventType == REMOTE_EVENT_ENTITY_CREATE_FROM_INSTANCE) then
                    EntitiesCreatedFromInstanceFromServer_Client(self, instance, componentList)
                elseif (eventType == REMOTE_EVENT_RESOURCE_CREATE) then
                    --ResourceCreatedFromServer_Client(self, instance, componentList)
                else
                    warn("Unknown Argument [1] passed! Arg [1] = ".. tostring(eventType))
                end
            end)
        end
    end


    return self
end


return ECSWorld