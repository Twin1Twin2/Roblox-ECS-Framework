
local ECSComponent = require(script.ECSComponent)
local ECSComponentDescription = require(script.ECSComponentDescription)
local ECSEngine = require(script.ECSEngine)
local ECSEngineConfiguration = require(script.ECSEngineConfiguration)
local ECSEntity = require(script.ECSEntity)
local ECSSystem = require(script.ECSSystem)
local ECSWorld = require(script.ECSWorld)


local ECSFramework = {}

ECSFramework.Engine = ECSEngine
ECSFramework.EngineConfiguration = ECSEngineConfiguration
ECSFramework.World = ECSWorld
ECSFramework.Component = ECSComponentDescription
ECSFramework.System = ECSSystem


return ECSFramework