
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ECSEntity = require(script.Parent.ECSEntity)
local ECSComponent = require(script.Parent.ECSComponent)
local ECSSystem = require(script.Parent.ECSSystem)

local Table = require(script.Parent.Table)
local Signal = require(script.Parent.Signal)
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

local REMOTE_EVENT_PLAYER_READY = 0
local REMOTE_EVENT_ENTITY_CREATE = 1
local REMOTE_EVENT_ENTITY_REMOVE = 2
local REMOTE_EVENT_ENTITY_ADD_COMPONENTS = 3
local REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS = 4
local REMOTE_EVENT_RESOURCE_CREATE = 5


local function GetCFrameFromInstance(instance)
    if (instance:IsA("Model") == true) then
        if (instance.PrimaryPart ~= nil) then
            return instance:GetPrimaryPartCFrame()
        end
    elseif (instance:IsA("BasePart") == true) then
        return instance.CFrame
    end
end


local function IsValidParentForServerClientEntity(instance)
    return instance ~= ServerStorage and instance ~= ServerScriptStorage
end


local function IsInstanceVisibleByClient(instance)
    local instanceParent = instance.Parent

    return instanceParent ~= nil and IsValidParentForServerClientEntity(instanceParent)
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
    for _, entity in pairs(self._Entities) do
        if (entity.Instance == instance) then
            return entity
        end
    end

    return nil
end


function ECSWorld:GetEntityContainingInstance(instance) --need to redo
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


function ECSWorld:WaitForEntityWithInstance(instance, maxWaitTime)   --idk how to do this, but this will do
    assert(maxWaitTime == nil or (type(maxWaitTime) == "number" and maxWaitTime >= 0), "Invalid Arg [2]")

    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        return entity
    end

    --big old wait
    local startTime = tick()

    while (entity == nil and (maxWaitTime == nil or tick() - startTime < maxWaitTime)) do
        RunService.Heartbeat:Wait()
        entity = self:GetEntityFromInstance(instance) 
    end

    return entity
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

    if (componentDesc == nil) then
        --warn("ECS World :: _CreateComponent() " .. self.Name .. " - Unable to find component with the name \"" .. componentName .. "\"")
        --removed until i can make either an ignorelist or whatever
        return nil
    end

    local newComponent = ECSComponent.new(componentDesc, data, instance)

    return newComponent
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


