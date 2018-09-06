
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


function ECSEngineConfiguration:AddRenderSteppedSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.RenderSteppedSystems, system) == false) then
        table.insert(self.RenderSteppedSystems, system)
    end

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddSteppedSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.SteppedSystems, system) == false) then
        table.insert(self.SteppedSystems, system)
    end    

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddHeartbeatSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.HeartbeatSystems, system) == false) then
        table.insert(self.HeartbeatSystems, system)
    end

    self:_AddSystem(system)
end


function ECSEngineConfiguration:AddUserInterfaceSystem(system)
    assert(IsSystem(system))

    if (TableContains(self.UserInterfaceSystems, system) == false) then
        table.insert(self.UserInterfaceSystems, system)
    end

    self:_AddSystem(system)
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
    
    if (type(isServer) == "boolean") then
        self.IsServer = isServer
    end


    return self
end


return ECSEngineConfiguration