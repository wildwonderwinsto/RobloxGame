local SpawnService = require(script.Services.SpawnService.SpawnService)
local RagdollService = require(script.Services.RagdollService.RagdollService)
local LookServiceServer = require(script.Services.LookService.LookServiceServer)
local LeverServiceServer = require(script.Services.LeverService.LeverServiceServer)

SpawnService:Init() -- Must be first: sets CharacterAutoLoads = false
RagdollService:Init()
LookServiceServer:Init()
LeverServiceServer:Init()
