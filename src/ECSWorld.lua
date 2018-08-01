
local ECSEntity = require(script.Parent.ECSEntity)
local ECSComponent = require(script.Parent.ECSComponent)
local ECSSystem = require(script.Parent.ECSSystem)

local Table = require(script.Parent.Table)
local GetComponentDataFromInstance = require(script.Parent.GetComponentDataFromInstance)

local TableContains = Table.Contains
local TableMerge = Table.Merge
local TableCopy = Table.Copy
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local TableContainsAnyIndex = Table.TableContainsAnyIndex

local COMPONENT_DESC_CLASSNAME = "ECSComponentDescription"
local SYSTEM_CLASSNAME = "ECSSystem"
local ENTITY_INSTANCE_COMPONENT_DATA_NAME = "COMPONENTS"

local ENTITY_DATA_INDEXES = {
    "Instance";
    "Components";
    "Tags";
    "UpdateEntity";
}


local ECSWorld = {
    ClassName = "ECSWorld";
}

ECSWorld.__index = ECSWorld


function ECSWorld:GetEntityFromInstance(instance)   --need to redo
    for _, entity in pairs(self._Entities) do
        if (entity:ContainsInstance(instance) == true) then
            return entity
        end
    end

    return nil
end


function ECSWorld:GetEntityFromInstance(instance)
    local currentEntity = nil

    for _, entity in pairs(self._Entities) do
        if (entity:ContainsInstance(instance) == true) then
            if (currentEntity ~= nil) then
                if (currentEntity.Instance:IsAncestorOf(entity.Instance) == true) then
                    currentEntity = entity
                end
            else
                currentEntity = entity
            end
        end
    end

    return currentEntity
end


function ECSWorld:GetSystem(systemName)
    for _, system in pairs(self._Systems) do
        if (system.SystemName == systemName) then
            return system
        end
    end

    return nil
end


function ECSWorld:_GetComponentDescription(componentName)
    return self._RegisteredComponents[componentName]
end


function ECSWorld:_CreateComponent(componentName, data, instance)
    local componentDesc = self:_GetComponentDescription(componentName)

    if (componentDesc ~= nil) then
        local newComponent = ECSComponent.new(componentDesc, data, instance)

        return newComponent
    end

    return nil
end


function ECSWorld:RegisterComponent(componentDesc)
    if (typeof(componentDesc) == "Instance" and componentDesc:IsA("ModuleScript") == true) then
        local success, message = pcall(function()
            componentDesc = require(componentDesc)
        end)

        assert(success == true, message)
    end

    assert(type(componentDesc) == "table", "")
    assert(componentDesc._IsComponentDescription == true, "ECSWorld :: RegisterComponent() Argument [1] is not a \"" .. COMPONENT_DESC_CLASSNAME .. "\"! ClassName = " .. tostring(componentDesc.ClassName))

    local componentName = componentDesc.ComponentName

    if (self:_GetComponentDescription(componentName) ~= nil) then
        warn("ECS World " .. self.Name .. " - Component already registered with the name " .. componentName)
    end

    self._RegisteredComponents[componentName] = componentDesc
end


function ECSWorld:RegisterComponents(...)
    local componentDescs = {...}

    self:RegisterComponentsFromList(componentDescs)
end


function ECSWorld:RegisterComponentsFromList(componentDescs)
    assert(type(componentDescs) == "table", "")

    for _, componentDesc in pairs(componentDescs) do
        self:RegisterComponent(componentDesc)
    end
end


function ECSWorld:RegisterSystem(system)
    if (typeof(system) == "Instance" and system:IsA("ModuleScript") == true) then
        local success, message = pcall(function()
            system = require(system)
        end)

        assert(success == true, message)
    end

    assert(type(system) == "table", "")
    assert(system._IsSystem == true, "ECSWorld :: RegisterSystem() Argument [1] is not a \"" .. SYSTEM_CLASSNAME .. "\"! ClassName = " .. tostring(system.SystemName))

    local systemName = system.SystemName

    if (self:GetSystem(systemName) ~= nil) then
        error("ECS World " .. self.Name .. " - System already registered with the name \"" .. systemName .. "\"!")
    end

    table.insert(self._Systems, system)

    system:Initialize()
end


function ECSWorld:RegisterSystems(...)
    local systemDescs = {...}

    self:RegisterSystemsFromList(systemDescs)
end


function ECSWorld:RegisterSystemsFromList(systemDescs)
    assert(type(systemDescs) == "table", "")

    for _, systemDesc in pairs(systemDescs) do
        self:RegisterSystem(systemDesc)
    end
end


