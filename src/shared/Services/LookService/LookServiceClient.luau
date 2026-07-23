local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

type LookServiceClient = {
	Init: (self: LookServiceClient) -> ()
}
local LookServiceClient = {} :: LookServiceClient & typeof(setmetatable({}, {}))

local MAX_YAW = math.rad(75)
local MAX_PITCH = math.rad(60)

-- Clamp a look vector based on character's root orientation
local function getClampedTarget(rootCFrame: CFrame, desiredLook: Vector3): Vector3
	local localLook = rootCFrame:VectorToObjectSpace(desiredLook)
	local yaw = math.atan2(-localLook.X, -localLook.Z)
	local pitch = math.asin(math.clamp(localLook.Y, -1, 1))

	yaw = math.clamp(yaw, -MAX_YAW, MAX_YAW)
	pitch = math.clamp(pitch, -MAX_PITCH, MAX_PITCH)

	local clampedLocalLook = Vector3.new(
		-math.sin(yaw) * math.cos(pitch),
		math.sin(pitch),
		-math.cos(yaw) * math.cos(pitch)
	)
	
	return rootCFrame:VectorToWorldSpace(clampedLocalLook).Unit
end

function LookServiceClient.Init(_self: LookServiceClient)
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local lookUpdateEvent = remotesFolder:WaitForChild("LookUpdate")

	local remoteLookTargets = {} -- [Player] = Vector3
	local characterJanitors = {} -- [Character] = Janitor
	local characterIKTargets = {} -- [Character] = Attachment
	local characterIKControls = {} -- [Character] = IKControl

	lookUpdateEvent.OnClientEvent:Connect(function(otherPlayer, lookVector)
		remoteLookTargets[otherPlayer] = lookVector
	end)

	local function setupCharacter(_player: Player, character: Model)
		local janitor = Janitor.new()
		characterJanitors[character] = janitor

		-- Use task.spawn to not yield the main initialization thread
		task.spawn(function()
			local upperTorso = character:WaitForChild("UpperTorso", 5)
			local head = character:WaitForChild("Head", 5)
			local rootPart = character:WaitForChild("HumanoidRootPart", 5)
			local humanoid = character:WaitForChild("Humanoid", 5)

			if not (upperTorso and head and rootPart and humanoid) then
				return
			end
			
			-- Check if character is still valid/alive
			if not character.Parent then return end

			local targetAttachment = Instance.new("Attachment")
			targetAttachment.Name = "LookTarget"
			targetAttachment.Parent = Workspace.Terrain
			janitor:Add(targetAttachment)
			characterIKTargets[character] = targetAttachment

			local ikControl = Instance.new("IKControl")
			ikControl.Type = Enum.IKControlType.LookAt
			ikControl.ChainRoot = upperTorso
			ikControl.EndEffector = head
			ikControl.Target = targetAttachment
			ikControl.Weight = 1
			ikControl.Parent = humanoid
			janitor:Add(ikControl)
			characterIKControls[character] = ikControl

			humanoid.Died:Connect(function()
				if characterJanitors[character] then
					characterJanitors[character]:Destroy()
					characterJanitors[character] = nil
					characterIKTargets[character] = nil
					characterIKControls[character] = nil
				end
			end)
		end)
	end

	local function onPlayerAdded(player)
		if player.Character then
			setupCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(char)
			setupCharacter(player, char)
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Workspace.ChildRemoved:Connect(function(child)
		if characterJanitors[child] then
			characterJanitors[child]:Destroy()
			characterJanitors[child] = nil
			characterIKTargets[child] = nil
			characterIKControls[child] = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		remoteLookTargets[player] = nil
	end)

	local lastUpdateSent = 0

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local localPlayer = Players.LocalPlayer
		local localLook = camera.CFrame.LookVector

		-- 1. Send our update to the server (throttle to 15Hz = 0.066s)
		local now = os.clock()
		if now - lastUpdateSent > 0.066 then
			lastUpdateSent = now
			lookUpdateEvent:FireServer(localLook)
		end

		-- 2. Update IK for all characters
		for character, targetAtt in characterIKTargets do
			local player = Players:GetPlayerFromCharacter(character)
			if not player then continue end

			local head = character:FindFirstChild("Head")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not (head and rootPart) then continue end

			-- LOD distance check
			if (camera.CFrame.Position - head.Position).Magnitude > 150 then
				continue
			end

			local desiredLook
			if player == localPlayer then
				desiredLook = localLook
				-- First person check
				local ikControl = characterIKControls[character]
				if ikControl then
					if (camera.CFrame.Position - head.Position).Magnitude < 1 then
						ikControl.Weight = 0
					else
						ikControl.Weight = 1
					end
				end
			else
				desiredLook = remoteLookTargets[player]
			end

			if desiredLook then
				local clampedDir = getClampedTarget(rootPart.CFrame, desiredLook)
				targetAtt.WorldPosition = head.Position + (clampedDir * 10)
			end
		end
	end)
end

return LookServiceClient :: LookServiceClient
