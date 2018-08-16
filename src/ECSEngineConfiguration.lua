
local Table = require(script.Parent.Table)

local TableContains = Table.Contains


local ECSEngineConfiguration = {
    ClassName = "ECSEngineConfiguration";
}

ECSEngineConfiguration.__index = ECSEngineConfiguration


function ECSEngineConfiguration:AddComponent(component)
    assert(type(component) == "table" and component._IsComponentDescription == true)

    if (TableContains(self.Components, component) == true) then
        return
    end

    table.insert(self.Components, component)
end


function ECSEngineConfiguration:AddComponents(...)
    local componentList = {...}

    if (#componentList == 1 and type(componentList[1]) == "table" and componentList[1]._IsComponentDescription == nil) then
        componentList = componentList[1]
    end

    self:AddComponentsFromList(componentList)
end


function ECSEngineConfiguration:AddComponentsFromList(componentList)
    for _, component in pairs(componentList) do
        self:AddComponent(component)
    end
end


function ECSEngineConfiguration:AddSystem(system)
    assert(type(system) == "table" and system._IsSystem == true, "Object is not a system!")

    if (TableContains(self.Systems, system) == true) then
        return
    end

    table.insert(self.Systems, system)
end


function ECSEngineConfiguration:AddSystems(...)
    local systemList = {...}

    if (#systemList == 1 and type(systemList[1]) == "table" and systemList[1]._IsSystem == nil) then
        systemList = systemList[1]
    end

    self:AddSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddSystemsFromList(systemList)
    for index, system in pairs(systemList) do
        local updateType = 0

        if (type(system) == "number" and type(index) == "table") then
            updateType = system
            system = index
        elseif (type(system) == "table" and type(system.SystemUpdateType) == "number") then
            updateType = system.SystemUpdateType
        end

        if (updateType == 0) then
            self:AddSystem(system)
        elseif (updateType == 1) then
            self:AddRenderSteppedSystem(system)
        elseif (updateType == 2) then
            self:AddSteppedSystem(system)
        elseif (updateType == 3) then
            self:AddHeartbeatSystem(system)
        end
    end
end


function ECSEngineConfiguration:AddRenderSteppedSystem(system)
    assert(type(system) == "table" and system._IsSystem == true)

    if (TableContains(self.RenderSteppedSystems, system) == true) then
        return
    end

    table.insert(self.RenderSteppedSystems, system)

    self:AddSystem(system)
end


function ECSEngineConfiguration:AddRenderSteppedSystems(...)
    local systemList = {...}

    if (#systemList == 1 and type(systemList[1]) == "table" and systemList[1]._IsSystem == nil) then
        systemList = systemList[1]
    end

    self:AddRenderSteppedSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddRenderSteppedSystemsFromList(systemsList)
    for _, system in pairs(systemsList) do
        self:AddRenderSteppedSystem(system)
    end
end


function ECSEngineConfiguration:AddSteppedSystem(system)
    assert(type(system) == "table" and system._IsSystem == true)

    if (TableContains(self.SteppedSystems, system) == true) then
        return
    end

    table.insert(self.SteppedSystems, system)

    self:AddSystem(system)
end


function ECSEngineConfiguration:AddSteppedSystems(...)
    local systemList = {...}

    if (#systemList == 1 and type(systemList[1]) == "table" and systemList[1]._IsSystem == nil) then
        systemList = systemList[1]
    end

    self:AddSteppedSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddSteppedSystemsFromList(systemsList)
    for _, system in pairs(systemsList) do
        self:AddSteppedSystem(system)
    end
end


function ECSEngineConfiguration:AddHeartbeatSystem(system)
    assert(type(system) == "table" and system._IsSystem == true)

    if (TableContains(self.HeartbeatSystems, system) == true) then
        return
    end

    table.insert(self.HeartbeatSystems, system)

    self:AddSystem(system)
end


function ECSEngineConfiguration:AddHeartbeatSystems(...)
    local systemList = {...}

    if (#systemList == 1 and type(systemList[1]) == "table" and systemList[1]._IsSystem == nil) then
        systemList = systemList[1]
    end

    self:AddHeartbeatSystemsFromList(systemList)
end


function ECSEngineConfiguration:AddHeartbeatSystemsFromList(systemsList)
    for _, system in pairs(systemsList) do
        self:AddHeartbeatSystem(system)
    end
end


function ECSEngineConfiguration.new(name)
    local self = setmetatable({}, ECSEngineConfiguration)

    self.WorldName = name or "WORLD"

    self.Components = {}

    self.Systems = {}

    self.RenderSteppedSystems = {}
    self.SteppedSystems = {}
    self.HeartbeatSystems = {}


    return self
end


return ECSEngineConfiguration