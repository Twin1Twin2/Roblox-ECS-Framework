
local RunService = game:GetService("RunService")

local ECSWorld = require(script.Parent.ECSWorld)
local ECSSystem = require(script.Parent.ECSSystem)
local ECSEngineConfiguration = require(script.Parent.ECSEngineConfiguration)


local ECSEngine = {
    ClassName = "ECSEngine";
}

ECSEngine.__index = ECSEngine

local LOCKMODE_OPEN = ECSSystem.LOCKMODE_OPEN
local LOCKMODE_LOCKED = ECSSystem.LOCKMODE_LOCKED
local LOCKMODE_ERROR = ECSSystem.LOCKMODE_ERROR


function ECSEngine:RenderSteppedUpdate(stepped)
    for _, system in pairs(self._RenderSteppedUpdateSystems) do
        system:SetLockMode(LOCKMODE_LOCKED)
        system:Update(stepped)
        system:SetLockMode(LOCKMODE_OPEN)
    end
end


function ECSEngine:SteppedUpdate(t, stepped)
    self.World.T = t  --idk

    for _, system in pairs(self._SteppedUpdateSystems) do
        system:SetLockMode(LOCKMODE_LOCKED)
        system:Update(stepped)
        system:SetLockMode(LOCKMODE_OPEN)
    end
end


function ECSEngine:HeartbeatUpdate(stepped)
    for _, system in pairs(self._HeartbeatUpdateSystems) do 
        system:SetLockMode(LOCKMODE_LOCKED)
        system:Update(stepped)
        system:SetLockMode(LOCKMODE_OPEN)
    end
end


function ECSEngine:Destroy()
    if (self.World ~= nil) then
        self.World:Destroy()
    end

    if (self._RenderSteppedUpdateConnection ~= nil) then
        self._RenderSteppedUpdateConnection:Disconnect()
    end

    if (self._SteppedUpdateConnection ~= nil) then
        self._SteppedUpdateConnection:Disconnect()
    end

    if (self._HeartbeatUpdateConnection ~= nil) then
        self._HeartbeatUpdateConnection:Disconnect()
    end

    self.World = nil

    setmetatable(self, nil)
end


function ECSEngine.new(engineConfiguration)
    assert(type(engineConfiguration) == "table" and engineConfiguration.ClassName == "ECSEngineConfiguration")

    local self = setmetatable({}, ECSEngine)

    local isServer = engineConfiguration.IsServer
    local remoteEvent = engineConfiguration.RemoteEvent

    self.World = ECSWorld.new(engineConfiguration.WorldName, isServer, remoteEvent)
    
    self._RenderSteppedUpdateSystems = {}
    self._SteppedUpdateSystems = {}
    self._HeartbeatUpdateSystems = {}

    self._RenderSteppedUpdateConnection = nil
    self._SteppedUpdateConnection = nil
    self._HeartbeatUpdateConnection = nil

    self.World:RegisterComponentsFromList(engineConfiguration.Components)
    self.World:RegisterSystemsFromList(engineConfiguration.Systems, false)

    self.World:InitializeSystems()

    self._RenderSteppedUpdateSystems = engineConfiguration.RenderSteppedSystems
    self._SteppedUpdateSystems = engineConfiguration.SteppedSystems
    self._HeartbeatUpdateSystems = engineConfiguration.HeartbeatSystems

    if (isServer == false or isServer == nil) then  --assume client
        self._RenderSteppedUpdateConnection = RunService.RenderStepped:Connect(function(stepped)
            self:RenderSteppedUpdate(stepped)
        end)
    end

    self._SteppedUpdateConnection = RunService.Stepped:Connect(function(t, stepped)
        self:SteppedUpdate(t, stepped)
    end)

    self._HeartbeatUpdateConnection = RunService.Heartbeat:Connect(function(stepped)
        self:HeartbeatUpdate(stepped)
    end)
    

    return self
end


return ECSEngine