
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
local ENTITY_INSTANCE_TAG_DATA_NAME = "TAGS"

local ENTITY_DATA_INDEXES = {
    "Instance";
    "Components";
    "Tags";
    "UpdateEntity";
    "CFrame";
}


local function GetCFrameFromInstance(instance)
    if (instance:IsA("Model") == true) then
        if (instance.PrimaryPart ~= nil) then
            return instance:GetPrimaryPartCFrame()
        end
    elseif (instance:IsA("BasePart") == true) then
        return instance.CFrame
    end
end


local ECSWorld = {
    ClassName = "ECSWorld";
}

ECSWorld.__index = ECSWorld

--[[
function ECSWorld:GetEntityFromInstance(instance)   --need to redo
    for _, entity in pairs(self._Entities) do
        if (entity:ContainsInstance(instance) == true) then
            return entity
        end
    end

    return nil
end
--]]

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

    if (#system.Components > 0) then
        table.insert(self._EntitySystems, system)
    end

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


local function GetEntityData(entityData)
    local instance = nil
    local componentList = {}
    local tags = {}
    local cframe = nil
    local updateEntity = true
    local initializeComponents = true

    local function AddTag(tagName)
        if (TableContains(tags, tagName) == false) then
            table.insert(tags, tagName)
        end
    end

    local function SetTagsData(newTags)
        for _, tagName in pairs(newTags) do
            AddTag(tagName)
        end
    end

    local function SetComponentListData(newComponentList)
        for componentName, componentData in pairs(newComponentList) do
            local currentComponentData = componentList[componentName]
            if (currentComponentData == nil) then
                componentList[componentName] = componentData
            else
                componentList[componentName] = TableMerge(currentComponentData, componentData)
            end
        end
    end

    local function SetInstanceData(newInstance)
        if (instance ~= nil) then
            local newCFrame = GetCFrameFromInstance(newInstance)
            if (newCFrame ~= nil) then
                cframe = newCFrame
            end
        end

        instance = newInstance

        local entityInstanceComponentData = instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME)
        local entityInstanceTagData = instance:FindFirstChild(ENTITY_INSTANCE_TAG_DATA_NAME)

        if (entityInstanceComponentData ~= nil) then
            local newComponentList = {}

            for _, componentInstanceData in pairs(entityInstanceComponentData:GetChildren()) do
                local componentName = componentInstanceData.Name
                newComponentList[componentName] = GetComponentDataFromInstance(componentInstanceData)
            end

            SetComponentListData(newComponentList)
        end

        if (entityInstanceTagData ~= nil) then
            local newTags = {}

            for _, tagInstanceData in pairs(entityInstanceTagData:GetChildren()) do
                local tagName = tagInstanceData.Name
                table.insert(newTags, tagName)
            end

            SetTagsData(newTags)
        end
    end

    local function SetBoolData(enum)
        if (enum == 0) then
            updateEntity = true
            initializeComponents = true
        elseif (enum == 1) then
            updateEntity = false
            initializeComponents = true
        elseif (enum == 2) then
            updateEntity = false
            initializeComponents = false
        end
    end

    local function SetData(data)
        local firstIndex = data[1]

        if (type(firstIndex) == "string") then
            SetTagsData(data)
        elseif (type(firstIndex) == "table") then
            SetComponentListData(data)
        elseif (TableContainsAnyIndex(data, ENTITY_DATA_INDEXES) == true) then
            if (typeof(data.Instance) == "Instance") then
                SetInstanceData(data.Instance)
            end
    
            if (type(data.Components) == "table") then
                SetComponentListData(data.Components)
            end
    
            if (type(data.UpdateEntity) == "boolean") then
                updateEntity = data.UpdateEntity
            end

            if (type(data.InitializeComponents) == "boolean") then
                initializeComponents = data.InitializeComponents
            end
    
            if (type(data.Tags) == "table") then
                SetTagsData(data.Tags)
            end

            if (type(data.CFrame) == "CFrame") then
                cframe = data.CFrame
            elseif (type(data.CFrame) == "Vector3") then
                cframe = CFrame.new(data.CFrame)
            end
        else
            SetComponentListData(data)
        end
    end

    for _, eData in pairs(entityData) do
        local eDType = type(eData)
        local eDTypeOf = typeof(eData)

        if (eDTypeOf == "Instance") then
            SetInstanceData(eData)
        elseif (eDType == "boolean") then
            updateEntity = eData
        elseif (eDType == "string") then
            AddTag(eData)
        elseif (eDType == "table") then
            SetData(eData)
        elseif (eDType == "number") then
            SetBoolData(eData)
        elseif (eDTypeOf == "CFrame") then
            cframe = eData
        elseif (eDTypeOf == "Vector3") then
            cframe = CFrame.new(eData)
        end
    end

    assert(not (updateEntity == true and initializeComponents == false), "You must Initialize components if you are going to update the entity with systems!")

    return instance, componentList, tags, cframe, updateEntity, initializeComponents
