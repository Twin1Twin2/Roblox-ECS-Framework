
local RunService = game:GetService("RunService")

local ECSWorld = require(script.Parent.ECSWorld)
local ECSWorld_Server = require(script.Parent.ECSWorld_Server)
local ECSWorld_Client = require(script.Parent.ECSWorld_Client)
local ECSSystem = require(script.Parent.ECSSystem)
local ECSEngineConfiguration = require(script.Parent.ECSEngineConfiguration)

local Utilities = require(script.Parent.Utilities)

local IsEngineConfiguration = Utilities.IsEngineConfiguration


local USER_INTERFACE_UPDATE_RENDER_PRIORITY = Enum.RenderPriority.First.Value


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


function ECSEngine:UserInterfaceUpdate(stepped) --keep the ui thread separate i guess
    for _, system in pairs(self._UserInterfaceUpdateSystems) do 
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

    RunService:UnbindFromRenderStep(self._UserInterfaceUpdateName)

    self.World = nil

    setmetatable(self, nil)
end


function ECSEngine.new(engineConfiguration)
    assert(IsEngineConfiguration(engineConfiguration))

    local self = setmetatable({}, ECSEngine)

    local isServer = engineConfiguration.IsServer
    local remoteEvent = engineConfiguration.RemoteEvent
    local worldName = engineConfiguration.WorldName

    self.World = nil

    if (type(isServer) == "boolean") then
        assert(typeof(remoteEvent) == "Instance" and remoteEvent:IsA("RemoteEvent"))
        if (isServer == true) then
            self.World = ECSWorld_Server.new(remoteEvent, worldName)
        else
            self.World = ECSWorld_Client.new(remoteEvent, worldName)
        end
    else
        self.World = ECSWorld.new(worldName)
    end
    
    self._RenderSteppedUpdateSystems = {}
    self._SteppedUpdateSystems = {}
    self._HeartbeatUpdateSystems = {}
    self._UserInterfaceUpdateSystems = {}

    self._RenderSteppedUpdateConnection = nil
    self._SteppedUpdateConnection = nil
    self._HeartbeatUpdateConnection = nil
    self._UserInterfaceUpdateName = nil

    for _, component in pairs(engineConfiguration.Components) do
        self.World:RegisterComponent(component)
    end

    for _, system in pairs(engineConfiguration.Systems) do
        self.World:RegisterSystem(system, false)
    end

    for _, system in pairs(engineConfiguration.Systems) do
        self.World:_InitializeSystem(system)
    end

    self._RenderSteppedUpdateSystems = engineConfiguration.RenderSteppedSystems
    self._SteppedUpdateSystems = engineConfiguration.SteppedSystems
    self._HeartbeatUpdateSystems = engineConfiguration.HeartbeatSystems
    self._UserInterfaceUpdateSystems = engineConfiguration.UserInterfaceSystems

    if (isServer == false or isServer == nil) then  --assume client/normal
        self._RenderSteppedUpdateConnection = RunService.RenderStepped:Connect(function(stepped)
            self:RenderSteppedUpdate(stepped)
        end)

        local userInterfaceUpdateName = worldName .. "_USER_INTERFACE_UPDATE"

        local function UserInterfaceUpdateFunction(stepped)
            self:UserInterfaceUpdate(stepped)
        end

        self._UserInterfaceUpdateName = userInterfaceUpdateName
        RunService:BindToRenderStep(userInterfaceUpdateName, USER_INTERFACE_UPDATE_RENDER_PRIORITY, UserInterfaceUpdateFunction)
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