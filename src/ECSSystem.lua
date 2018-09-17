--- System
--

local ECSComponentRequirement = require(script.Parent.ECSComponentRequirement)

local Utilities = require(script.Parent.Utilities)

local IsComponentRequirement = Utilities.IsComponentRequirement


local ECSSystem = {
    ClassName = "ECSSystem";
}

ECSSystem.__index = ECSSystem


function ECSSystem:GetComponentList()
    return self.ComponentRequirement:GetComponentList()
end


function ECSSystem:EntityBelongs(entity)
    return self.ComponentRequirement:EntityBelongs(entity)
end


function ECSSystem:GetEntities()
    -- only update the entity list whenever you want to access it
    -- if the system gets an immutable list of entities through this, then it wouldn't need
    --      the lock mode

    if (self._ShouldUpdateEntityList == true) then
        -- hmm

        self._ShouldUpdateEntityList = false
    end

    return self._Entities   -- return the list
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


function ECSSystem:Destroy()
    if (self.World ~= nil) then
        self.World:UnregisterSystem(self)
    end

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

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

    self._Entities = {}

    self.World = nil
    self.ComponentRequirement = componentRequirement or ECSComponentRequirement.new(name)

    self.UpdatePriority = -1    -- higher the number, the lower the priority (when it will be updated)

    self.IsServerSide = nil     -- if not nil, boolean for whether it is server-side only or client-side only

    self._ShouldUpdateEntityList = false


    return self
end


return ECSSystem