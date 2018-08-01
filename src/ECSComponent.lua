
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


local ECSComponent = {
    ClassName = "ECSComponent";
}

ECSComponent.__index = ECSComponent


function ECSComponent:_Destroy()

end


function ECSComponent:Destroy()
    self:_Destroy()
    
    if (self.Instance ~= nil) then
        self.Instance:Destroy()
    end

    setmetatable(self, nil)
end


function ECSComponent.new(componentDesc, data)
    assert(type(componentDesc) == "table" and componentDesc._IsComponentDescription == true)

    data = data or {}
    assert(type(data) == "table")

    local self = setmetatable({}, ECSComponent)
    
    AltMerge(self, componentDesc.Data)

    local newSelf = componentDesc:Create(self, data)    --Create() might be easy to hack if someone modifies the module. Should a ComponentDesc be copied?
    self = newSelf or self

    self._IsComponent = true

    self._ComponentName = componentDesc.ComponentName
    self._Destroy = DeepCopy(componentDesc.Destroy)
    

    return self
end


return ECSComponent