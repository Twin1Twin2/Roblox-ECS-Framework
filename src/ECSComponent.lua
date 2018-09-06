
local Table = require(script.Parent.Table)

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local AltMerge = Table.AltMerge
local DeepCopy = Table.DeepCopy


local ECSComponent = {
    ClassName = "ECSComponent";
}

ECSComponent.__index = ECSComponent


function ECSComponent:CopyData()
    local componentDesc = self._ComponentDescription
    assert(componentDesc ~= nil)

    local data = {}

    for i, _ in pairs(componentDesc.Data) do
        data[i] = DeepCopy(self[i])
    end

    return data
end


function ECSComponent:Initialize(entity)
    if (self._IsInitialized == false) then
        self._IsInitialized = true
        self._ComponentDescription:Initialize(self, entity)
    end
end


function ECSComponent:Destroy()
    self._ComponentDescription:DestroyComponent(self)

    setmetatable(self, nil)
end


function ECSComponent.new(componentDesc, data)
    assert(type(componentDesc) == "table" and componentDesc._IsComponentDescription == true)

    data = data or {}
    assert(type(data) == "table")

    local self = setmetatable({}, ECSComponent)

    self._IsComponent = true
    
    AltMerge(self, componentDesc.Data)

    local newSelf = componentDesc:Create(self, data)
    self = newSelf or self

    self._IsInitialized = false

    self._ComponentDescription = componentDesc  --reference here yea b/c you can already get it from ecsworld
    self._ComponentName = componentDesc.ComponentName


    return self
end


return ECSComponent