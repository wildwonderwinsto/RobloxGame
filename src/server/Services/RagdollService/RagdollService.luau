local Players = game:GetService("Players")

type RagdollService = {
	_ragdollInstances: { [Model]: { Instance } },
	_onCharacterAdded: (self: RagdollService, character: Model) -> (),
	Init: (self: RagdollService) -> (),
	Ragdoll: (self: RagdollService, character: Model) -> (),
	Unragdoll: (self: RagdollService, character: Model) -> (),
}

local RagdollService = {} :: RagdollService & typeof(setmetatable({}, {}))

function RagdollService._onCharacterAdded(self: RagdollService, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- CRITICAL: prevent Roblox from destroying Motor6Ds on death
	-- (default behavior breaks joints before our Died handler runs)
	humanoid.BreakJointsOnDeath = false

	humanoid.Died:Connect(function()
		self:Ragdoll(character)
	end)

	-- Clean up tracking when character is destroyed on respawn
	character.Destroying:Connect(function()
		self._ragdollInstances[character] = nil
	end)
end

function RagdollService.Init(self: RagdollService)
	self._ragdollInstances = {}

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			self:_onCharacterAdded(character)
		end)

		-- Handle character that already exists (Studio race condition)
		if player.Character then
			self:_onCharacterAdded(player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	-- Handle players already in-game (Studio testing)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function RagdollService.Ragdoll(self: RagdollService, character: Model)
	local instances: { Instance } = {}
	self._ragdollInstances[character] = instances

	-- Kill animation control so it doesn't fight physics
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true

		local animator = humanoid:FindFirstChildWhichIsA("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0)
			end
		end
	end

	-- Swap every Motor6D for a BallSocketConstraint + NoCollisionConstraint
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0
			table.insert(instances, a0)

			local a1 = Instance.new("Attachment")
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1
			table.insert(instances, a1)

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.Parent = joint.Part0
			table.insert(instances, socket)

			-- Prevent connected parts from colliding with each other
			local noCollide = Instance.new("NoCollisionConstraint")
			noCollide.Part0 = joint.Part0
			noCollide.Part1 = joint.Part1
			noCollide.Parent = joint.Part0
			table.insert(instances, noCollide)

			joint.Enabled = false
		end
	end

	-- Server-authoritative physics to prevent jitter on other clients
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end
end

function RagdollService.Unragdoll(self: RagdollService, character: Model)
	-- Destroy all constraints/attachments we created
	local instances = self._ragdollInstances[character]
	if instances then
		for _, inst in instances do
			inst:Destroy()
		end
		self._ragdollInstances[character] = nil
	end

	-- Re-enable all Motor6Ds so the animation rig takes over again
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") then
			joint.Enabled = true
		end
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

return RagdollService :: RagdollService
