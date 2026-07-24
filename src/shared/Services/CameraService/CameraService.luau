local RunService = game:GetService("RunService")

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

type PlayOptions = {
	loop: boolean?,
	speed: number?, -- waypoints per second (default 0.15)
	focusTarget: Instance?, -- look-at target
	focusRadius: number?, -- held distance from focus target
}

type CameraService = {
	_blur: BlurEffect?,
	_dof: DepthOfFieldEffect?,
	_playbackJanitor: any?,
	_focusRadius: number,
	Init: (self: CameraService) -> (),
	Play: (self: CameraService, pathName: string, opts: PlayOptions?) -> (),
	Stop: (self: CameraService) -> (),
	SetFocusRadius: (self: CameraService, radius: number) -> (),
	SetBlur: (self: CameraService, size: number) -> (),
	SetDepthOfField: (self: CameraService, focusDistance: number, inFocusRadius: number, nearIntensity: number, farIntensity: number) -> (),
}

local CameraService = {} :: CameraService & typeof(setmetatable({}, {}))

-- Catmull-Rom spline interpolation between four CFrame control points
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

-- Read waypoints from Workspace.CameraPaths or ReplicatedStorage.CameraPaths
local function getWaypoints(pathName: string): { CFrame }
	local cameraPaths = Workspace:FindFirstChild("CameraPaths") or ReplicatedStorage:FindFirstChild("CameraPaths")
	if not cameraPaths then
		warn("[CameraService] CameraPaths folder not found in Workspace or ReplicatedStorage")
		return {}
	end

	local pathFolder = cameraPaths:FindFirstChild(pathName)
	if not pathFolder then
		warn("[CameraService] CameraPath '" .. pathName .. "' not found")
		return {}
	end

	local parts = {}
	for _, child in pathFolder:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "FocusTarget" then
			table.insert(parts, child)
		end
	end

	table.sort(parts, function(a, b)
		local orderA = a:GetAttribute("Order") or 0
		local orderB = b:GetAttribute("Order") or 0
		return orderA < orderB
	end)

	local waypoints = {}
	for _, part in parts do
		table.insert(waypoints, part.CFrame)
	end

	return waypoints
end

-- Check if a path folder has Loop = true
local function isLooping(pathName: string): boolean
	local cameraPaths = Workspace:FindFirstChild("CameraPaths") or ReplicatedStorage:FindFirstChild("CameraPaths")
	if not cameraPaths then return false end
	local pathFolder = cameraPaths:FindFirstChild(pathName)
	if not pathFolder then return false end
	return pathFolder:GetAttribute("Loop") == true
end

function CameraService.Init(self: CameraService)
	local camera = Workspace.CurrentCamera

	-- Baseline blur — never fully clear
	local blur = Instance.new("BlurEffect")
	blur.Name = "CameraServiceBlur"
	blur.Size = 2
	blur.Parent = camera
	self._blur = blur

	-- Baseline depth of field
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "CameraServiceDoF"
	dof.FarIntensity = 0.1
	dof.FocusDistance = 50
	dof.InFocusRadius = 30
	dof.NearIntensity = 0
	dof.Parent = camera
	self._dof = dof

	self._focusRadius = 15
	self._playbackJanitor = nil
end