function ECSWorld:_InitializeSystem(system)
    for _, componentName in pairs(system.Components) do
        if (self:_GetComponentDescription(componentName) == nil) then
            warn("ECS World \"" .. self.Name .. "\" :: InitializeSystem() - [" .. system.SystemName .. "] Component \"" .. componentName .. "\" is not registered!")
        end
    end

    system:Initialize()
    system._IsInitialized = true

    if (#system.Components > 0) then
        table.insert(self._EntitySystems, system)
    end
end


function ECSWorld:InitializeSystems()
    for _, system in pairs(self._Systems) do
        if (system._IsInitialized == false) then
            self:_InitializeSystem(system)
        end
    end
end


function ECSWorld:RegisterSystem(system, initializeSystem)
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

    system.World = self
    table.insert(self._Systems, system)

    if (initializeSystem ~= false) then
        self:_InitializeSystem(system)
    end
end


function ECSWorld:RegisterSystems(...)
    local systemDescs = {...}

    self:RegisterSystemsFromList(systemDescs)
end


function ECSWorld:RegisterSystemsFromList(systemDescs, initializeSystems)
    assert(type(systemDescs) == "table", "")

    for _, systemDesc in pairs(systemDescs) do
        self:RegisterSystem(systemDesc, initializeSystems)
    end
end


function ECSWorld:EntityBelongsInSystem(system, entity)
    local systemComponents = system.Components

    return (#systemComponents > 0 and entity:HasComponents(systemComponents))
end


local function GetEntityDataFromInstance(instance)
    local entityInstanceComponentData = instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME)
    local entityInstanceTagData = instance:FindFirstChild(ENTITY_INSTANCE_TAG_DATA_NAME)

    local componentList = {}
    local tags = {}

    if (entityInstanceComponentData ~= nil) then
        for _, componentInstanceData in pairs(entityInstanceComponentData:GetChildren()) do
            local componentName = componentInstanceData.Name
            componentList[componentName] = GetComponentDataFromInstance(componentInstanceData)
        end
    end

    if (entityInstanceTagData ~= nil) then
        for _, tagInstanceData in pairs(entityInstanceTagData:GetChildren()) do
            local tagName = tagInstanceData.Name
            table.insert(tags, tagName)
        end
    end

    return componentList, tags
end


function ECSWorld:IsResource(resource)
    return (type(resource) == "table" and resource._IsResource == true)
end


function ECSWorld:GetResource(resourceName)
    return self._RegisteredResources[resourceName]
end


function ECSWorld:RegisterResource(resource, resourceName)    --register for prefabs resources
    assert(self:IsResource(resource) == true)
    
    if (TableContains(self._RegisteredResources, resource) == true) then
        return
    end

    resourceName = resourceName or resource.ResourceName

    local otherResource = self:GetResource(resourceName)

    if (otherResource ~= nil) then
        error("Resource already registered with the name " .. resourceName)
    end

    self._RegisteredResources[resourceName] = resource
end


function ECSWorld:_CreateEntityFromResource(resource, data, isServerSideEntity, updateAndInitializeResource, parentPrefabNames)
    if (type(resource) == "string") then
        local resourceName = resource
        resource = self:GetResource(resourceName)
        assert(resource ~= nil, "Resource with the name " .. resourceName .. " not found!")
    else
        assert(self:IsResource(resource) == true)
    end

    local rootInstance, entityInstances, resourcePrefabData = resource:Create()

    if (resource.IsRootInstanceAnEntity == false) then
        rootInstance.ChildRemoved:Connect(function(child)   --remove automatically if it has no children
            if (#rootInstance:GetChildren() == 0) then
                rootInstance:Destroy()
            end
        end)
    end

    local entities = {}

    for _, instance in pairs(entityInstances) do
        local entity = self:_CreateAndAddEntity(instance, {}, {}, isServerSideEntity, false, false)

        table.insert(entities, entity)
    end

    --[[
    for _, prefabData in pairs(resourcePrefabData) do
        local instance = data.Instance
        local resourceName = data.ResourceName
        local resourceData

        local prefabRootInstance, prefabEntities = self:_CreateEntityFromResource(resourceName, resourceData, false)

        for _, prefabEntity in pairs(prefabEntities) do
            table.insert(entities, prefabEntity)
        end
    end
    --]]

    if (updateAndInitializeResource == true) then
        for _, entity in pairs(entities) do
            entity:InitializeComponents()
        end

        for _, entity in pairs(entities) do
            self:_UpdateEntity(entity)
        end
    end

    return rootInstance, entities, entityInstances
end


local function CreateEntityFromResource_Server(resource, parent, isServerSideEntity)
    if (isServerSideEntity ~= true) then
        if (parent ~= nil) then
            assert(IsValidParentForServerClientEntity(parent) == true)
        else
            parent = ReplicatedStorage
        end
    end

    local rootInstance, entities = self:_CreateEntityFromResource(resource, nil, isServerSideEntity, true)

    rootInstance.Parent = parent

    if (isServerSideEntity ~= true and self._RemoteEvent ~= nil) then
        for _, entity in pairs(entities) do
            self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_CREATE, entity.Instance, nil, nil)
        end
    end

    return rootInstance, entities
end


local function CreateEntityFromResource_Client(resource, parent)
    local rootInstance, entities = self:_CreateEntityFromResource(resource, nil, false, true)

    if (parent ~= nil) then
        rootInstance.Parent = parent
    end

    return rootInstance, entities
end

--[[
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

    local entity = ECSEntity.new(self, instance, tags)

    if (cframe ~= nil and entity.Instance:IsA("Model") == true and entity.Instance.PrimaryPart ~= nil) then
        entity.Instance:SetPrimaryPartCFrame(cframe)
    end

    table.insert(self._Entities, entity)

    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)

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
            AddTag(data)
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

    if (resource.RootInstanceIsAnEntity == false) then
        rootInstance.ChildRemoved:Connect(function(child)   --remove automatically if it has no children
            if (#rootInstance:GetChildren() == 0) then
                rootInstance:Destroy()
            end
        end)
    end

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

    return rootInstance, entities
end
--]]

function ECSWorld:_CanUpdateEntityForClients(entity)
    return entity._IsServerSide ~= true and self._RemoteEvent ~= nil
end


function ECSWorld:_CreateAndAddEntity(instance, componentList, tags, isServerSide, updateEntity, initializeComponents)
    componentList = componentList or {}
    tags = tags or {}

    if (isServerSide == nil) then
        isServerSide = false
    end

    if (instance ~= nil) then
        assert(typeof(instance) == "Instance")

        local instanceComponentList, instanceTags = GetEntityDataFromInstance(instance)

        for componentName, componentData in pairs(instanceComponentList) do
            local currentComponentData = componentList[componentName]
            if (currentComponentData == nil) then
                componentList[componentName] = componentData
            else
                componentList[componentName] = TableMerge(currentComponentData, componentData)
            end
        end

        for _, tagName in pairs(instanceTags) do
            if (TableContains(tags, tagName) == false) then
                table.insert(tags, tagName)
            end
        end
    end

    local entity = ECSEntity.new(self, instance, tags)
    entity._IsServerSide = isServerSide

    table.insert(self._Entities, entity)
    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)

    self.OnEntityAdded:Fire(entity)

    return entity
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


