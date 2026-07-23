local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

type LookServiceServer = {
	Init: (self: LookServiceServer) -> ()
}

local LookServiceServer = {} :: LookServiceServer & typeof(setmetatable({}, {}))

function LookServiceServer.Init(_self: LookServiceServer)
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local lookUpdateEvent = remotesFolder:FindFirstChild("LookUpdate")
	if not lookUpdateEvent then
		lookUpdateEvent = Instance.new("UnreliableRemoteEvent")
		lookUpdateEvent.Name = "LookUpdate"
		lookUpdateEvent.Parent = remotesFolder
	end

	local lastUpdate = {}

	lookUpdateEvent.OnServerEvent:Connect(function(player, lookVector)
		-- Throttle: max 20Hz (0.05 seconds between updates)
		local now = os.clock()
		if lastUpdate[player] and now - lastUpdate[player] < 0.05 then
			return
		end
		lastUpdate[player] = now

		-- Validate input type
		if typeof(lookVector) ~= "Vector3" then
			return
		end

		-- Validate input magnitude (reject NaNs and 0-magnitude)
		local magnitude = lookVector.Magnitude
		if magnitude == 0 or magnitude ~= magnitude then -- Check for NaN
			return
		end

		-- Sanitize: Normalize
		local sanitizedLookVector = lookVector.Unit

		-- Broadcast to everyone else
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				lookUpdateEvent:FireClient(otherPlayer, player, sanitizedLookVector)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastUpdate[player] = nil
	end)
end

return LookServiceServer :: LookServiceServer
