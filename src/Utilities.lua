
local Table = require(script.Parent.Table)

local TableMerge = Table.Merge

local Utilities = {}

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


local function GetComponentsDataFromEntityInstance(instance)
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
    end

    return componentList
end

Utilities.GetComponentsDataFromEntityInstance = GetComponentsDataFromEntityInstance


local function MergeComponentData(mainComponentData, otherComponentData)
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

Utilities.MergeComponentData = MergeComponentData


local function MergeEntityInstanceData(mainEntityInstance, otherEntityInstance)
    local mainComponentData = GetComponentsDataFromEntityInstance(mainEntityInstance)
    local otherComponentData = GetComponentsDataFromEntityInstance(otherEntityInstance)

    mainComponentData = MergeComponentData(mainComponentData, otherComponentData)




    return mainComponentData
end

Utilities.MergeEntityInstanceData = MergeEntityInstanceData


local function CanInstanceBeAnEntity(instance)
    return instance:FindFirstChild(ENTITY_INSTANCE_PREFAB_DATA_NAME) == nil and instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME) ~= nil
end


local function CanInstanceBeAPrefab(instance)    --for prefabs
    local isResource = false

    local flag = instance:FindFirstChild(ENTITY_INSTANCE_PREFAB_DATA_NAME)
    local resourceName = nil

    if (flag ~= nil and flag:IsA("StringValue") == true) then
        isResource = true
        resourceName = flag.Value
    end

    return isResource, resourceName
end

Utilities.CanInstanceBeAnEntity = CanInstanceBeAnEntity
Utilities.CanInstanceBeAPrefab = CanInstanceBeAPrefab


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


return Utilities