local function CreateEntity_Server(self, instance, componentList, tags, isServerSideEntity)
    assert(instance == nil or typeof(instance) == "Instance")
    componentList = componentList or {}

    if (isServerSideEntity == nil) then
        isServerSideEntity = false
    end

    if (isServerSideEntity == false and instance ~= nil) then
        assert(IsInstanceVisibleByClient(instance) == true, "Instance is not visible by the client. Consider parenting it in ReplicatedStorage")
    end

    local entity = self:_CreateAndAddEntity(instance, componentList, tags, isServerSideEntity)

    --add entity to clients    
    if (self:_CanUpdateEntityForClients(entity) == true) then
        if (instance == nil) then
            entity.Instance.Parent = ReplicatedStorage
        end

        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_CREATE, entity.Instance, componentList, tags)
    else
        entity._IsServerSide = true
    end

    return entity
end


local function RemoveEntity_Server(self, entity)
    if (TableContains(self._Entities, entity) == false) then
        return
    end

    if (self:_CanUpdateEntityForClients(entity) == true) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_REMOVE, entity.Instance)
    end

    self:_RemoveEntity(entity)
end


function ECSWorld:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")
end


local function AddComponentsToEntity_Server(self, entity, componentList, updateEntity, initializeComponents)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)

    if (self:_CanUpdateEntityForClients(entity) == true) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_ADD_COMPONENTS, entity.Instance, componentList)
    end
end


local function RemoveComponentsFromEntity_Server(self, entity, componentList, updateEntity)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_RemoveComponentsFromEntity(REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS, componentList, updateEntity)

    if (self:_CanUpdateEntityForClients(entity) == true) then
        self._RemoteEvent:FireAllClients(REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS, entity.Instance, componentList)
    end
end


local function CreateEntity_Client(self, instance, componentList, tags)
    componentList = componentList or {}

    local entity = self:_CreateAndAddEntity(instance, componentList, tags)

    return entity
end


local function RemoveEntity_Client(self, entity)
    if (TableContains(self._Entities, entity) == false) then
        return
    end

    self:_RemoveEntity(entity)
end


local function AddComponentsToEntity_Client(self, entity, componentList, updateEntity, initializeComponents)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)
end


local function RemoveComponentsFromEntity_Client(self, entity, componentList, updateEntity)
    self:_CheckValidArgumentsForUpdateComponentsFunction(entity, componentList)

    self:_RemoveComponentsFromEntity(entity, componentList, updateEntity)
end


local function EntityCreatedFromServer(self, instance, componentList, tags)
    print("Entity created from server! Instance =", instance)

    local entity = self:_CreateAndAddEntity(instance, componentList, tags)

    return entity
end


local function EntityRemovedFromServer(self, instance)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveEntity(entity)
    end
end


local function EntityAddedComponentsFromServer(self, instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_AddComponentsToEntity(entity, componentList)
    end
end


local function EntityRemovedComponentsFromServer(self, instance, componentList)
    local entity = self:GetEntityFromInstance(instance)

    if (entity ~= nil) then
        self:_RemoveComponentsFromEntity(entity, componentList)
    end
end


local function ResourceCreatedFromServer(self, instances, data)
    for _, instance in pairs(instances) do
        EntityCreatedFromServer(self, instance)
    end
end

--[[
function ECSWorld:RemoveEntity(entity)
    if (TableContains(self._Entities, entity) == false) then
        return
    end

    self:_RemoveEntity(entity)
end
--]]

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


function ECSWorld:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)
    for componentName, componentData in pairs(componentList) do
        if (type(componentData) == "string") then
            componentName = componentData
            componentData = {}
        end
        
        self:_AddComponentToEntity(entity, componentName, componentData, initializeComponents)
    end

    if (updateEntity ~= false) then
        self:_UpdateEntity(entity)
    end
end


function ECSWorld:_RemoveComponentFromEntity(entity, componentName)
    assert(type(componentName) == "string")

    entity:RemoveComponent(componentName)
end


function ECSWorld:_RemoveComponentsFromEntity(entity, componentList, updateEntity)
    for _, componentName in pairs(componentList) do
        self:_RemoveComponentFromEntity(entity, componentName)
    end

    if (updateEntity ~= false) then
        self:_UpdateEntity(entity)
    end
end

--[[
function ECSWorld:AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")

    self:_AddComponentsToEntity(entity, componentList, updateEntity, initializeComponents)
end


function ECSWorld:RemoveComponentsFromEntity(entity, componentList, updateEntity)
    assert(entity ~= nil and type(entity) == "table" and entity.ClassName == "ECSEntity")
    assert(TableContains(self._Entities, entity) == true)
    assert(componentList ~= nil and type(componentList) == "table")

    self:_RemoveComponentsFromEntity(entity, componentList, updateEntity)
end
--]]

