
local ENTITY_INSTANCE_COMPONENT_DATA_NAME = "COMPONENTS"
local ENTITY_INSTANCE_IS_PREFAB_FLAG_NAME = "IS_PREFAB"
local PATH_SEPARATOR = "/"

local INVALID_NAMES = {
    [ENTITY_INSTANCE_COMPONENT_DATA_NAME] = true;
    [ENTITY_INSTANCE_IS_PREFAB_FLAG_NAME] = true;
}


local function CompilePath(instance, rootInstance, path)
    path = path or ""

    if (rootInstance:IsAncestorOf(instance) == true) then
        path = CompilePath(instance.Parent, rootInstance) .. instance.Name .. PATH_SEPARATOR .. path
    elseif (instance ~= rootInstance) then
        error("Somehow, instance is a parent of RootInstance")
    end

    return path
end


local function ParsePath(rootInstance, path)
    local instance = rootInstance

    for str, _ in string.gmatch(path, "[^" .. PATH_SEPARATOR .. "]+") do
        instance = instance:FindFirstChild(str)
        
        if (instance == nil) then
            warn("Unable to find instance in " .. rootInstance.Name .. " with path " .. path)
            return nil
        end
    end

    return instance
end


local function CanInstanceBeAnEntity(instance)
    return instance:FindFirstChild(ENTITY_INSTANCE_IS_PREFAB_FLAG_NAME) == nil and instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME) ~= nil
end


local function CanInstanceBeAPrefab(instance)    --for prefabs
    local isResource = false

    local flag = instance:FindFirstChild(ENTITY_INSTANCE_IS_PREFAB_FLAG_NAME)
    local resourceName = nil

    if (flag ~= nil and flag:IsA("StringValue") == true) then
        isResource = true
        resourceName = flag.Value
    end

    return isResource, resourceName
end


local function GetEntityPathsFromInstance(instance, rootInstance, paths)
    paths = paths or {}
    rootInstance = rootInstance or instance

    if (INVALID_NAMES[instance.Name] ~= true and CanInstanceBeAnEntity(instance) == true) then
        local path = CompilePath(instance, rootInstance)

        table.insert(paths, path)
    end

    if (CanInstanceBeAPrefab(instance) == false) then
        for _, child in pairs(instance:GetChildren()) do
            GetEntityPathsFromInstance(child, rootInstance, paths)
        end
    end

    return paths
end


local function GetPrefabPathsFromInstance(instance, rootInstance, paths)
    paths = paths or {}
    rootInstance = rootInstance or instance

    if (INVALID_NAMES[instance.Name] ~= true) then
        local canBePrefab, resourceName = CanInstanceBeAPrefab(instance)

        if (canBePrefab == true) then
            local pathData = {
                ResourceName = resourceName;
                Path = CompilePath(instance, rootInstance);
            }

            table.insert(paths, pathData)
        end
    end

    for _, child in pairs(instance:GetChildren()) do
        GetPrefabPathsFromInstance(child, rootInstance, paths)
    end

    return paths
end


local ECSRobloxResource = {
    ClassName = "ECSRobloxResource";
}

ECSRobloxResource.__index = ECSRobloxResource


ECSRobloxResource.GetEntityPathsFromInstance = GetEntityPathsFromInstance


function ECSRobloxResource:Create()
    local newInstance = self.Resource:Clone()

    local entityInstances = {}
    local prefabData = {}

    for _, path in pairs(self.EntityPaths) do
        local entityInstance = ParsePath(newInstance, path)

        table.insert(entityInstances, entityInstance)
    end

    for _, pathData in pairs(self.PrefabPaths) do
        local resourceName = pathData.ResourceName
        local path = pathData.Path
        local prefabInstance = ParsePath(newInstance, path)

        local data = {
            Instance = prefabInstance;
            ResourceName = resourceName;
        }

        table.insert(prefabData, data)
    end

    return newInstance, entityInstances, prefabData
end


function ECSRobloxResource.new(instance, name)
    assert(typeof(instance) == "Instance")

    local self = setmetatable({}, ECSRobloxResource)

    self.Resource = instance
    self.ResourceName = name or "DEFAULT_RESOURCE_NAME"

    self.EntityPaths = GetEntityPathsFromInstance(instance)
    self.PrefabPaths = GetPrefabPathsFromInstance(instance)   --for better prefabs

    self.IsRootInstanceAnEntity = CanInstanceBeAnEntity(instance)

    self._IsResource = true


    return self
end


return ECSRobloxResource