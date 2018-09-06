--- Resource
--

local Utilities = require(script.Parent.Utilities)

local CanInstanceBeAnEntity = Utilities.CanInstanceBeAnEntity


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


local function GetEntityPathsFromInstance(instance)
    local paths = {}
    local entityInstances = GetEntityInstancesFromInstance(instance)

    for _, entityInstance in pairs(entityInstances) do
        local path = CompilePath(entityInstance, instance)

        table.insert(paths, path)
    end

    return paths
end


local ECSRobloxResource = {
    ClassName = "ECSRobloxResource";
}

ECSRobloxResource.__index = ECSRobloxResource


function ECSRobloxResource:Create()
    assert(typeof(self._Resource) == "Instance")

    local newInstance = self._Resource:Clone()

    local entityInstances = {}

    for _, path in pairs(self._EntityPaths) do
        local entityInstance = ParsePath(newInstance, path)

        table.insert(entityInstances, entityInstance)
    end


    return newInstance, entityInstances
end


function ECSRobloxResource:Destroy()
    self._Resource = nil
    self._EntityPaths = nil
    
    setmetatable(self, nil)
end


function ECSRobloxResource.new(instance, name)
    assert(typeof(instance) == "Instance")

    local self = setmetatable({}, ECSRobloxResource)

    self._Resource = instance

    self.ResourceName = name or "INSTANCE_RESOURCE"

    self._EntityPaths = GetEntityPathsFromInstance(instance)

    self._IsRootInstanceAnEntity = CanInstanceBeAnEntity(instance)

    self._IsResource = true


    return self
end


return ECSRobloxResource