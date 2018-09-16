
local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsComponentDescription = Utilities.IsComponentDescription
local IsSystem = Utilities.IsSystem

local TableContains = Table.Contains

local SYSTEM_UPDATE_TYPE = Utilities.SYSTEM_UPDATE_TYPE

local SYSTEM_UPDATE_TYPE_NO_UPDATE = SYSTEM_UPDATE_TYPE.NO_UPDATE
local SYSTEM_UPDATE_TYPE_RENDER_STEPPED = SYSTEM_UPDATE_TYPE.RENDER_STEPPED
local SYSTEM_UPDATE_TYPE_STEPPED = SYSTEM_UPDATE_TYPE.STEPPED
local SYSTEM_UPDATE_TYPE_HEARTBEAT = SYSTEM_UPDATE_TYPE.HEARTBEAT
local SYSTEM_UPDATE_TYPE_UI = SYSTEM_UPDATE_TYPE.UI


local ECSEngineConfiguration = {
    ClassName = "ECSEngineConfiguration";
}

ECSEngineConfiguration.__index = ECSEngineConfiguration


function ECSEngineConfiguration:AddComponent(component)
    assert(IsComponentDescription(component))

    if (TableContains(self.Components, component) == false) then
        table.insert(self.Components, component)
    end 
end


function ECSEngineConfiguration:AddComponents(...)
    local componentList = {...}

    self:AddComponentsFromList(componentList)
end


function ECSEngineConfiguration:AddComponentsFromList(componentList)
    assert(type(componentList) == "table")

    for _, component in pairs(componentList) do
        self:AddComponent(component)
    end
end


function ECSEngineConfiguration:_AddSystem(system)
    if (TableContains(self.Systems, system) == false) then
        table.insert(self.Systems, system)
    end
end


function ECSEngineConfiguration:AddSystem(system, type)
    assert(IsSystem(system))

    if (type == SYSTEM_UPDATE_TYPE_RENDER_STEPPED) then
        self:AddRenderSteppedSystem(system)
    elseif (type == SYSTEM_UPDATE_TYPE_STEPPED) then
        self:AddSteppedSystem(system)
    elseif (type == SYSTEM_UPDATE_TYPE_HEARTBEAT) then
        self:AddHeartbeatSystem(system)
    elseif (type == SYSTEM_UPDATE_TYPE_UI) then
        self:AddUserInterfaceSystem(system)
    else
        self:_AddSystem(system)
    end
end


function ECSEngineConfiguration:AddSystems(...)
    local systemList = {...}

    self:AddSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddSystemsFromList(systemList)
    assert(type(systemList) == "table")

    for _, system in pairs(systemList) do
        self:AddSystem(system)
    end
end


function ECSEngineConfiguration:AddRenderSteppedSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.RenderSteppedSystems, system) == false) then
        table.insert(self.RenderSteppedSystems, system)
    end

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddRenderSteppedSystems(...)
    local systemList = {...}

    self:AddRenderSteppedSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddRenderSteppedSystemsFromList(systemList)
    assert(type(systemList) == "table")

    for _, system in pairs(systemList) do
        self:AddRenderSteppedSystem(system)
    end
end


function ECSEngineConfiguration:AddSteppedSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.SteppedSystems, system) == false) then
        table.insert(self.SteppedSystems, system)
    end    

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddSteppedSystems(...)
    local systemList = {...}

    self:AddSteppedSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddSteppedSystemsFromList(systemList)
    assert(type(systemList) == "table")

    for _, system in pairs(systemList) do
        self:AddSteppedSystem(system)
    end
end


function ECSEngineConfiguration:AddHeartbeatSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.HeartbeatSystems, system) == false) then
        table.insert(self.HeartbeatSystems, system)
    end

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddHeartbeatSystems(...)
    local systemList = {...}

    self:AddHeartbeatSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddHeartbeatSystemsFromList(systemList)
    assert(type(systemList) == "table")

    for _, system in pairs(systemList) do
        self:AddHeartbeatSystem(system)
    end
end


function ECSEngineConfiguration:AddUserInterfaceSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.UserInterfaceSystems, system) == false) then
        table.insert(self.UserInterfaceSystems, system)
    end

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddUserInterfaceSystems(...)
    local systemList = {...}

    self:AddUserInterfaceSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddUserInterfaceSystemsFromList(systemList)
    assert(type(systemList) == "table")

    for _, system in pairs(systemList) do
        self:AddUserInterfaceSystem(system)
    end
end


function ECSEngineConfiguration.new(name, isServer, remoteEvent)
    local self = setmetatable({}, ECSEngineConfiguration)

    self.WorldName = name or "WORLD"

    self.Components = {}
    self.Systems = {}

    self.RenderSteppedSystems = {}
    self.SteppedSystems = {}
    self.HeartbeatSystems = {}
    self.UserInterfaceSystems = {}

    self.IsServer = nil
    self.RemoteEvent = remoteEvent or nil

    self._IsEngineConfiguration = true
    
    if (type(isServer) == "boolean") then
        self.IsServer = isServer
    end


    return self
end


return ECSEngineConfiguration