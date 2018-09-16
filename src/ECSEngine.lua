
local RunService = game:GetService("RunService")

local ECSWorld = require(script.Parent.ECSWorld)
local ECSWorld_Server = require(script.Parent.ECSWorld_Server)
local ECSWorld_Client = require(script.Parent.ECSWorld_Client)
local ECSSystem = require(script.Parent.ECSSystem)
local ECSEngineConfiguration = require(script.Parent.ECSEngineConfiguration)

local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsSystem = Utilities.IsSystem
local IsEngineConfiguration = Utilities.IsEngineConfiguration
local AddSystemToListByPriority = Utilities.AddSystemToListByPriority

local TableCopy = Table.Copy
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable

local SYSTEM_UPDATE_TYPE = Utilities.SYSTEM_UPDATE_TYPE

local SYSTEM_UPDATE_TYPE_NO_UPDATE = SYSTEM_UPDATE_TYPE.NO_UPDATE
local SYSTEM_UPDATE_TYPE_RENDER_STEPPED = SYSTEM_UPDATE_TYPE.RENDER_STEPPED
local SYSTEM_UPDATE_TYPE_STEPPED = SYSTEM_UPDATE_TYPE.STEPPED
local SYSTEM_UPDATE_TYPE_HEARTBEAT = SYSTEM_UPDATE_TYPE.HEARTBEAT
local SYSTEM_UPDATE_TYPE_UI = SYSTEM_UPDATE_TYPE.UI

local LOCKMODE_OPEN = ECSSystem.LOCKMODE_OPEN
local LOCKMODE_LOCKED = ECSSystem.LOCKMODE_LOCKED
local LOCKMODE_ERROR = ECSSystem.LOCKMODE_ERROR

local USER_INTERFACE_UPDATE_RENDER_PRIORITY = Enum.RenderPriority.First.Value


local function AddSystemToListAndSetUpdateType(system, list, updateType)
    system.UpdateType = updateType
    AddSystemToListByPriority(system, list)
end


local function AddSystemsToListAndSetUpdateType(systems, list, updateType)
    for _, system in pairs(systems) do
        AddSystemToListAndSetUpdateType(system, list, updateType)
    end
end


local ECSEngine = {
    ClassName = "ECSEngine";
}

ECSEngine.__index = ECSEngine



function ECSEngine:RegisterSystem(system, updateType)
    assert(IsSystem(system))

    updateType = updateType or system.UpdateType
    assert(type(updateType) == "number")

    self.World:RegisterSystem(system)

    system.UpdateType = updateType

    if (updateType == SYSTEM_UPDATE_TYPE_RENDER_STEPPED) then
        AddSystemToListByPriority(system, self._RenderSteppedUpdateSystems)
    elseif (updateType == SYSTEM_UPDATE_TYPE_STEPPED) then
        AddSystemToListByPriority(system, self._SteppedUpdateSystems)
    elseif (updateType == SYSTEM_UPDATE_TYPE_HEARTBEAT) then
        AddSystemToListByPriority(system, self._HeartbeatUpdateSystems)
    elseif (updateType == SYSTEM_UPDATE_TYPE_UI) then
        AddSystemToListByPriority(system, self._UserInterfaceUpdateSystems)
    end
end


function ECSEngine:UnregisterSystem(system)
    if (type(system) == "string") then
        system = self.World:GetSystem(system)

        if (system == nil) then
            return
        end
    else
        assert(IsSystem(system))

        local otherSystem = self.World:GetSystem(system.Name)
        assert(otherSystem == system, "System is not registered! Unable to remove!")
    end

    self.World:UnregisterSystem(system)

    local updateType = system.UpdateType

    if (updateType == SYSTEM_UPDATE_TYPE_RENDER_STEPPED) then
        AttemptRemovalFromTable(self._RenderSteppedUpdateSystems, system)
    elseif (updateType == SYSTEM_UPDATE_TYPE_STEPPED) then
        AttemptRemovalFromTable(self._SteppedUpdateSystems, system)
    elseif (updateType == SYSTEM_UPDATE_TYPE_HEARTBEAT) then
        AttemptRemovalFromTable(self._HeartbeatUpdateSystems, system)
    elseif (updateType == SYSTEM_UPDATE_TYPE_UI) then
        AttemptRemovalFromTable(self._UserInterfaceUpdateSystems, system)
    end
end


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

    AddSystemsToListAndSetUpdateType(engineConfiguration.RenderSteppedSystems, self._RenderSteppedUpdateSystems, SYSTEM_UPDATE_TYPE_RENDER_STEPPED)
    AddSystemsToListAndSetUpdateType(engineConfiguration.SteppedSystems, self._SteppedUpdateSystems, SYSTEM_UPDATE_TYPE_STEPPED)
    AddSystemsToListAndSetUpdateType(engineConfiguration.HeartbeatSystems, self._HeartbeatUpdateSystems, SYSTEM_UPDATE_TYPE_HEARTBEAT)
    AddSystemsToListAndSetUpdateType(engineConfiguration.UserInterfaceSystems, self._UserInterfaceUpdateSystems, SYSTEM_UPDATE_TYPE_UI)

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