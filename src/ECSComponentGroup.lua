
local ECSComponentGroup = {
    ClassName = "ECSComponentGroup";
}

ECSComponentGroup.__index = ECSComponentGroup


function ECSComponentGroup:GetComponentList()
    return self.Components  --should this be copied?
end


function ECSComponentGroup:EntityBelongs(entity)
    return #self.Components > 0 and entity:HasComponents(self.Components)
end


function ECSComponentGroup.new(name, components)
    assert(type(name) == "string")
    assert(components == nil or type(components) == "table")

    local self = setmetatable({}, ECSComponentGroup)

    self.Name = name
    self.Components = components or {}

    self._IsComponentGroup = true


    return self
end


return ECSComponentGroup