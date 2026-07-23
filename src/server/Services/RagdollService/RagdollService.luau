local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ServerScriptService.ServerPackages.Janitor)

-- Incremental ragdoll: Testing limits on legs first
type JointConfig = {
	Type: "BallSocket" | "Hinge",
	UpperAngle: number?,
	TwistLowerAngle: number?,
	TwistUpperAngle: number?,
	LowerAngle: number?,
}

local JOINT_CONFIG: { [string]: JointConfig } = {
	-- Neck: tight cone and twist so it slumps but doesn't roll around
	Neck = { Type = "BallSocket", UpperAngle = 20, TwistLowerAngle = -20, TwistUpperAngle = 20 },

	-- Shoulders: wide cone, moderate twist
	LeftShoulder = { Type = "BallSocket", UpperAngle = 60, TwistLowerAngle = -45, TwistUpperAngle = 45 },
	RightShoulder = { Type = "BallSocket", UpperAngle = 60, TwistLowerAngle = -45, TwistUpperAngle = 45 },

	-- Elbows: single-axis hinge, 0-135 degrees
	LeftElbow = { Type = "Hinge", LowerAngle = 0, UpperAngle = 135 },
	RightElbow = { Type = "Hinge", LowerAngle = 0, UpperAngle = 135 },

	-- Wrists: tight ball socket
	LeftWrist = { Type = "BallSocket", UpperAngle = 20, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	RightWrist = { Type = "BallSocket", UpperAngle = 20, TwistLowerAngle = -10, TwistUpperAngle = 10 },

	-- Waist: limited bend so the spine doesn't snap in half
	Waist = { Type = "BallSocket", UpperAngle = 20, TwistLowerAngle = -20, TwistUpperAngle = 20 },

	-- Hips: wide cone, moderate twist
	LeftHip = { Type = "BallSocket", UpperAngle = 50, TwistLowerAngle = -30, TwistUpperAngle = 30 },
	RightHip = { Type = "BallSocket", UpperAngle = 50, TwistLowerAngle = -30, TwistUpperAngle = 30 },

	-- Knees: single-axis hinge, 0-135 degrees (backwards bend only)
	LeftKnee = { Type = "Hinge", LowerAngle = 0, UpperAngle = 135 },
	RightKnee = { Type = "Hinge", LowerAngle = 0, UpperAngle = 135 },

	-- Ankles: tight ball socket
	LeftAnkle = { Type = "BallSocket", UpperAngle = 20, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	RightAnkle = { Type = "BallSocket", UpperAngle = 20, TwistLowerAngle = -10, TwistUpperAngle = 10 },
}

type RagdollService = {
	_janitors: { [Model]: any },
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
		if self._janitors[character] then
			self._janitors[character]:Destroy()
			self._janitors[character] = nil
		end
	end)
end

function RagdollService.Init(self: RagdollService)
	self._janitors = {}

	-- Register collision group so ragdoll limbs never collide with each other
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Ragdoll")
	end)
	PhysicsService:CollisionGroupSetCollidable("Ragdoll", "Ragdoll", false)

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
	if self._janitors[character] then
		-- Already ragdolled
		return
	end

	local janitor = Janitor.new()
	self._janitors[character] = janitor

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

	-- Replace every Motor6D with a limitless BallSocketConstraint
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			-- Create attachments at the joint's original offsets
			local a0 = janitor:Add(Instance.new("Attachment"))
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0

			local a1 = janitor:Add(Instance.new("Attachment"))
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1

			local config = JOINT_CONFIG[joint.Name]

			if config and config.Type == "Hinge" then
				local hinge = janitor:Add(Instance.new("HingeConstraint"))
				hinge.Attachment0 = a0
				hinge.Attachment1 = a1
				hinge.LimitsEnabled = true
				hinge.LowerAngle = config.LowerAngle or 0
				hinge.UpperAngle = config.UpperAngle or 135
				hinge.Parent = joint.Part0
			elseif config and config.Type == "BallSocket" then
				local socket = janitor:Add(Instance.new("BallSocketConstraint"))
				socket.Attachment0 = a0
				socket.Attachment1 = a1
				socket.LimitsEnabled = true
				socket.UpperAngle = config.UpperAngle or 45
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle = config.TwistLowerAngle or -25
				socket.TwistUpperAngle = config.TwistUpperAngle or 25
				socket.MaxFrictionTorque = 15 -- Friction to absorb snapping/bouncing
				socket.Parent = joint.Part0
			else
				-- Unconfigured joints (arms, torso, head) remain perfectly loose but heavy
				local socket = janitor:Add(Instance.new("BallSocketConstraint"))
				socket.Attachment0 = a0
				socket.Attachment1 = a1
				socket.LimitsEnabled = false
				socket.MaxFrictionTorque = 15
				socket.Parent = joint.Part0
			end

			-- Prevent connected parts from colliding with each other
			local noCollide = janitor:Add(Instance.new("NoCollisionConstraint"))
			noCollide.Part0 = joint.Part0
			noCollide.Part1 = joint.Part1
			noCollide.Parent = joint.Part0

			joint.Enabled = false
		end
	end

	-- Apply Ragdoll collision group (NO network ownership changes to avoid lag jitter)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Ragdoll"
		end
	end
end

function RagdollService.Unragdoll(self: RagdollService, character: Model)
	-- Destroy all constraints/attachments we created via the Janitor
	if self._janitors[character] then
		self._janitors[character]:Destroy()
		self._janitors[character] = nil
	end

	-- Re-enable all Motor6Ds so the animation rig takes over again
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") then
			joint.Enabled = true
		end
	end

	-- Restore default collisions
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Default"
		end
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

return RagdollService :: RagdollService
