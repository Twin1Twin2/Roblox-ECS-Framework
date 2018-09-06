--- World_Server
--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")


local ECSWorld = require(script.Parent.ECSWorld)

local Signal = require(script.Parent.Signal)
local Utilities = require(script.Parent.Utilities)

local REMOTE_EVENT_ENUM = Utilities.REMOTE_EVENT_ENUM

local REMOTE_EVENT_PLAYER_READY = REMOTE_EVENT_ENUM.PLAYER_READY
local REMOTE_EVENT_ENTITY_CREATE = REMOTE_EVENT_ENUM.ENTITY_CREATE
local REMOTE_EVENT_ENTITY_ADD_COMPONENTS = REMOTE_EVENT_ENUM.ENTITY_ADD_COMPONENTS
local REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS = REMOTE_EVENT_ENUM.ENTITY_REMOTE_COMPONENTS
local REMOTE_EVENT_ENTITY_ADD_REMOVE_COMPONENTS = REMOTE_EVENT_ENUM.ENTITY_ADD_REMOVE_COMPONENTS
local REMOTE_EVENT_ENTITY_REMOVE = REMOTE_EVENT_ENUM.ENTITY_REMOTE
local REMOTE_EVENT_ENTITY_CREATE_FROM_INSTANCE = REMOTE_EVENT_ENUM.ENTITY_CREATE_FROM_INSTANCE


local function IsValidParentForServerClientEntity(instance)
    return instance ~= ServerStorage and instance ~= ServerScriptService
end


local function IsInstanceVisibleByClient(instance)
    local instanceParent = instance.Parent

    return instanceParent ~= nil and IsValidParentForServerClientEntity(instanceParent)
end


local ECSWorld_Server = {
    ClassName = "ECSWorld_Server";
}

ECSWorld_Server.__index = ECSWorld_Server
setmetatable(ECSWorld_Server, ECSWorld)


local function GetPlayerIdString(player)
    local playerId = player.UserId
    local idString = tostring(playerId)

    return idString
end


function ECSWorld_Server:IsPlayerReady(player)
    assert(typeof(player) == "Instance" and player:IsA("Player") == true)

    local idString = GetPlayerIdString(player)

    return self._PlayersReady[idString] == true
end


function ECSWorld_Server:_PlayerReady(player)
    local idString = GetPlayerIdString(player)
    
    if (self._PlayersReady[idString] ~= true) then
        self._PlayersReady[idString] = true
        self.OnPlayerReady:Fire(player)
    end
end


function ECSWorld_Server:_PlayerLeft(player)
    local idString = GetPlayerIdString(player)

    self._PlayersReady[idString] = nil

    self.OnPlayerLeft:Fire(player)
end


--Entities

function ECSWorld_Server:_FireAllClientsEntityCreated(entity)
    local entityComponentList = entity:CopyData()
    self:FilterServerComponents(entityComponentList)

    self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_CREATE, entity.Instance, entityComponentList)
end


function ECSWorld_Server:CreateEntity(instance, componentList, isServerSide)
    isServerSide = isServerSide or false
    assert(type(isServerSide) == "boolean")

    if (typeof(instance) == "Instance" and isServerSide == false) then
        assert(IsInstanceVisibleByClient(instance))
    end
    
    local entity = self:_CreateEntity(instance, componentList)
    entity._IsServerSide = isServerSide

    self:_AddEntity(entity)

    --add entity to clients
    if (isServerSide == false) then
        if (instance == nil) then
            entity.Instance.Parent = self.DefaultGlobalEntityInstanceParent
        end

        self:_FireAllClientsEntityCreated(entity)
    end
end


function ECSWorld_Server:CreateEntitiesFromInstance(instance, data, isServerSide)
    assert(typeof(instance) == "Instance")

    isServerSide = isServerSide or false
    assert(type(isServerSide) == "boolean")
    assert(isServerSide == true or IsInstanceVisibleByClient(instance))

    local newEntities, rootEntity = self:_CreateEntitiesFromInstance(instance, data)

    for _, entity in pairs(newEntities) do
        entity._IsServerSide = isServerSide
        self:_UpdateEntity(entity)
    end

    if (isServerSide == false) then
        for _, entity in pairs(newEntities) do
            self:_FireAllClientsEntityCreated(entity)
        end
    end

    return newEntities, rootEntity
end


function ECSWorld_Server:AddComponentsToEntity(entity, componentList)
    assert(self:HasEntity(entity) == true)

    self:_AddComponentsToEntity(entity, componentList)

    self:_UpdateEntity(entity)

    if (entity._IsServerSide == false) then
        local _, componentCount = self:FilterServerComponents(componentList)

        if (componentCount > 0) then
            self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_ADD_COMPONENTS, entity.Instance, componentList)
        end
    end
end


function ECSWorld_Server:RemoveComponentsFromEntity(entity, componentList)
    assert(self:HasEntity(entity) == true)

    self:_RemoveComponentsFromEntity(entity, componentList)

    self:_UpdateEntity(entity)

    if (entity._IsServerSide == false) then
        local _, componentCount = self:FilterServerComponents(componentList)

        if (componentCount > 0) then
            self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS, entity.Instance, componentList)
        end
    end
