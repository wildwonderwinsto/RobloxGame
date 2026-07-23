local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Shared folder
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local LookServiceClient = require(sharedFolder.Services.LookService.LookServiceClient)

LookServiceClient:Init()

print("Client services initialized!")
