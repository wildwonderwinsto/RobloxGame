local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local GameFlowAtoms = require(ReplicatedStorage.Shared.State.GameFlowAtoms)
local CameraService = require(ReplicatedStorage.Shared.Services.CameraService.CameraService)
local RootUI = require(ReplicatedStorage.Shared.UI.RootUI)
local mount = require(ReplicatedStorage.Shared.UI.Mount)

local e = React.createElement

type GameFlowService = {
	Init: (self: GameFlowService) -> (),
}

local GameFlowService = {} :: GameFlowService & typeof(setmetatable({}, {}))

local MIN_LOADING_TIME = 2.5

function GameFlowService.Init(_self: GameFlowService)
	local player = Players.LocalPlayer

	local fadeCompleteEvent = Instance.new("BindableEvent")

	local function onFadeComplete()
		fadeCompleteEvent:Fire()
	end

	local function onPlay()
		GameFlowAtoms.phase("FadingToBlackFromMenu")
	end

	mount(e(RootUI, {
		onPlay = onPlay,
		onFadeComplete = onFadeComplete,
	}))

	task.spawn(function()
		-- === LOADING PHASE ===
		GameFlowAtoms.phase("Loading")
		local loadStart = os.clock()

		-- Find camera paths once for streaming + playback
		local cameraPaths = Workspace:FindFirstChild("CameraPaths")
			or ReplicatedStorage:FindFirstChild("CameraPaths")

		-- Wait for the server to create the Remotes folder (SpawnService creates it)
		local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
		local updateFocus = if remotesFolder then remotesFolder:WaitForChild("UpdateFocus", 5) else nil

		-- Move the server-side ReplicationFocus to the kitchen/scene area
		if updateFocus and cameraPaths then
			local introPath = cameraPaths:FindFirstChild("IntroPath")
			if introPath then
				local positions = {}
				for _, child in introPath:GetChildren() do
					if child:IsA("BasePart") and child.Name ~= "FocusTarget" then
						table.insert(positions, child.Position)
					end
				end

				if #positions > 0 then
					-- Move server focus to center of path for broad coverage
					local center = Vector3.zero
					for _, pos in positions do
						center = center + pos
					end
					center = center / #positions
					
					updateFocus:FireServer(center)

					-- Yield until the center is streamed in (up to 5 seconds)
					pcall(function()
						player:RequestStreamAroundAsync(center, 5)
					end)

					-- Also request around each waypoint to ensure the full path is loaded
					for _, pos in positions do
						pcall(function()
							player:RequestStreamAroundAsync(pos, 1)
						end)
					end
				end
			end
		end

		-- Now preload all assets (textures, meshes, sounds)
		pcall(function()
			ContentProvider:PreloadAsync(Workspace:GetDescendants())
		end)
		pcall(function()
			ContentProvider:PreloadAsync(ReplicatedStorage:GetDescendants())
		end)

		local elapsed = os.clock() - loadStart
		if elapsed < MIN_LOADING_TIME then
			task.wait(MIN_LOADING_TIME - elapsed)
		end

		-- Start the camera path while the screen is still black
		local useFocus = math.random() > 0.5
		local focusTarget = nil
		if useFocus then
			if cameraPaths then
				local introPath = cameraPaths:FindFirstChild("IntroPath")
				if introPath then
					focusTarget = introPath:FindFirstChild("FocusTarget")
				end
			end
		end

		CameraService:Play("IntroPath", {
			loop = true,
			focusTarget = focusTarget,
		})

		-- === FADE TO BLACK FROM LOADING ===
		-- Screen goes black over the loading screen, hiding it cleanly
		GameFlowAtoms.phase("FadingToBlackFromLoading")
		fadeCompleteEvent.Event:Wait()

		-- === FADE IN TO MENU ===
		-- Now the menu is mounted behind the black overlay; fade reveals it
		GameFlowAtoms.phase("FadingInMenu")
		fadeCompleteEvent.Event:Wait()

		-- === MENU PHASE ===
		GameFlowAtoms.phase("Menu")

		-- Wait for Play button press
		while GameFlowAtoms.phase() ~= "FadingToBlackFromMenu" do
			task.wait()
		end

		-- Wait for fade-to-black to finish
		fadeCompleteEvent.Event:Wait()

		-- === SPAWN ===
		CameraService:Stop()

		local requestSpawn = remotesFolder:WaitForChild("RequestSpawn")
		requestSpawn:FireServer()

		if not player.Character then
			player.CharacterAdded:Wait()
		end

		task.wait(0.5)

		-- === FADE IN TO GAMEPLAY ===
		GameFlowAtoms.phase("FadingInGame")
		fadeCompleteEvent.Event:Wait()

		-- === GAMEPLAY ===
		GameFlowAtoms.phase("Gameplay")
		fadeCompleteEvent:Destroy()
	end)
end

return GameFlowService :: GameFlowService