end


function ECSWorld:CreateEntity(...)
    local instance, componentList, tags, cframe, updateEntity, initializeComponents = GetEntityData({...})

    local entity = ECSEntity.new(instance, tags)

    if (cframe ~= nil and entity.Instance:IsA("Model") == true and entity.Instance.PrimaryPart ~= nil) then
        entity.Instance:SetPrimaryPartCFrame(cframe)
    end

    local function AddComponentToEntity(entity, componentName, componentData)
        local newComponent = self:_CreateComponent(componentName, componentData)
    
        if (newComponent ~= nil) then
            entity:AddComponent(componentName, newComponent, initializeComponents)
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


local function GetResourceEntitiesData(resourceEntitiesData)
    local parent = nil
    local entitiesData = {}
    local tags = {}

    local function AddTag(tagName)
        if (TableContains(tags, tagName) == false) then
            table.insert(tags, tagName)
        end
    end

    local function SetTagsData(newTags)
        for _, tagName in pairs(newTags) do
            AddTag(tagName)
        end
    end

    local function SetData(data)
        local firstIndex = data[1]

        if (type(firstIndex) == "string") then
            SetTagsData(data)
        else
            entitiesData = data
        end
    end

    for _, data in pairs(resourceEntitiesData) do
        local dTypeOf = typeof(data)
        local dType = type(data)

        if (dTypeOf == "Instance") then
            parent = data
        elseif (dType == "string") then
            AddTag(eData)
        elseif (dType == "table") then
            SetData(data)
        end
    end

    return parent, entitiesData, tags
end


function ECSWorld:CreateEntitiesFromResource(resource, ...)
    assert(type(resource) == "table")
    assert(resource._IsResource == true)

    local parent, entitiesData, tags = GetResourceEntitiesData({...})

    local rootInstance, entityInstances = resource:Create()

    local entities = {}

    for _, instance in pairs(entityInstances) do
        local entityData = entitiesData[instance.Name] or {}

        if (instance == rootInstance and type(entitiesData.RootInstance) == "table") then
            entityData = entitiesData.RootInstance
        end

        local entity = self:CreateEntity(instance, entityData, tags, 2)

        table.insert(entities, entity)
    end

    for _, entity in pairs(entities) do
        entity:InitializeComponents()
    end

    for _, entity in pairs(entities) do
        self:_UpdateEntity(entity)
    end

    if (typeof(parent) == "Instance" or parent == nil) then
        rootInstance.Parent = parent
    end

    return rootInstance
end


function ECSWorld:_RemoveEntity(entity)
    if (entity._IsBeingRemoved ~= true) then
        entity._IsBeingRemoved = true   --set flag to true

        local registeredSystems = TableCopy(entity:GetRegisteredSystems())

        if (#registeredSystems > 0) then
            for _, systemName in pairs(registeredSystems) do
                local system = self:GetSystem(systemName)
                if (system ~= nil) then
                    system:RemoveEntity(entity)
                end
            end
        else
            self:ForceRemoveEntity(entity)
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
    assert(type(tag) == "string")
    
    local currentEntities = TableCopy(self._Entities)

    for _, entity in pairs(currentEntities) do
        if (entity:HasTag(tag) == true) then
            self:_RemoveEntity(entity)
        end
    end
end


function ECSWorld:RemoveEntitiesWithTags(...)
    local tags = {...}

    if (type(tags[1]) == "table") then
        tags = tags[1]
    end

    local currentEntities = TableCopy(self._Entities)

    for _, entity in pairs(currentEntities) do
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


function ECSWorld:_AddComponentToEntity(entity, componentName, componentData, initializeComponents)
    assert(type(componentName) == "string" and type(componentData) == "table")

    local newComponent = self:_CreateComponent(componentName, componentData)

    if (newComponent ~= nil) then
        entity:AddComponent(componentName, newComponent, initializeComponents)
    end
end


function ECSWorld:_RemoveComponentFromEntity(entity, componentName)
    assert(type(componentName) == "string")

    entity:RemoveComponent(componentName)
end


function ECSWorld:AddComponentsToEntity(entity, componentList, initializeComponents)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")

    for componentName, componentData in pairs(componentList) do
        self:_AddComponentToEntity(entity, componentName, componentData, initializeComponents)
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

    for _, system in pairs(self._EntitySystems) do
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
    self._EntitySystems = {}


    return self
end


return ECSWorld