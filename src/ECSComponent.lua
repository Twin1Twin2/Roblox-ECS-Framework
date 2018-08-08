
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


function ECSComponent:Initialize(entity)
    if (self._IsInitialized == false) then
        self._IsInitialized = true
        self._ComponentDescription:Initialize(self, entity)
    end
end


function ECSComponent:Destroy()
    self._ComponentDescription:Destroy(self)

    setmetatable(self, nil)
end


function ECSComponent.new(componentDesc, data)
    assert(type(componentDesc) == "table" and componentDesc._IsComponentDescription == true)

    data = data or {}
    assert(type(data) == "table")

    local self = setmetatable({}, ECSComponent)
    
    AltMerge(self, componentDesc.Data)

    local newSelf = componentDesc:Create(self, data)
    self = newSelf or self

    self._IsComponent = true
    self._IsInitialized = false

    self._ComponentDescription = componentDesc  --reference here yea b/c you can already get it from ecsworld
    self._ComponentName = componentDesc.ComponentName


    return self
end


return ECSComponent