function ECSWorld:EntityBelongsInSystem(system, entity)
    local systemComponents = system.Components

    return (#systemComponents > 0 and entity:HasComponents(systemComponents))
end


function ECSWorld:CreateEntity(...)
    local instance = nil
    local componentList = {}
    local tags = {}
    local updateEntity = true

    local function SetData(data)
        local firstIndex = data[1]

        if (type(firstIndex) == "string") then
            tags = data
        elseif (type(firstIndex) == "table") then
            componentList = data
        elseif (TableContainsAnyIndex(data, ENTITY_DATA_INDEXES) == true) then
            if (typeof(data.Instance) == "Instance" and instance ~= nil) then
                instance = data.Instance
            end
    
            if (type(data.Components) == "table") then
                componentList = data.Components
            end
    
            if (type(data.UpdateEntity) == "boolean") then
                updateEntity = data.UpdateEntity
            end
    
            if (type(data.Tags) == "table") then
                tags = data.Tags
            end
        else
            componentList = data
        end
    end

    local entityData = {...}

    for _, eData in pairs(entityData) do
        if (typeof(eData) == "Instance") then
            instance = eData
        elseif (type(eData) == "boolean") then
            updateEntity = eData
        elseif (type(eData) == "table") then
            SetData(eData)
        end
    end

    
    if (instance ~= nil) then
        local entityInstanceComponentData = instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME)

        if (entityInstanceComponentData ~= nil) then
            for _, componentInstanceData in pairs(entityInstanceComponentData:GetChildren()) do
                local componentName = componentInstanceData.Name
                local componentData = GetComponentDataFromInstance(componentInstanceData)
                local currentComponentData = componentList[componentName]

                if (currentComponentData ~= nil) then
                    componentData = TableMerge(componentData, currentComponentData)
                end

                componentList[componentName] = componentData
            end
        end
    end

    local entity = ECSEntity.new(instance, tags)

    local function AddComponentToEntity(entity, componentName, componentData)
        local newComponent = self:_CreateComponent(componentName, componentData)
    
        if (newComponent ~= nil) then
            entity:AddComponent(componentName, newComponent)
        end
    end

    for componentName, componentData in pairs(componentList) do
        AddComponentToEntity(entity, componentName, componentData)
    end

    entity.World = self
    table.insert(self._Entities, entity)

    if (updateEntity ~= false) then
        self:_UpdateEntity(entity)
    end

    return entity
end


function ECSWorld:_RemoveEntity(entity)
    if (entity._IsBeingRemoved ~= true) then
        entity._IsBeingRemoved = true   --set flag to true

        local registeredSystems = TableCopy(entity:GetRegisteredSystems())

        for _, systemName in pairs(registeredSystems) do
            local system = self:GetSystem(systemName)
            if (system ~= nil) then
                system:RemoveEntity(entity)
            end
        end
    end
end


function ECSWorld:RemoveEntity(entity)
    if (TableContains(self._Entities, entity) == false) then
        return
    end

    self:_RemoveEntity(entity)
end


function ECSWorld:RemoveEntitiesWithTag(tag)
    for _, entity in pairs(self._Entities) do
        if (entity:HasTag(tag) == true) then
            self:_RemoveEntity(entity)
        end
    end
end


function ECSWorld:RemoveEntitiesWithTags(...)
    local tags = {...}

    for _, entity in pairs(self._Entities) do
        if (entity:HasTags(tags) == true) then
            self:_RemoveEntity(entity)
        end
    end
end


function ECSWorld:ForceRemoveEntity(entity)
    AttemptRemovalFromTable(self._Entities, entity)

    pcall(function()
        entity:Destroy()
    end)
end


function ECSWorld:_AddComponentToEntity(entity, componentName, componentData)
    assert(type(componentName) == "string" and type(componentData) == "table")

    local newComponent = self:_CreateComponent(componentName, componentData)

    if (newComponent ~= nil) then
        entity:AddComponent(componentName, newComponent)
    end
end


function ECSWorld:_RemoveComponentFromEntity(entity, componentName)
    assert(type(componentName) == "string")

    entity:RemoveComponent(componentName)
end


function ECSWorld:AddComponentsToEntity(entity, componentList)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")

    for componentName, componentData in pairs(componentList) do
        self:_AddComponentToEntity(entity, componentName, componentData)
    end

    self:_UpdateEntity(entity)
end


function ECSWorld:RemoveComponentsFromEntity(entity, componentList)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")

    for componentName, componentData in pairs(componentList) do
        self:_RemoveComponentFromEntity(entity, componentName)
    end

    self:_UpdateEntity(entity)
end


function ECSWorld:_UpdateEntity(entity)  --update after it's components have changed or it was just added
    if (entity._IsBeingRemoved == true) then
        return
    end

    for _, systemName in pairs(entity:GetRegisteredSystems()) do
        local system = self:GetSystem(systemName)
        
        if (system ~= nil and self:EntityBelongsInSystem(system, entity) == false) then
            system:RemoveEntity(entity)
        end
    end

    for _, system in pairs(self._Systems) do
        if (self:EntityBelongsInSystem(system, entity) == true) then
            system:AddEntity(entity)
        end
    end
end


function ECSWorld:UpdateEntity(entity)
    assert(TableContains(self._Entities, entity) == true)

    self:_UpdateEntity(entity)
end


function ECSWorld.new(name)
    local self = setmetatable({}, ECSWorld)

    self.Name = name

    self._Entities = {}

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

    self._RegisteredComponents = {}

    self._Systems = {}
    --self._EntitySystems = {}  --if i wanted to separate systems that look for components in entity
        --to those that i just want to registered to this world


    return self
end


return ECSWorld