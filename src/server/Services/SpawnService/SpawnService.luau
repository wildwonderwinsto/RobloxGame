local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

type SpawnService = {
	Init: (self: SpawnService) -> (),
}

local SpawnService = {} :: SpawnService & typeof(setmetatable({}, {}))

function SpawnService.Init(_self: SpawnService)
	Players.CharacterAutoLoads = false

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local requestSpawn = Instance.new("RemoteEvent")
	requestSpawn.Name = "RequestSpawn"
	requestSpawn.Parent = remotesFolder

	local updateFocus = Instance.new("RemoteEvent")
	updateFocus.Name = "UpdateFocus"
	updateFocus.Parent = remotesFolder

	local playerFocusParts = {}

	requestSpawn.OnServerEvent:Connect(function(player)
		if player.Character then return end
		
		-- Clear the custom focus so streaming follows the new character
		player.ReplicationFocus = nil
		
		local focusPart = playerFocusParts[player]
		if focusPart then
			focusPart:Destroy()
			playerFocusParts[player] = nil
		end

		player:LoadCharacter()
	end)

	-- Handle StreamingEnabled by creating a dummy part that follows the client's cinematic camera
	Players.PlayerAdded:Connect(function(player)
		local focusPart = Instance.new("Part")
		focusPart.Name = "MenuFocus_" .. player.Name
		focusPart.Transparency = 1
		focusPart.CanCollide = false
		focusPart.Anchored = true
		focusPart.Parent = Workspace
		
		playerFocusParts[player] = focusPart
		player.ReplicationFocus = focusPart
	end)

	Players.PlayerRemoving:Connect(function(player)
		local focusPart = playerFocusParts[player]
		if focusPart then
			focusPart:Destroy()
			playerFocusParts[player] = nil
		end
	end)

	updateFocus.OnServerEvent:Connect(function(player, position)
		if player.Character then return end
		local focusPart = playerFocusParts[player]
		if focusPart and typeof(position) == "Vector3" then
			focusPart.Position = position
		end
	end)
end

return SpawnService :: SpawnService
