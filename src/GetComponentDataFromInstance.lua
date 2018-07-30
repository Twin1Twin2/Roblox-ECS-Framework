
local function GetDataFromInstance(instance)
    local data = instance

    if (data:IsA("ValueBase") == true) then
        data = instance.Value
    end

    return data
end


local function GetComponentDataFromInstance(instance)
    local data = {}

    for _, valueInstance in pairs(instance:GetChildren()) do
        local valueName = valueInstance.Name
        data[valueName] = GetDataFromInstance(valueInstance)
    end

    return data
end


return GetComponentDataFromInstance