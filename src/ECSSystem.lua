--- System
--

local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local GetEntityInListFromInstance = Utilities.GetEntityInListFromInstance
local GetEntityInListContainingInstance = Utilities.GetEntityInListContainingInstance

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local Merge = Table.Merge
local DeepCopy = Table.DeepCopy
local TableCopy = Table.Copy
local AltMerge = Table.AltMerge


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

--
local INDEX_BLACKLIST = {
    ClassName = true;

    LOCKMODE_OPEN = true;
    LOCKMODE_LOCKED = true;
    LOCKMODE_ERROR = true;

    SetLockMode = true;
    AddEntity = true;
    RemoveEntity = true;
    _AddEntity = true;
    _RemoveEntity = true;

    _EntitiesToAdd = true;
    _EntitiesToRemove = true;

    World = true;
    Entities = true;
}


function ECSSystem:GetComponentList()
    if (self._CachedComponentList == nil) then
        self:UpdateComponentList()
    end

    return self._CachedComponentList
end


function ECSSystem:EntityBelongs(entity)
    local systemComponents = self:GetComponentList()

    return #systemComponents > 0 and entity:HasComponents(systemComponents)
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
        for _, entity in pairs(self._EntitiesToAdd) do
            self:_AddEntity(entity)
        end

        self._EntitiesToAdd = {}
    end

    if (#self._EntitiesToRemove > 0) then
        for _, entity in pairs(self._EntitiesToRemove) do
            self:_RemoveEntity(entity)
        end

        self._EntitiesToRemove = {}
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


function ECSSystem:UpdateComponentList()
    local componentList = TableCopy(self.Components)

    for _, componentGroup in pairs(self.ComponentGroups) do
        local componentGroupComponents = componentGroup:GetComponentList()
        AltMerge(componentList, componentGroupComponents)
    end

    self._CachedComponentList = componentList
end


function ECSSystem:Initialize()

end


function ECSSystem:EntityAdded(entity)

end


function ECSSystem:EntityRemoved(entity)

end


function ECSSystem:Update(stepped)
    
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

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

    self.World = nil
    self.Components = nil    --the names of the components this system needs
    self.Entities = nil

    setmetatable(self, nil)
end


function ECSSystem:Extend(name)
    assert(type(name) == "string")

    local this = {}
    
    this.SystemName = name

    function this.new()
        local t = ECSSystem.new(name)

        for index, value in pairs(this) do
            if (INDEX_BLACKLIST[index] == nil) then
                t[index] = DeepCopy(value)
            end
        end

        return t
    end

    return this
end


function ECSSystem.new(name)
    assert(type(name) == "string")

    local self = setmetatable({}, ECSSystem)

    self._IsSystem = true
    self._IsInitialized = false

    self.Name = name

    self.LockMode = LOCKMODE_OPEN

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

    self.World = nil
    self.Components = {}    --the names of the components this system needs
    self.ComponentGroups = {}
    self.Entities = {}

    self._CachedComponentList = nil

    self.UpdatePriority = -1   --higher the number, the lower the priority (when it will be updated)

    self.IsServerSide = nil


    return self
end


return ECSSystem