
local ENTITY_INSTANCE_COMPONENT_DATA_NAME = "COMPONENTS"
local PATH_SEPARATOR = "/"


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
    return instance:FindFirstChild(ENTITY_INSTANCE_COMPONENT_DATA_NAME) ~= nil
end


local function GetEntityPathsFromInstance(instance, rootInstance, paths)
    paths = paths or {}
    rootInstance = rootInstance or instance

    if (instance.Name ~= ENTITY_INSTANCE_COMPONENT_DATA_NAME and CanInstanceBeAnEntity(instance)) then
        local path = CompilePath(instance, rootInstance)

        table.insert(paths, path)
    end

    for _, child in pairs(instance:GetChildren()) do
        GetEntityPathsFromInstance(child, rootInstance, paths)
    end

    return paths
end


local ECSRobloxResource = {
    ClassName = "ECSRobloxResource";
}

ECSRobloxResource.__index = ECSRobloxResource


ECSRobloxResource.GetEntityPathsFromInstance = GetEntityPathsFromInstance


function ECSRobloxResource:Create()
    local entityInstances = {}

    local newInstance = self.Resource:Clone()

    for _, path in pairs(self.EntityPaths) do
        local entityInstance = ParsePath(newInstance, path)

        table.insert(entityInstances, entityInstance)
    end

    return newInstance, entityInstances
end


function ECSRobloxResource.new(instance)
    assert(typeof(instance) == "Instance")

    local self = setmetatable({}, ECSRobloxResource)

    self.Resource = instance
    self.EntityPaths = GetEntityPathsFromInstance(instance)

    self.RootInstanceIsAnEntity = CanInstanceBeAnEntity(instance)
    self._IsResource = true



    return self
end


return ECSRobloxResource