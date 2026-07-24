local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Shared folder
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local CameraService = require(sharedFolder.Services.CameraService.CameraService)
local GameFlowService = require(sharedFolder.Services.GameFlowService.GameFlowService)
local LookServiceClient = require(sharedFolder.Services.LookService.LookServiceClient)

CameraService:Init() -- Baseline blur/DoF on CurrentCamera
GameFlowService:Init() -- Mounts UI, starts Loading → Menu → Play flow
LookServiceClient:Init()

print("Client services initialized!")