end


function ECSWorld_Server:AddAndRemoveComponentsFromEntity(entity, componentsToAdd, componentsToRemove)
    assert(self:HasEntity(entity) == true)

    self:_AddComponentsToEntity(entity, componentsToAdd)
    self:_RemoveComponentsFromEntity(entity, componentsToRemove)

    self:_UpdateEntity(entity)

    if (entity._IsServerSide == false) then
        local _, toAddCount = self:FilterServerComponents(componentsToAdd)
        local _, toRemoveCount = self:FilterServerComponents(componentsToRemove)

        if (toAddCount > 0 or toRemoveCount > 0) then
            self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_ADD_REMOVE_COMPONENTS, entity.Instance, componentsToAdd, componentsToRemove)
        end
    end
end


function ECSWorld_Server:RemoveEntity(entity)
    assert(IsEntity(entity) == true)

    if (TableContains(self._Entities, entity) == false) then
        return
    end

    if (entity._IsServerSide == false) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_REMOVE, entity.Instance)
    end

    ECSWorld.RemoveEntity(self, entity)
end


--Components

function ECSWorld_Server:IsComponentServerOnly(componentName)
    local componentDesc = self:GetComponent(componentName)

    return componentDesc ~= nil and componentDesc.IsServerOnly == true
end


function ECSWorld_Server:RegisterComponent(componentDesc)
    assert(IsComponentDescription(componentDesc), "ECSWorld :: RegisterComponent() Argument [1] is not a \"" .. COMPONENT_DESC_CLASSNAME .. "\"!")

    local isServerSide = componentDesc.IsServerSide
    
    if (isServerSide ~= nil and isServerSide ~= true) then
        error()
    end

    ECSWorld.RegisterComponent(self, componentDesc)
end


function ECSWorld_Server:FilterServerComponents(componentList)
    local componentCount = 0

    for componentName, componentData in pairs(componentList) do
        if (componentData ~= nil) then
            if (self:IsComponentServerOnly(componentName) == true) then
                componentList[componentName] = nil
            else
                componentCount = componentCount + 1
            end
        end
    end

    return componentList, componentCount
end


--Systems

function ECSWorld_Server:RegisterSystem(system)
    assert(IsSystem(system), "ECSWorld :: RegisterSystem() Argument [1] is not a \"" .. SYSTEM_CLASSNAME .. "\"!")

    local isServerSide = system.IsServerSide

    if (isServerSide ~= nil and isServerSide ~= true) then
        error()
    end

    ECSWorld.RegisterSystem(self, system)
end


--Resources and Prefabs

function ECSWorld_Server:CreateEntitiesFromResource(resource, parent, data, isServerSide)
    isServerSide = isServerSide or false
    assert(type(isServerSide) == "boolean")
    
    parent = parent or self.DefaultGlobalEntityInstanceParent
    
    local rootInstance, newEntities, rootEntity = self:_CreateEntitiesFromResource(resource, parent, data)

    assert(rootInstance ~= nil, "Unable to load resource!" .. tostring(newEntities))

    for _, entity in pairs(newEntities) do
        entity._IsServerSide = isServerSide
        self:_UpdateEntity(entity)
    end

    if (isServerSide == false) then
        for _, entity in pairs(newEntities) do
            self:_FireAllClientsEntityCreated(entity)
        end
    end

    return rootInstance, newEntities, rootEntity
end


--Constructor/Deconstructor

function ECSWorld_Server:Destroy()
    self._ServerComponents = {}

    self.OnPlayerReady:Destroy()
    self.OnPlayerLeft:Destroy()

    self._RemoteEvent = nil

    self._RemoteEventConnection:Disconnect()
    self._PlayerLeftConnection:Disconnect()

    ECSWorld.Destroy(self)

    setmetatable(self, nil)
end


function ECSWorld_Server.new(remoteEvent, name)
    assert(typeof(remoteEvent) == "Instance" and remoteEvent:IsA("RemoteEvent"))
    --warn/error if remote event cannot be seen by client? nah

    local self = setmetatable(ECSWorld.new(name), ECSWorld_Server)

    self.DefaultGlobalEntityInstanceParent = ReplicatedStorage

    self._ServerComponents = {}

    self.OnPlayerReady = Signal.new()
    self.OnPlayerLeft = Signal.new()

    self._IsServer = true
    
    self._RemoteEvent = remoteEvent

    self._RemoteEventConnection = remoteEvent.OnServerEvent:Connect(function(player, eventType, ...)
        if (eventType == REMOTE_EVENT_PLAYER_READY) then
            self:_PlayerReady(player)
        end
    end)

    self._PlayerLeftConnection = Players.PlayerRemoving:Connect(function(player)
        self:_PlayerLeft(self, player)
    end)


    return self
end


return ECSWorld_Server