local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local RewardRevealAtoms = require(ReplicatedStorage.Shared.State.RewardRevealAtoms)

type RewardRevealClient = {
	_revealCount: number,
	Init: (self: RewardRevealClient) -> (),
}

local RewardRevealClient = {} :: RewardRevealClient & typeof(setmetatable({}, {}))

local function playSound(soundId: string, parent: Instance, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function getItemPosition(item: Instance): CFrame?
	if item:IsA("BasePart") then
		return item.CFrame
	elseif item:IsA("Model") then
		return item:GetPivot()
	end
	return nil
end

local function burstParticles(item: Instance)
	local itemCFrame = getItemPosition(item)
	if not itemCFrame then
		warn("[RewardReveal] Could not get CFrame from item:", item.Name, item.ClassName)
		return
	end

	-- Look for the VFX template
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local revealFood = vfxFolder and vfxFolder:FindFirstChild("RevealFood")
	local template = revealFood and revealFood:FindFirstChild("RewardShot")

	if template then
		local cloned = template:Clone()

		-- Orient to face the player's camera
		local camera = Workspace.CurrentCamera
		local itemPos = itemCFrame.Position
		local lookAt = camera and camera.CFrame.Position or (itemPos + Vector3.new(0, 0, -1))
		local facingCFrame = CFrame.lookAt(itemPos, lookAt)

		-- Position at the item, facing the player
		if cloned:IsA("BasePart") then
			cloned.CFrame = facingCFrame
			cloned.Anchored = true
			cloned.CanCollide = false
			cloned.Transparency = 1
			cloned.Parent = Workspace
		elseif cloned:IsA("Model") then
			cloned.Parent = Workspace
			cloned:PivotTo(facingCFrame)
		else
			-- Anything else (Attachment, ParticleEmitter, Folder, etc.) needs a host Part
			local host = Instance.new("Part")
			host.Anchored = true
			host.CanCollide = false
			host.Transparency = 1
			host.CFrame = facingCFrame
			host.Parent = Workspace
			cloned.Parent = host
			Debris:AddItem(host, 3)
		end

		-- Disable auto-emission so particles only fire once via :Emit()
		if cloned:IsA("ParticleEmitter") then
			cloned.Enabled = false
			cloned.Rate = 0
		end
		for _, desc in cloned:GetDescendants() do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
				desc.Rate = 0
			end
		end

		task.defer(function()
			if cloned:IsA("ParticleEmitter") then
				cloned:Emit(80)
			end
			for _, desc in cloned:GetDescendants() do
				if desc:IsA("ParticleEmitter") then
					desc:Emit(80)
				end
			end
		end)

		-- Clean up the cloned VFX after a few seconds
		if cloned:IsA("BasePart") or cloned:IsA("Model") then
			Debris:AddItem(cloned, 3)
		end
	else
		warn("[RewardReveal] VFX template not found at ReplicatedStorage.VFX.RevealFood.RewardShot")
	end
end

local function shakeCamera(duration: number, magnitude: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < duration do
			if not humanoid or not humanoid.Parent then
				break
			end
			local falloff = 1 - (os.clock() - startTime) / duration
			humanoid.CameraOffset =
				Vector3.new((math.random() - 0.5) * magnitude * falloff, (math.random() - 0.5) * magnitude * falloff, 0)
			task.wait()
		end
		if humanoid and humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
end

function RewardRevealClient.Init(self: RewardRevealClient)
	self._revealCount = 0

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local rewardRevealEvent = remotesFolder:WaitForChild("RewardReveal")

	rewardRevealEvent.OnClientEvent:Connect(function(itemName: string, spawnedItem: Instance?)
		if not spawnedItem then
			-- First fire: start the drumroll anticipation
			playSound("rbxassetid://119989901283078", Workspace, 0.6)
			return
		end

		-- Second fire: the item has spawned, do the reveal
		self._revealCount += 1
		local revealId = self._revealCount

		burstParticles(spawnedItem)
		shakeCamera(0.3, 0.15)
		playSound("rbxassetid://125379366694866", Workspace, 0.8)

		-- Tell the UI
		RewardRevealAtoms.reveal({ ItemName = itemName, RevealId = revealId })
	end)
end

return RewardRevealClient :: RewardRevealClient
