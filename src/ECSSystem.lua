--- System
--

local ECSComponentRequirement = require(script.Parent.ECSComponentRequirement)

local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsComponentRequirement = Utilities.IsComponentRequirement

local GetEntityInListFromInstance = Utilities.GetEntityInListFromInstance
local GetEntityInListContainingInstance = Utilities.GetEntityInListContainingInstance

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local TableCopy = Table.Copy


local ECSSystem = {
    ClassName = "ECSSystem";

    LOCKMODE_OPEN = 0;
    LOCKMODE_LOCKED = 1;
    LOCKMODE_ERROR = 2;
}

ECSSystem.__index = ECSSystem

local LOCKMODE_OPEN = ECSSystem.LOCKMODE_OPEN
local LOCKMODE_LOCKED = ECSSystem.LOCKMODE_LOCKED
local LOCKMODE_ERROR = ECSSystem.LOCKMODE_ERROR



function ECSSystem:GetComponentList()
    return self.ComponentRequirement:GetComponentList()
end


function ECSSystem:EntityBelongs(entity)
    return self.ComponentRequirement:EntityBelongs(entity)
end


function ECSSystem:GetEntityFromInstance(instance)
    return GetEntityInListFromInstance(self.Entities, instance)
end


function ECSSystem:GetEntityInListContainingInstance(instance)
    return GetEntityInListContainingInstance(self.Entities, instance)
end


function ECSSystem:_AddEntity(entity)
    if (TableContains(self.Entities, entity) == false) then
        table.insert(self.Entities, entity)

        entity:RegisterSystem(self.SystemName) --change to ECSEntity.RegisterSystem(entity, self) ?

        self:EntityAdded(entity)
    end
end


function ECSSystem:_RemoveEntity(entity)
    local wasRemoved = AttemptRemovalFromTable(self.Entities, entity)

    if (wasRemoved == true) then
        self:EntityRemoved(entity)

        entity:UnregisterSystem(self.SystemName)
    end
end


function ECSSystem:SetLockMode(newLockMode)
    self.LockMode = newLockMode

    if (#self._EntitiesToAdd > 0) then
        local entitiesToAdd = TableCopy(self._EntitiesToAdd)
        self._EntitiesToAdd = {}

        for _, entity in pairs(entitiesToAdd) do
            self:_AddEntity(entity)
        end
    end

    if (#self._EntitiesToRemove > 0) then
        local entitiesToRemove = TableCopy(self._EntitiesToRemove)
        self._EntitiesToRemove = {}

        for _, entity in pairs(entitiesToRemove) do
            self:_RemoveEntity(entity)
        end
    end
end


function ECSSystem:AddEntity(entity)
    local lockMode = self.LockMode

    if (lockMode == LOCKMODE_OPEN) then
        self:_AddEntity(entity)
    elseif (lockMode == LOCKMODE_LOCKED) then
        if (TableContains(self.Entities, entity) == false and TableContains(self._EntitiesToAdd, entity) == false) then
            table.insert(self._EntitiesToAdd, entity)
        end
    elseif (lockMode == LOCKMODE_ERROR) then
        error("Cannot add or remove entities at this time!", 2)
    end
end


function ECSSystem:RemoveEntity(entity)
    local lockMode = self.LockMode

    if (lockMode == LOCKMODE_OPEN) then
        self:_RemoveEntity(entity)
    elseif (lockMode == LOCKMODE_LOCKED) then
        if (TableContains(self.Entities, entity) == true and TableContains(self._EntitiesToRemove, entity) == false) then
            table.insert(self._EntitiesToRemove, entity)
        end
    elseif (lockMode == LOCKMODE_ERROR) then
        error("Cannot add or remove entities at this time!", 2)
    end
end


function ECSSystem:Initialize()
    -- callback
end


function ECSSystem:RegisteredToWorld(world)
    -- callback
end


function ECSSystem:UnregisteredFromWorld(world)
    -- callback
end


function ECSSystem:EntityAdded(entity)
    -- callback
end


function ECSSystem:EntityRemoved(entity)
    -- callback
end


function ECSSystem:Update(stepped)
    -- callback
end


function ECSSystem:UpdateSystem(stepped)
    self:SetLockMode(LOCKMODE_LOCKED)
    self:Update(stepped)
    self:SetLockMode(LOCKMODE_OPEN)
end


function ECSSystem:Destroy()
    if (self.World ~= nil) then
        self.World:UnregisterSystem(self)
    end

    self._EntitiesToAdd = nil
    self._EntitiesToRemove = nil

    self.World = nil
    self.Components = nil
    self.Entities = nil

    setmetatable(self, nil)
end


function ECSSystem.new(name, componentRequirement)
    assert(type(name) == "string")
    assert(componentRequirement == nil or IsComponentRequirement(componentRequirement))

    local self = setmetatable({}, ECSSystem)

    self._IsSystem = true
    self._IsInitialized = false

    self.Name = name

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

    self.Entities = {}
    self.World = nil
    self.ComponentRequirement = componentRequirement or ECSComponentRequirement.new(name)

    self.UpdatePriority = -1    -- higher the number, the lower the priority (when it will be updated)

    self.IsServerSide = nil     -- if not nil, boolean for whether it is server-side only or client-side only

    self._ShouldUpdateEntityList = false


    return self
end


return ECSSystem