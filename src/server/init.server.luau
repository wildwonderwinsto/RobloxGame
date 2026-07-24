local SpawnService = require(script.Services.SpawnService.SpawnService)
local RagdollService = require(script.Services.RagdollService.RagdollService)
local LookServiceServer = require(script.Services.LookService.LookServiceServer)

SpawnService:Init() -- Must be first: sets CharacterAutoLoads = false
RagdollService:Init()
LookServiceServer:Init()
