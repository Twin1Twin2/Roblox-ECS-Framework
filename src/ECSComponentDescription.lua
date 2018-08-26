
local Table = require(script.Parent.Table)

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local Merge = Table.Merge
local DeepCopy = Table.DeepCopy

local function AltDeepCopy(source)   --copied from RobloxComponentSystem by tiffany352
	if typeof(source) == 'table' then
		local new = {}
		for key, value in pairs(source) do
			new[AltDeepCopy(key)] = AltDeepCopy(value)
		end
		return new
	end
	return source
end

local function AltMerge(to, from)   --copied from RobloxComponentSystem by tiffany352
	for key, value in pairs(from or {}) do
		to[DeepCopy(key)] = DeepCopy(value)
	end
end


local ECSComponentDescription = {
    ClassName = "ECSComponentDescription";
}

ECSComponentDescription.__index = ECSComponentDescription


local INDEX_BLACKLIST = {
    ClassName = true;

    _IsComponentDescription = true;
}


function ECSComponentDescription:Create(component, data)
    AltMerge(component, data)

    return component
end


function ECSComponentDescription:Initialize(component, entity)
    
end


function ECSComponentDescription:Destroy(component)

end


function ECSComponentDescription:Extend(name)
    assert(type(name) == "string")

    local this = {}

    function this.new()
        local t = ECSComponentDescription.new(name)

        for index, value in pairs(this) do
            if (INDEX_BLACKLIST[index] == nil) then
                t[index] = DeepCopy(value)
            end
        end

        return t
    end

    return this
end


function ECSComponentDescription.new(name)
    assert(type(name) == "string")

    local self = setmetatable({}, ECSComponentDescription)

    self.ComponentName = name
    self.Data = {}

    self._IsComponentDescription = true

    self.IsServerSide = nil


    return self
end


return ECSComponentDescription