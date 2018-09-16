--- World_Client
--

local ECSWorld = require(script.Parent.ECSWorld)

local Utilities = require(script.Parent.Utilities)

local REMOTE_EVENT_ENUM = Utilities.REMOTE_EVENT_ENUM

local REMOTE_EVENT_PLAYER_READY = REMOTE_EVENT_ENUM.PLAYER_READY
local REMOTE_EVENT_ENTITY_CREATE = REMOTE_EVENT_ENUM.ENTITY_CREATE
local REMOTE_EVENT_ENTITY_ADD_COMPONENTS = REMOTE_EVENT_ENUM.ENTITY_ADD_COMPONENTS
local REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS = REMOTE_EVENT_ENUM.ENTITY_REMOTE_COMPONENTS
local REMOTE_EVENT_ENTITY_ADD_REMOVE_COMPONENTS = REMOTE_EVENT_ENUM.ENTITY_ADD_REMOVE_COMPONENTS
local REMOTE_EVENT_ENTITY_REMOVE = REMOTE_EVENT_ENUM.ENTITY_REMOTE


local ECSWorld_Client = {
    ClassName = "ECSWorld_Client";
}

ECSWorld_Client.__index = ECSWorld_Client
setmetatable(ECSWorld_Client, ECSWorld)


function ECSWorld_Client:_EntityCreatedFromServer(instance, componentList)
    self:CreateEntity(instance, componentList)
end


function ECSWorld_Client:_EntityAddedComponentsFromServer(instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_AddComponentsToEntity(entity, componentList)
        self:_UpdateEntity(entity)
    end
end


function ECSWorld_Client:_EntityRemovedComponentsFromServer(instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveComponentsFromEntity(entity, componentList)
        self:_UpdateEntity(entity)
    end
end


function ECSWorld_Client:_EntityAddedAndRemovedComponentsFromServer(instance, componentsToAdd, componentsToRemove)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_AddComponentsToEntity(entity, componentsToAdd)
        self:_RemoveComponentsFromEntity(entity, componentsToRemove)

        self:_UpdateEntity(entity)
    end
end


function ECSWorld_Client:_EntityRemovedFromServer(instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveEntity(entity)
    end
end


function ECSWorld:Ready()
    self._RemoteEvent:FireServer(REMOTE_EVENT_PLAYER_READY)
end


function ECSWorld_Client.new(remoteEvent, name)
    assert(typeof(remoteEvent) == "Instance" and remoteEvent:IsA("RemoteEvent"))

    local self = setmetatable(ECSWorld.new(name), ECSWorld_Client)

    self._IsServer = false

    self._RemoteEvent = remoteEvent

    self._RemoteEventConnection = remoteEvent.OnClientEvent:Connect(function(eventType, instance, componentList, otherComponentList)
        if (eventType == REMOTE_EVENT_ENTITY_CREATE) then
            self:_EntityCreatedFromServer(instance, componentList)
        elseif (eventType == REMOTE_EVENT_ENTITY_REMOVE) then
            self:_EntityRemovedFromServer(instance)
        elseif (eventType == REMOTE_EVENT_ENTITY_ADD_COMPONENTS) then
            self:_EntityAddedComponentsFromServer(instance, componentList)
        elseif (eventType == REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS) then
            self:_EntityRemovedComponentsFromServer(instance, componentList)
        elseif (eventType == REMOTE_EVENT_ENTITY_ADD_REMOVE_COMPONENTS) then
            self:_EntityAddedAndRemovedComponentsFromServer(instance, componentList, otherComponentList)
        else
            error("Unknown Argument [1] passed! Arg [1] = ".. tostring(eventType))
        end
    end)


    return self
end


return ECSWorld_Client