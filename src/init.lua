
local ECSComponent = require(script.ECSComponent)
local ECSComponentDescription = require(script.ECSComponentDescription)
local ECSEngine = require(script.ECSEngine)
local ECSEngineConfiguration = require(script.ECSEngineConfiguration)
local ECSEntity = require(script.ECSEntity)
local ECSRobloxResource = require(script.ECSRobloxResource)
local ECSSystem = require(script.ECSSystem)
local ECSWorld = require(script.ECSWorld)


local ECSFramework = {}

ECSFramework.Component = ECSComponentDescription
ECSFramework.Engine = ECSEngine
ECSFramework.EngineConfiguration = ECSEngineConfiguration
ECSFramework.Resource = ECSRobloxResource
ECSFramework.System = ECSSystem
ECSFramework.World = ECSWorld


return ECSFramework