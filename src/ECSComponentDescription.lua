
local ECSComponentDescription = {
    ClassName = "ECSComponentDescription";
}

ECSComponentDescription.__index = ECSComponentDescription


function ECSComponentDescription:Create(data)
    return data
end


function ECSComponentDescription:Destroy()

end


function ECSComponentDescription:Extend(name)
    return ECSComponentDescription.new(name)
end


function ECSComponentDescription.new(name)
    assert(type(name) == "string")

    local self = setmetatable({}, ECSComponentDescription)

    self.ComponentName = name
    self.Data = {}

    self._IsComponentDescription = true


    return self
end


return ECSComponentDescription