function ECSWorld:_UpdateEntity(entity)  --update after it's components have changed or it was just added
    if (entity._IsBeingRemoved == true) then
        return
    end

    local registeredSystems = TableCopy(entity:GetRegisteredSystems())

    for _, systemName in pairs(registeredSystems) do
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

    entity:Update()
end


function ECSWorld:UpdateEntity(entity)
    assert(TableContains(self._Entities, entity) == true)

    self:_UpdateEntity(entity)
end


local function GetPlayerIdString(player)
    local playerId = player.UserId
    local idString = tostring(playerId)

    return idString
end


local function IsPlayerReady_Server(self, player)
    assert(typeof(player) == "Instance" and player:IsA("Player") == true)

    local idString = GetPlayerIdString(player)

    return self._PlayersReady[idString] == true
end


local function PlayerReady_Server(self, player)
    local idString = GetPlayerIdString(player)
    
    if (self._PlayersReady[idString] ~= true) then
        self._PlayersReady[idString] = true
        self.OnPlayerReady:Fire(player)
    end
end


local function PlayerLeft_Server(self, player)
    local idString = GetPlayerIdString(player)

    self._PlayersReady[idString] = false
end


function ECSWorld:Destroy()
    --to do, add
end


function ECSWorld.new(name, isServer, remoteEvent)
    if (isServer ~= nil) then
        assert(type(isServer) == "boolean")
    else
        isServer = false
    end

    if (remoteEvent ~= nil) then
        assert(typeof(remoteEvent) == "Instance" and remoteEvent:IsA("RemoteEvent") == true)
    end

    local self = setmetatable({}, ECSWorld)

    self.Name = name or "ECS_WORLD"

    self._Entities = {}

    self._EntitiesToAdd = {}
    self._EntitiesToRemove = {}

    self._RegisteredComponents = {}

    self._Systems = {}
    self._EntitySystems = {}

    self._RegisteredResources = {}

    self._RemoteEvent = nil
    self._RemoteEventConnection = nil

    self.OnEntityAdded = Signal.new()


    if (isServer == true) then
        self._IsServer = true

        self.CreateEntity = CreateEntity_Server
        self.RemoveEntity = RemoveEntity_Server

        self.AddComponentsToEntity = AddComponentsToEntity_Server
        self.RemoveComponentsFromEntity = RemoveComponentsFromEntity_Server

        self.CreateEntityFromResource = CreateEntityFromResource_Server

        self._PlayersReady = {}
        self.IsPlayerReady = IsPlayerReady_Server

        if (remoteEvent ~= nil) then
            self.OnPlayerReady = Signal.new()

            self._RemoteEvent = remoteEvent

            self._RemoteEventConnection = remoteEvent.OnServerEvent:Connect(function(player, eventType)
                if (eventType == REMOTE_EVENT_PLAYER_READY) then
                    PlayerReady_Server(self, player)
                end
            end)

            self._PlayerLeftConnection = Players.PlayerRemoving:Connect(function(player)
                PlayerLeft_Server(self, player)
            end)
        end
    else
        self._IsServer = false

        self.CreateEntity = CreateEntity_Client
        self.RemoveEntity = RemoveEntity_Client

        self.AddComponentsToEntity = AddComponentsToEntity_Client
        self.RemoveComponentsFromEntity = RemoveComponentsFromEntity_Client

        self.CreateEntityFromResource = CreateEntityFromResource_Client

        if (remoteEvent ~= nil) then
            self._RemoteEvent = remoteEvent

            function self:Ready()
                remoteEvent:FireServer(REMOTE_EVENT_PLAYER_READY)
            end

            self._RemoteEventConnection = remoteEvent.OnClientEvent:Connect(function(eventType, instance, componentList, tags)
                if (eventType == REMOTE_EVENT_ENTITY_CREATE) then
                    EntityCreatedFromServer(self, instance, componentList, tags)
                elseif (eventType == REMOTE_EVENT_ENTITY_REMOVE) then
                    EntityRemovedFromServer(self, instance)
                elseif (eventType == REMOTE_EVENT_ENTITY_ADD_COMPONENTS) then
                    EntityAddedComponentsFromServer(self, instance, componentList)
                elseif (eventType == REMOTE_EVENT_ENTITY_REMOVE_COMPONENTS) then
                    EntityRemovedComponentsFromServer(self, instance, componentList)
                elseif (eventType == REMOTE_EVENT_RESOURCE_CREATE) then
                    ResourceCreatedFromServer(self, instance, componentList)
                end
            end)
        end
    end


    return self
end


return ECSWorld