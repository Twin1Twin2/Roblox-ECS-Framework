--- Utilities
--

local Table = require(script.Parent.Table)

local TableMerge = Table.Merge


local Utilities = {}


--Constants

local REMOTE_EVENT_ENUM = {
    PLAYER_READY = 0;
    ENTITY_CREATE = 1;
    ENTITY_ADD_COMPONENTS = 2;
    ENTITY_REMOVE_COMPONENTS = 3;
    ENTITY_ADD_REMOVE_COMPONENTS = 4;
    ENTITY_REMOVE = 5;
    ENTITY_CREATE_FROM_INSTANCE = 6;
}

Utilities.REMOTE_EVENT_ENUM = REMOTE_EVENT_ENUM


local ENTITY_INSTANCE_COMPONENT_DATA_NAME = "COMPONENTS"
local ENTITY_INSTANCE_PREFAB_DATA_NAME = "PREFABS"
local COMPONENT_DESC_CLASSNAME = "ECSComponentDescription"
local SYSTEM_CLASSNAME = "ECSSystem"

local INVALID_ENTITY_INSTANCE_NAMES = {
    [ENTITY_INSTANCE_COMPONENT_DATA_NAME] = true;
    [ENTITY_INSTANCE_PREFAB_DATA_NAME] = true;
}

Utilities.ENTITY_INSTANCE_COMPONENT_DATA_NAME = ENTITY_INSTANCE_COMPONENT_DATA_NAME
Utilities.ENTITY_INSTANCE_PREFAB_DATA_NAME = ENTITY_INSTANCE_PREFAB_DATA_NAME
Utilities.COMPONENT_DESC_CLASSNAME = COMPONENT_DESC_CLASSNAME
Utilities.SYSTEM_CLASSNAME = SYSTEM_CLASSNAME

Utilities.INVALID_ENTITY_INSTANCE_NAMES = INVALID_ENTITY_INSTANCE_NAMES


local SYSTEM_UPDATE_TYPE = {
    NO_UPDATE = 0;
    RENDER_STEPPED = 1;
    STEPPED = 2;
    HEARTBEAT = 3;
    UI = 4;
}

Utilities.SYSTEM_UPDATE_TYPE = SYSTEM_UPDATE_TYPE


--Functions

function Utilities.IsEntity(object)
    return type(object) == "table" and object._IsEntity == true
end


function Utilities.IsComponent(object)
    return type(object) == "table" and object._IsComponent == true
end


function Utilities.IsComponentDescription(object)
    return type(object) == "table" and object._IsComponentDescription == true
end


function Utilities.IsComponentGroup(object)
    return type(object) == "table" and object._IsComponentGroup == true
end


function Utilities.IsSystem(object)
    return type(object) == "table" and object._IsSystem == true
end


function Utilities.IsEngineConfiguration(object)
    return type(object) == "table" and object._IsEngineConfiguration == true
end


function Utilities.IsResource(object)
    return type(object) == "table" and object._IsResource == true
end


local function CanInstanceBeAnEntity(instance)
    return instance:FindFirstChild(ENTITY_INSTANCE_PREFAB_DATA_NAME) == nil and instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME) ~= nil
end

Utilities.CanInstanceBeAnEntity = CanInstanceBeAnEntity


local function GetDataFromInstance(instance)
    local data = instance

    if (data:IsA("ValueBase") == true) then
        data = instance.Value
    end

    return data
end


local function GetComponentDataFromDataContainer(instance)
    local data = {}

    for _, valueInstance in pairs(instance:GetChildren()) do
        local valueName = valueInstance.Name
        data[valueName] = GetDataFromInstance(valueInstance)
    end

    return data
end


local function GetComponentsDataFromEntityInstance(instance, deleteData)
    local componentList = {}

    if (typeof(instance) ~= "Instance") then
        return componentList
    end

    local entityInstanceComponentData = instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME)

    if (entityInstanceComponentData ~= nil) then
        for _, componentInstanceData in pairs(entityInstanceComponentData:GetChildren()) do
            local componentName = componentInstanceData.Name
            componentList[componentName] = GetComponentDataFromDataContainer(componentInstanceData)
        end

        if (deleteData == true) then
            entityInstanceComponentData:Destroy()
        end
    end


    return componentList
end

Utilities.GetComponentsDataFromEntityInstance = GetComponentsDataFromEntityInstance


function Utilities.MergeComponentData(mainComponentData, otherComponentData)
    for componentName, componentData in pairs(otherComponentData) do
        local currentComponentData = mainComponentData[componentName]
        if (currentComponentData == nil) then
            mainComponentData[componentName] = componentData
        else
            mainComponentData[componentName] = TableMerge(currentComponentData, componentData)
        end
    end

    return mainComponentData
end


local function GetEntityInstancesFromInstance(instance, entityInstances)
    entityInstances = entityInstances or {}

    if (INVALID_ENTITY_INSTANCE_NAMES[instance.Name] ~= true and CanInstanceBeAnEntity(instance) == true) then
        table.insert(entityInstances, instance)
    end

    for _, child in pairs(instance:GetChildren()) do
        GetEntityInstancesFromInstance(child, entityInstances)
    end

    return entityInstances
end

Utilities.GetEntityInstancesFromInstance = GetEntityInstancesFromInstance


local function PrintComponentList(componentList)
    assert(type(componentList) == "table")

    for componentName, componentData in pairs(componentList) do
        if (type(componentData) == "table") then
            print("[\"" ..componentName .. "\"]")
            for index, value in pairs(componentData) do
                print("    -", index, "=", value)
            end
            print()
        end
    end
end

Utilities.PrintComponentList = PrintComponentList


local function AddSystemToListByPriority(system, list)
    local priority = system.UpdatePriority

    --find a place to put it
    local wasInserted = false

    if (priority >= 0) then
        for index, system in pairs(list) do
            local otherPriority = system.UpdatePriority

            if (otherPriority < 0) then
                break
            elseif (otherPriority < priority) then
                table.insert(list, index, system)
                wasInserted = true
                break
            end
        end
    end

    if (wasInserted == false) then
        table.insert(list, system)
    end
end

Utilities.AddSystemToListByPriority = AddSystemToListByPriority


function Utilities.GetEntityInListFromInstance(entityList, instance)
    assert(typeof(instance) == "Instance")

    for _, entity in pairs(entityList) do
        if (entity.Instance == instance) then
            return entity
        end
    end

    return nil
end


function Utilities.GetEntityInListContainingInstance(entityList, instance)
    assert(typeof(instance) == "Instance")

    local currentEntity = nil

    for _, entity in pairs(entityList) do
        if (entity:ContainsInstance(instance) == true) then
            if (currentEntity == nil or currentEntity.Instance:IsAncestorOf(entity.Instance) == true) then
                currentEntity = entity
            end
        end
    end

    return currentEntity
end


return Utilities