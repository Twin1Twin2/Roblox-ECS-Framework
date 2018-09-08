
local Utilities = require(script.Parent.Utilities)
local Table = require(script.Parent.Table)

local IsComponent = Utilities.IsComponent

local TableContains = Table.Contains
local AttemptRemovalFromTable = Table.AttemptRemovalFromTable
local Merge = Table.Merge
local DeepCopy = Table.DeepCopy
local AltMerge = Table.AltMerge


local ECSComponentDescription = {
    ClassName = "ECSComponentDescription";
}

ECSComponentDescription.__index = ECSComponentDescription


local INDEX_BLACKLIST = {
    ClassName = true;

    _IsComponentDescription = true;
}


local function MergeComponentWithData(component, data)
    AltMerge(component, data)

    return component
end


function ECSComponentDescription.MergeComponentWithData(component, data)
    assert(IsComponent(component))
    assert(type(data) == "table")

    return MergeComponentWithData(component, data)
end


function ECSComponentDescription:Create(component, data)
    return MergeComponentWithData(component, data)
end


function ECSComponentDescription:Initialize(component, entity)
    
end


function ECSComponentDescription:DestroyComponent(component)

end


function ECSComponentDescription:Destroy()
    setmetatable(self, nil)
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
    self.IsServerOnly = false


    return self
end


return ECSComponentDescription