function CameraService.Play(self: CameraService, pathName: string, opts: PlayOptions?)
	-- Stop any existing playback first
	self:Stop()

	local options = opts or {}
	local waypoints = getWaypoints(pathName)
	if #waypoints < 2 then
		warn("[CameraService] Path '" .. pathName .. "' needs at least 2 waypoints")
		return
	end

	local pathFolder = nil
	local cameraPaths = Workspace:FindFirstChild("CameraPaths") or ReplicatedStorage:FindFirstChild("CameraPaths")
	if cameraPaths then
		pathFolder = cameraPaths:FindFirstChild(pathName)
	end

	local loop = if options.loop ~= nil then options.loop else isLooping(pathName)
	
	local speed = options.speed
	if not speed and pathFolder then
		speed = pathFolder:GetAttribute("Speed")
	end
	speed = speed or 0.15 -- fallback waypoints per second

	if pathFolder then
		local blurAttr = pathFolder:GetAttribute("Blur")
		if blurAttr ~= nil then
			self:SetBlur(blurAttr)
		end
	end

	if self._blur then
		self._blur.Enabled = true
	end
	if self._dof then
		self._dof.Enabled = true
	end

	local focusTarget = options.focusTarget
	
	local focusRadius = options.focusRadius
	if not focusRadius and pathFolder then
		focusRadius = pathFolder:GetAttribute("FocusRadius")
	end
	focusRadius = focusRadius or self._focusRadius

	self._focusRadius = focusRadius

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local janitor = Janitor.new()
	self._playbackJanitor = janitor

	local startTime = os.clock()
	local numWaypoints = #waypoints
	local totalSegments = if loop then numWaypoints else numWaypoints - 1

	local lastFocusUpdate = 0

	janitor:Add(RunService.RenderStepped:Connect(function(_dt)
		local elapsed = os.clock() - startTime
		local rawAlpha = elapsed * speed -- fractional waypoint index

		if not loop and rawAlpha >= totalSegments then
			-- Reached end of non-looping path
			local finalCFrame = waypoints[numWaypoints]
			if focusTarget and focusTarget:IsA("BasePart") then
				camera.CFrame = CFrame.lookAt(finalCFrame.Position, focusTarget.Position)
			else
				camera.CFrame = finalCFrame
			end
			return
		end

		-- Wrap for looping
		local alpha = if loop then rawAlpha % totalSegments else rawAlpha
		local segmentIndex = math.floor(alpha)
		local t = alpha - segmentIndex

		-- Get four control points for Catmull-Rom (wrapping for loop)
		local function getPoint(i: number): Vector3
			if loop then
				return waypoints[((i - 1) % numWaypoints) + 1].Position
			else
				return waypoints[math.clamp(i, 1, numWaypoints)].Position
			end
		end

		-- segmentIndex is 0-based: segment 0 goes from waypoint 1 to waypoint 2
		local p0 = getPoint(segmentIndex) -- one before start
		local p1 = getPoint(segmentIndex + 1) -- start of segment
		local p2 = getPoint(segmentIndex + 2) -- end of segment
		local p3 = getPoint(segmentIndex + 3) -- one after end

		local position = catmullRom(p0, p1, p2, p3, t)

		if focusTarget and focusTarget:IsA("BasePart") then
			-- Position from path, rotation toward focus target
			local targetPos = focusTarget.Position
			local direction = (targetPos - position).Unit
			local distance = self._focusRadius
			local adjustedPos = targetPos - direction * distance
			camera.CFrame = CFrame.lookAt(adjustedPos, targetPos)
		else
			-- Derive rotation from spline tangent (look toward next point on spline)
			local lookAhead = catmullRom(p0, p1, p2, p3, math.min(t + 0.01, 1))
			if (lookAhead - position).Magnitude > 0.001 then
				camera.CFrame = CFrame.lookAt(position, lookAhead)
			else
				camera.CFrame = CFrame.new(position)
			end
		end

		-- Tell the server to stream the area around our moving camera!
		local now = os.clock()
		if now - lastFocusUpdate > 0.5 then
			lastFocusUpdate = now
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			if remotes then
				local updateFocus = remotes:FindFirstChild("UpdateFocus")
				if updateFocus then
					updateFocus:FireServer(camera.CFrame.Position)
				end
			end
		end
	end))
end

function CameraService.Stop(self: CameraService)
	if self._playbackJanitor then
		self._playbackJanitor:Destroy()
		self._playbackJanitor = nil
	end

	if self._blur then
		self._blur.Enabled = false
	end
	if self._dof then
		self._dof.Enabled = false
	end

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
end

function CameraService.SetFocusRadius(self: CameraService, radius: number)
	self._focusRadius = radius
end

function CameraService.SetBlur(self: CameraService, size: number)
	if self._blur then
		self._blur.Size = size
	end
end

function CameraService.SetDepthOfField(self: CameraService, focusDistance: number, inFocusRadius: number, nearIntensity: number, farIntensity: number)
	if self._dof then
		self._dof.FocusDistance = focusDistance
		self._dof.InFocusRadius = inFocusRadius
		self._dof.NearIntensity = nearIntensity
		self._dof.FarIntensity = farIntensity
	end
end

return CameraService :: CameraService
